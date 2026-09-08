with
    all_hours as (
        select
            it.icu_stay_id,
            it.in_time,
            {{ round_up_hourly("it.in_time") }} as in_time_rounded,
            {{
                generate_array(
                    -24,
                    "timestamp_diff(timestamp_trunc(it.out_time, hour), timestamp_trunc(it.in_time, hour), hour)",
                )
            }}
            as time_window_indices
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays` it
    ),
    ih as (
        select
            icu_stay_id,
            time_window_index,
            timestamp_add(in_time_rounded, interval time_window_index hour) as end_time,
            timestamp_add(
                in_time_rounded, interval time_window_index - 1 hour
            ) as start_time,
            in_time
        from all_hours
        cross join unnest(all_hours.time_window_indices) as time_window_index
    ),
    lab_rounded as (
        select
            lb.icu_stay_id,
            timestamp_diff(
                {{ round_up_hourly("lb.time") }}, {{ round_up_hourly("in_time") }}, hour
            ) as time_window_index,
            lb.field_name,
            lb.value,
            lb.exceeded_range
        from `medicu-beta.latest_one_icu.laboratory_tests_blood` lb
        left join
            `medicu-beta.latest_one_icu_derived.extended_icu_stays` ie using (
                icu_stay_id
            )
    ),
    lab_blood_hourly as (
        select
            icu_stay_id,
            time_window_index,
            min(case when field_name = ('platelet') then value end) as pt_min,
            min(case when field_name = ('creatinine') then value end) as cre_min,
            max(case when field_name = ('reticulocyte') then value end) as ret_max,
            min(case when field_name = ('haptoglobin') then value end) as hp_min,
            max(
                case
                    when field_name = ('haptoglobin') and exceeded_range is true
                    then 1
                    when field_name = ('haptoglobin') and exceeded_range is not true
                    then 0
                end
            ) as hp_exceeded_range,
            min(case when field_name = ('mcv') then value end) as mcv_min,
            min(
                case
                    when
                        field_name
                        = ('international_normalized_ratio_of_prothrombin_time')
                    then value
                end
            ) as pt_inr_min,
            max(case when field_name = ('creatine_kinase') then value end) as ck_max
        from lab_rounded
        group by icu_stay_id, time_window_index
    ),
    calculation as (
        select
            a.icu_stay_id,
            timestamp_diff(
                {{ round_up_hourly("a.time") }}, {{ round_up_hourly("in_time") }}, hour
            ) as time_window_index,
            a.time,
            case
                when
                    a.field_name = ('total_bilirubin')
                    and b.field_name = ('direct_bilirubin')
                then a.value - b.value
            end as indirect_bilirubin,
            case
                when
                    a.field_name = ('lactate_dehydrogenase')
                    and b.field_name = ('hemoglobin')
                    and b.value != 0
                then a.value / b.value
            end as ldhb_ratio
        from `medicu-beta.latest_one_icu.laboratory_tests_blood` a
        inner join
            `medicu-beta.latest_one_icu.laboratory_tests_blood` b using (
                icu_stay_id, time
            )
        inner join
            `medicu-beta.latest_one_icu_derived.extended_icu_stays` ie using (
                icu_stay_id
            )
        where
            (a.field_name = ('total_bilirubin') and b.field_name = ('direct_bilirubin'))
            or (
                a.field_name = ('lactate_dehydrogenase')
                and b.field_name = ('hemoglobin')
            )
    ),
    make_hour as (
        select
            icu_stay_id,
            time_window_index,
            max(indirect_bilirubin) as ib_max,
            max(ldhb_ratio) as ldhb_ratio_max
        from calculation
        group by icu_stay_id, time_window_index
    ),
    joined as (
        select
            ih.icu_stay_id,
            ih.time_window_index,
            ih.start_time,
            ih.end_time,
            ih.in_time,
            lb.pt_min,
            lb.cre_min,
            lb.ret_max,
            lb.hp_min,
            lb.hp_exceeded_range,
            lb.mcv_min,
            lb.pt_inr_min,
            lb.ck_max,
            mh.ib_max,
            mh.ldhb_ratio_max
        from ih
        left join lab_blood_hourly lb using (icu_stay_id, time_window_index)
        left join make_hour mh using (icu_stay_id, time_window_index)
    ),
    filled as (
        select
            icu_stay_id,
            time_window_index,
            start_time,
            end_time,
            in_time,
            last_value(pt_min ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as pt_min,
            last_value(cre_min ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as cre_min,
            last_value(ret_max ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as ret_max,
            last_value(hp_min ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as hp_min,
            last_value(hp_exceeded_range ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as hp_exceeded_range,
            last_value(mcv_min ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as mcv_min,
            last_value(pt_inr_min ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as pt_inr_min,
            last_value(ck_max ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as ck_max,
            last_value(ib_max ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as ib_max,
            last_value(ldhb_ratio_max ignore nulls) over (
                partition by icu_stay_id
                order by time_window_index
                rows between 49 preceding and current row
            ) as ldhb_ratio_max
        from joined
    ),
    diagnoses_flag as (
        select
            icu_stay_id,
            max(
                case
                    when
                        timestamp_diff(in_time, disease_start_date, day) >= 0
                        and timestamp_diff(in_time, disease_start_date, day) <= 365
                        and (
                            substr(icd10, 1, 3) in ('C43', 'C88')
                            or substr(icd10, 1, 3) between 'C00' and 'C26'
                            or substr(icd10, 1, 3) between 'C30' and 'C34'
                            or substr(icd10, 1, 3) between 'C37' and 'C41'
                            or substr(icd10, 1, 3) between 'C45' and 'C58'
                            or substr(icd10, 1, 3) between 'C60' and 'C76'
                            or substr(icd10, 1, 3) between 'C81' and 'C85'
                            or substr(icd10, 1, 3) between 'C90' and 'C97'
                        )
                        and suspicion_flag is false
                    then 1
                    else 0
                end
            ) as cancer_flag,
            max(
                case
                    when
                        timestamp_diff(in_time, disease_start_date, day) >= 0
                        and (icd10 like ('Z94%') or icd10 like ('T86%'))
                        and suspicion_flag is false
                    then 1
                    else 0
                end
            ) as transplant_flag
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join
            `medicu-beta.latest_one_icu.hospital_admission_diagnoses` using (
                hospital_admission_id
            )
        group by icu_stay_id
    ),
    calc_plasmic_score_component as (
        select
            f.icu_stay_id,
            f.time_window_index,
            f.start_time,
            f.end_time,
            f.in_time,
            case
                when pt_min is null then null when pt_min < 30 then 1 else 0
            end as pt_score,
            case
                when cre_min is null then null when cre_min < 2 then 1 else 0
            end as cre_score,
            case
                when ib_max is null then null when ib_max > 2 then 1 else 0
            end as ib_score,
            case
                when ret_max is null then null when ret_max > 2.5 then 1 else 0
            end as ret_score,
            case
                when hp_min is null
                then null
                when hp_min < 40 and hp_exceeded_range = 1
                then 1
                else 0
            end as hp_score,
            case
                when ldhb_ratio_max is null or ck_max is null
                then null
                when ldhb_ratio_max >= 53.7 and ck_max <= 1000
                then 1
                else 0
            end as ldhb_score,
            case
                when pt_inr_min is null then null when pt_inr_min < 1.5 then 1 else 0
            end as pt_inr_score,
            case
                when mcv_min is null then null when mcv_min < 90 then 1 else 0
            end as mcv_score,
            case
                when cancer_flag is null then null when cancer_flag = 0 then 1 else 0
            end as cancer_score,
            case
                when transplant_flag is null
                then null
                when transplant_flag = 0
                then 1
                else 0
            end as transplant_score
        from filled f
        left join diagnoses_flag using (icu_stay_id)
    ),
    calc_plasmic_score as (
        select
            icu_stay_id,
            time_window_index,
            start_time,
            end_time,
            in_time,
            pt_score,
            case
                when
                    pt_score is null
                    and cre_score is null
                    and ib_score is null
                    and ret_score is null
                    and hp_score is null
                    and ldhb_score is null
                    and pt_inr_score is null
                    and mcv_score is null
                    and cancer_score is null
                    and transplant_score is null
                then null
                else
                    coalesce(pt_score, 0)
                    + coalesce(cre_score, 0)
                    + greatest(
                        coalesce(ib_score, 0),
                        coalesce(ret_score, 0),
                        coalesce(hp_score, 0),
                        coalesce(ldhb_score, 0)
                    )
                    + coalesce(pt_inr_score, 0)
                    + coalesce(mcv_score, 0)
                    + coalesce(cancer_score, 0)
                    + coalesce(transplant_score, 0)
            end as plasmic_score
        from calc_plasmic_score_component
    ),
    plasmic_daily as (
        select
            icu_stay_id,
            div(timestamp_diff(end_time, in_time, hour), 24) + 1 as day,
            max(pt_score) as pt_score,
            max(plasmic_score) as plasmic_score
        from calc_plasmic_score
        where time_window_index >= 0
        group by icu_stay_id, day
    ),
    final as (
        select
            icu_stay_id,
            day,
            pt_score,
            plasmic_score,
        from plasmic_daily
    )

select *
from final
