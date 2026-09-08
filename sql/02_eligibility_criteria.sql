-- Patients meeting the eligibility criteria of the study (returns icu_stay_id).

with
    -- inclusion criteria
    -- patients from ADAMTS13 available hospitals/periods
    inclusion_criteria as (
        select distinct icu_stay_id
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        where (hospital_id = 1 and icu_admission_year >= 2025)
            or (hospital_id = 5 and icu_admission_year >= 2021)
            or (hospital_id = 6 and icu_admission_year >= 2018)
            or (hospital_id = 7 and icu_admission_year >= 2018)
            or (hospital_id = 19 and icu_admission_year >= 2022)
            or (hospital_id = 20 and icu_admission_year >= 2019)
    ),
    -- exclusion criteria
    -- 1. cases without a recorded age or sex
    -- 2. age < 18 years
    -- 3. without PLASMIC score in day 1 ~ 7
    -- 4. not first ICU admission
    exclusion_criteria as (
        with
            -- 1. cases without a recorded age or sex
            no_recorded_gender_age as (
                select distinct icu_stay_id
                from inclusion_criteria
                where
                    icu_stay_id not in (
                        select distinct icu_stay_id
                        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
                        where age is not null and female is not null
                    )
            ),
            -- 2. age < 18 years
            age_less_than_18 as (
                select distinct icu_stay_id
                from inclusion_criteria
                where
                    icu_stay_id not in (
                        select distinct icu_stay_id
                        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
                        where age >= 18
                    )
            ),
            -- 3. without PLASMIC score in day 1 ~ 7
            no_plasmic_score as (
                select distinct icu_stay_id
                from inclusion_criteria
                where icu_stay_id not in (
                        select distinct icu_stay_id
                        from `medicu-production.research_tma_epidemiology_2026.01_plasmic_score`
                        where plasmic_score is not null
                            and 1 <= day and day <= 7
                )
            ),
            pre_eligibility_criteria as (
                select icu_stay_id
                from inclusion_criteria
                where icu_stay_id not in (
                    select icu_stay_id
                    from no_recorded_gender_age
                    union distinct
                    select icu_stay_id
                    from age_less_than_18
                    union distinct
                    select icu_stay_id
                    from no_plasmic_score
                )
            ),
            -- 4. not first ICU admission
            not_first_icu_admission as (
                select icu_stay_id
                from (
                    select
                        icu_stay_id,
                        row_number() over (
                            partition by subject_id
                            order by in_time, icu_stay_id
                        ) as icu_admission_seq
                    from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
                    where icu_stay_id in (select icu_stay_id from pre_eligibility_criteria)
                )
                where icu_admission_seq > 1
            )
        select icu_stay_id
        from no_recorded_gender_age
        union distinct
        select icu_stay_id
        from age_less_than_18
        union distinct
        select icu_stay_id
        from no_plasmic_score
        union distinct
        select icu_stay_id
        from not_first_icu_admission
    )

select icu_stay_id
from inclusion_criteria
where icu_stay_id not in (select distinct icu_stay_id from exclusion_criteria)