with
  static as (
    select
      icu_stay_id,
      age,
      female,
      body_weight,
      icu_admission_type,
    from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
  ),
  diagnoses as (
    with
      hosp_diagnoses as (
        select
          icu_stay_id,
          icd10,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu.hospital_admission_diagnoses` using (hospital_admission_id)
        where timestamp_diff(disease_start_date, out_time, minute) <= 0
          and (disease_end_date is null
            or timestamp_diff(in_time, disease_end_date, minute) <= 0)
      ),
      union_diagnoses as (
        select 
          icu_stay_id,
          max(case when i.icd10 = ('M311') or i.icd10 = ('D593') or h.icd10 = ('M311') or h.icd10 = ('D593') then 1 else 0 end) as tma_flag,
          max(case when diagnosis = ('TTP') or diagnosis like ('%血栓性血小板減少性紫斑病') then 1 else 0 end) as ttp_flag,
        from `medicu-beta.latest_one_icu_derived.unioned_icu_diagnoses` i
        full join hosp_diagnoses h using (icu_stay_id)
        group by icu_stay_id
      ),
      sepsis as (
        select
          icu_stay_id,
          case when 0 <= confirmed_time_window_index and confirmed_time_window_index < 24 then 1 else 0 end as sepsis_flag,
        from `medicu-beta.latest_one_icu_derived.sepsis_confirmation`
      ),
      dic as (
        select
          icu_stay_id,
          max(case when jaam_dic_score >= 4 and 0 <= time_window_index and time_window_index < 24 then 1 else 0 end) as dic_flag
        from `medicu-beta.latest_one_icu_derived.dic_hourly`
        group by icu_stay_id
      )
    select
      icu_stay_id,
      coalesce(tma_flag, 0) as tma_flag,
      coalesce(ttp_flag, 0) as ttp_flag,
      coalesce(sepsis_flag, 0) as sepsis_flag,
      coalesce(dic_flag, 0) as dic_flag,
    from dic
    left join sepsis using (icu_stay_id)
    left join union_diagnoses using (icu_stay_id)
  ),
  lab_blood as (
    with
      base as (
        select
          icu_stay_id,
          min(case when field_name = ('platelet') then value end) as pt_min,
          min(case when field_name = ('creatinine') then value end) as cre_min,
          max(case when field_name = ('reticulocyte') then value end) as ret_max,
          min(case when field_name = ('haptoglobin') then value end) as hp_min,
          min(case when field_name = ('mcv') then value end) as mcv_min,
          min(case when field_name = ('international_normalized_ratio_of_prothrombin_time') then value end) as pt_inr_min,
          max(case when field_name = ('creatine_kinase') then value end) as ck_max,
          max(case when field_name = ('lactate_dehydrogenase') then value end) as ld_max,
          min(case when field_name = ('hemoglobin') then value end) as hb_min,
          max(case when field_name = ('fdp') then value end) as fdp_max,
          max(case when field_name = ('d_dimer') then value end) as d_dimer_max,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu.laboratory_tests_blood` using (icu_stay_id)
        where 0 <= timestamp_diff(time, in_time, hour) and timestamp_diff(time, in_time, hour) < 24
        group by icu_stay_id
      ),
      calc_indirect_bilirubin as (
        select 
          icu_stay_id,
          max(case when a.field_name = ('total_bilirubin') and b.field_name = ('direct_bilirubin') then a.value - b.value end) as ib_max,
        from `medicu-beta.latest_one_icu.laboratory_tests_blood` a
        inner join `medicu-beta.latest_one_icu.laboratory_tests_blood` b using (icu_stay_id, time)
        left join `medicu-beta.latest_one_icu_derived.extended_icu_stays` using (icu_stay_id)
        where (a.field_name = ('total_bilirubin') and b.field_name = ('direct_bilirubin'))
          and 0 <= timestamp_diff(time, in_time, hour) and timestamp_diff(time, in_time, hour) < 24
        group by icu_stay_id
      )
      select
        icu_stay_id,
        pt_min,
        cre_min,
        ret_max,
        hp_min,
        ib_max,
        mcv_min,
        pt_inr_min,
        ck_max,
        ld_max,
        hb_min,
        fdp_max,
        d_dimer_max,
      from base
      full join calc_indirect_bilirubin using (icu_stay_id)
  ),
  adam as (
    select distinct
      icu_stay_id,
      1 as adam_flag,
    from `medicu-beta.latest_one_icu.laboratory_tests_blood`
    where field_name = ('adamts13')
  ),
  sofa as (
    select
      icu_stay_id,
      max(sofa_24hours) as sofa_max,
    from `medicu-beta.latest_one_icu_derived.sofa_hourly`
    where 0 <= time_window_index and time_window_index < 24
    group by icu_stay_id
  ),
  apache2 as (
    select
      icu_stay_id,
      apache2_score,
    from `medicu-beta.latest_one_icu_derived.apache2`
  ),
  mv_use_table as (
    with
      mv_base as (
        select
          icu_stay_id,
          case
            when
              start_time < timestamp_add(in_time, interval 24 hour)
              and in_time < end_time
            then 1
            else 0
          end as mv_use,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu.mechanical_ventilations` using (icu_stay_id)
      )
    select
      icu_stay_id,
      max(mv_use) as mv_use,
    from mv_base
    group by icu_stay_id
  ),
  vaso_use_table as (
    with
      vaso_base as (
        select
          icu_stay_id,
          case
            when
              active_ingredient_name in (
                'vasopressin',
                'dopamine',
                'noradrenaline',
                'adrenaline',
                'phenylephrine'
              )
              and start_time < timestamp_add(in_time, interval 24 hour)
              and in_time < end_time
            then 1
            else 0
          end as vaso_use,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed` using (icu_stay_id)
      )
    select
      icu_stay_id,
      max(vaso_use) as vaso_use,
    from vaso_base
    group by icu_stay_id
  ),
  rrt_use_table as (
    with
      rrt_base as (
        select
          icu_stay_id,
          case
            when
              start_time < timestamp_add(in_time, interval 24 hour)
              and in_time < end_time
            then 1
            else 0
          end as rrt_use,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu.renal_replacement_therapy` using (icu_stay_id)
      )
    select
      icu_stay_id,
      max(rrt_use) as rrt_use,
    from rrt_base
    group by icu_stay_id
  ), 
  join_all as (
    select
      icu_stay_id,
      age,
      female,
      body_weight,
      icu_admission_type,
      tma_flag,
      ttp_flag,
      sepsis_flag,
      dic_flag,
      pt_min,
      cre_min,
      ret_max,
      hp_min,
      ib_max,
      mcv_min,
      pt_inr_min,
      ck_max,
      ld_max,
      hb_min,
      fdp_max,
      d_dimer_max,
      coalesce(adam_flag, 0) as adam_flag,
      sofa_max,
      apache2_score,
      mv_use,
      vaso_use,
      rrt_use,
    from static
    left join diagnoses using (icu_stay_id)
    left join lab_blood using (icu_stay_id)
    left join adam using (icu_stay_id)
    left join sofa using (icu_stay_id)
    left join apache2 using (icu_stay_id)
    left join mv_use_table using (icu_stay_id)
    left join vaso_use_table using (icu_stay_id)
    left join rrt_use_table using (icu_stay_id)
  )

select *
from join_all
inner join `medicu-production.research_tma_epidemiology_2026.02_eligibility_criteria` using (icu_stay_id)
