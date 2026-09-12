with
  -- hepatic failure
  hepatic_failure as (
    select distinct icu_stay_id, 1 as hepatic_flag
    from `medicu-beta.latest_one_icu_derived.unioned_icu_diagnoses`
    where icd10 in ('K704', 'K711', 'K720', 'K721', 'K729')
  ),
  -- DIC score
  dic as (
    select 
      icu_stay_id,
      div(time_window_index, 24) + 1 as day,
      max(jaam_dic_score) as jaam_max,
    from `medicu-beta.latest_one_icu_derived.dic_hourly`
    group by icu_stay_id, day
  ),
  -- test
  adam as (
    select distinct
      icu_stay_id,
      1 as adam_flag,
    from `medicu-beta.latest_one_icu.laboratory_tests_blood`
    where field_name = ('adamts13')
  ),
  hosp_diagnoses as (
    select
      icu_stay_id,
      icd10,
    from `medicu-beta.latest_one_icu.hospital_admission_diagnoses` 
    left join `medicu-beta.latest_one_icu_derived.extended_icu_stays` using (hospital_admission_id)
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
  -- treatment
  treatment as (
    with
      pe_records as (
        select
          icu_stay_id,
          div(timestamp_diff(start_time, in_time, hour), 24) + 1 as pe_start_day,
          div(timestamp_diff(coalesce(end_time, start_time), in_time, hour), 24) + 1 as pe_end_day
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        inner join `medicu-beta.latest_one_icu.blood_purification_therapy` using (icu_stay_id)
        where type = ('plasma_exchange')
      ),
      pe_days as (
        select distinct
          icu_stay_id,
          day,
          1 as pe_flag,
        from pe_records, unnest(generate_array(pe_start_day, pe_end_day)) as day
      ),
      drug_usage as (
        select
          icu_stay_id,
          div(timestamp_diff(start_time, in_time, hour), 24) + 1 as day,
          max(case when active_ingredient_name = ('caplacizumab') or active_ingredient_name = ('eculizumab') then 1 else 0 end) as drug_flag,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        inner join `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed` using (icu_stay_id)
        group by icu_stay_id, day
      )
    select
      icu_stay_id,
      day,
      coalesce(pe_flag, 0) as pe_flag,
      coalesce(drug_flag, 0) as drug_flag,
    from pe_days
    full join drug_usage using (icu_stay_id, day)
  ),
  -- sepsis
  sepsis as (
    select 
      icu_stay_id,
      div(confirmed_time_window_index, 24) + 1 as confirmed_day,
    from `medicu-beta.latest_one_icu_derived.sepsis_confirmation`
  ),
  -- join all
  final as (
    select
      icu_stay_id,
      day,
      coalesce(hepatic_flag, 0) as hepatic_flag,
      jaam_max,
      pt_score,
      plasmic_score,
      coalesce(adam_flag, 0) as adam_flag,
      coalesce(tma_flag, 0) as tma_flag,
      coalesce(ttp_flag, 0) as ttp_flag,
      coalesce(pe_flag, 0) as pe_flag,
      coalesce(drug_flag, 0) as drug_flag,
      case when day >= confirmed_day then 1 else 0 end as sepsis_flag,
      case
        when icu_mortality is null then null
        when icu_mortality is true then 1
        else 0
      end as icu_mortality,
      case
        when hospital_mortality is null then null
        when hospital_mortality is true then 1
        else 0
      end as hospital_mortality,
    from `medicu-production.research_tma_epidemiology_2026.01_plasmic_score`
    left join hepatic_failure using (icu_stay_id)
    full join dic using (icu_stay_id, day)
    left join adam using (icu_stay_id)
    left join union_diagnoses using (icu_stay_id)
    full join treatment using (icu_stay_id, day)
    left join sepsis using (icu_stay_id)
    left join `medicu-beta.latest_one_icu_derived.extended_icu_stays` using (icu_stay_id)
  )

select *
from final
inner join `medicu-production.research_tma_epidemiology_2026.02_eligibility_criteria` using (icu_stay_id)
order by icu_stay_id, day
