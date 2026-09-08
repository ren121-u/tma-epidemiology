############################################################
# Main table
############################################################

library(tidyverse)

# --- Directories ---
data_dir   <- './data/'
output_dir <- './output/adam_ratio/'

data_ver   <- '20260714'
output_ver <- '20260714'

############################################################
# 1. Load data
############################################################

df <- read.csv(
  paste0(data_dir, data_ver, '_tma_all.csv')
)

glimpse(df)

#day1-7
df <- df %>%
  filter(
    day >= 1 &
    day <= 7
  )

############################################################
# 2. worst PLASMIC score
############################################################

plasmic_worst <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    plasmic_worst =
      max(plasmic_score, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 3. platelet (<30000) flag
############################################################

pt_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    pt_score =
      any(pt_score == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 4. JAAM DIC score
############################################################

jaam_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    jaam_worst =
      max(jaam_max, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 5a. TMA flag
############################################################

tma_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    tma =
      any(tma_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 5b. TTP flag
############################################################

ttp_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    ttp =
      any(ttp_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )  

############################################################
# 6. ADAMTS13 flag
############################################################

adam_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    adam =
      any(adam_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 7a. PE flag
############################################################

pe_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    pe =
      any(pe_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 7b. Drug flag
############################################################

drug_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    drug =
      any(drug_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 7c. Any treatment flag
############################################################

treatment_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    any_treatment =
      any(
        pe_flag == 1 |
        drug_flag == 1,
        na.rm = TRUE
      ),

    .groups = "drop"
  )

############################################################
# 8. Hepatic flag
############################################################

hepatic_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    hepatic =
      any(hepatic_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 9. Sepsis
############################################################

sepsis_flag_df <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    sepsis =
      any(sepsis_flag == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 10a. ICU mortality
############################################################

icu_mortality_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    icu_mortality =
      any(icu_mortality == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 10b. Hospital mortality
############################################################

hospital_mortality_patient <- df %>%
  group_by(icu_stay_id) %>%
  summarise(

    hospital_mortality =
      any(hospital_mortality == 1, na.rm = TRUE),

    .groups = "drop"
  )

############################################################
# 11. Data per patient
############################################################

patient_level <- plasmic_worst %>%

  left_join(
    pt_patient,
    by = "icu_stay_id"
  ) %>%
  
  left_join(
    jaam_patient,
    by = "icu_stay_id"
  ) %>%
  
  left_join(
    tma_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    ttp_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    adam_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    pe_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    drug_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    treatment_patient,
    by = "icu_stay_id"
  ) %>%

    left_join(
    hepatic_patient,
    by = "icu_stay_id"
  ) %>%

    left_join(
    sepsis_flag_df,
    by = "icu_stay_id"
  ) %>%  

    left_join(
    icu_mortality_patient,
    by = "icu_stay_id"
  ) %>%

  left_join(
    hospital_mortality_patient,
    by = "icu_stay_id"
  ) %>%

  mutate(

    pt_score =
      replace_na(pt_score, FALSE),
    
    tma =
      replace_na(tma, FALSE),

    ttp =
      replace_na(ttp, FALSE),  

    adam =
      replace_na(adam, FALSE),

    pe =
      replace_na(pe, FALSE),

    hepatic =
      replace_na(hepatic, FALSE),

    drug =
      replace_na(drug, FALSE),

    any_treatment =
      replace_na(any_treatment, FALSE),

    sepsis =
      replace_na(sepsis, FALSE),
    
    icu_mortality =
      replace_na(icu_mortality, FALSE),

    hospital_mortality =
      replace_na(hospital_mortality, FALSE)
)

############################################################
# 12a. Aggregate by PLASMIC score
############################################################

plasmic_summary_all <- patient_level %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    ########################################################
    # Number of patients
    ########################################################

    n_patients = n(),

    ########################################################
    # TMA
    ########################################################

    tma_n =
      sum(tma),

    tma_pct =
      round(
        mean(tma) * 100,
        1
      ),

    ########################################################
    # TTP
    ########################################################

    ttp_n =
    sum(ttp),

    ttp_pct =
    round(
        mean(ttp) * 100,
        1
    ),

    ########################################################
    # ADAMTS13 testing
    ########################################################

    adam_n =
      sum(adam),

    adam_pct =
      round(
        mean(adam) * 100,
        1
      ),

    ########################################################
    # PE
    ########################################################

    pe_n =
      sum(pe),

    pe_pct =
      round(
        mean(pe) * 100,
        1
      ),

    ########################################################
    # Hepatic failure in PE
    ########################################################

    pe_hepatic_n =
      sum(
        pe &
        hepatic
      ),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe) == 0,
          NA,
          100 *
            sum(
              pe &
              hepatic
            ) /
            sum(pe)
        ),
        1
      ),

    ########################################################
    # Drug
    ########################################################

    drug_n =
      sum(drug),

    drug_pct =
      round(
        mean(drug) * 100,
        1
      ),

    ########################################################
    # Any treatment
    ########################################################

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(
        mean(any_treatment) * 100,
        1
      ),

    ########################################################
    # ICU mortality
    ########################################################

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(
        mean(icu_mortality) * 100,
        1
      ),

    ########################################################
    # Hospital mortality
    ########################################################

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(
        mean(hospital_mortality) * 100,
        1
      ),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12b. Aggregate by PLASMIC score (sepsis)
############################################################

plasmic_summary_sepsis <- patient_level %>%

  filter(sepsis == TRUE) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    ########################################################
    # Number of patients
    ########################################################

    n_patients = n(),

    ########################################################
    # TMA
    ########################################################

    tma_n =
      sum(tma),

    tma_pct =
      round(
        mean(tma) * 100,
        1
      ),

    ########################################################
    # TTP
    ########################################################

    ttp_n =
    sum(ttp),

    ttp_pct =
    round(
        mean(ttp) * 100,
        1
    ),

    ########################################################
    # ADAMTS13 testing
    ########################################################

    adam_n =
      sum(adam),

    adam_pct =
      round(
        mean(adam) * 100,
        1
      ),

    ########################################################
    # PE
    ########################################################

    pe_n =
      sum(pe),

    pe_pct =
      round(
        mean(pe) * 100,
        1
      ),

    ########################################################
    # Hepatic failure in PE
    ########################################################

    pe_hepatic_n =
      sum(
        pe &
        hepatic
      ),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe) == 0,
          NA,
          100 *
            sum(
              pe &
              hepatic
            ) /
            sum(pe)
        ),
        1
      ),

    ########################################################
    # Drug
    ########################################################

    drug_n =
      sum(drug),

    drug_pct =
      round(
        mean(drug) * 100,
        1
      ),

    ########################################################
    # Any treatment
    ########################################################

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(
        mean(any_treatment) * 100,
        1
      ),

    ########################################################
    # ICU mortality
    ########################################################

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(
        mean(icu_mortality) * 100,
        1
      ),

    ########################################################
    # Hospital mortality
    ########################################################

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(
        mean(hospital_mortality) * 100,
        1
      ),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12c. Aggregate by PLASMIC score (non-sepsis)
############################################################

plasmic_summary_nonsepsis <- patient_level %>%

  filter(sepsis == FALSE) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    ########################################################
    # Number of patients
    ########################################################

    n_patients = n(),

    ########################################################
    # TMA
    ########################################################

    tma_n =
      sum(tma),

    tma_pct =
      round(
        mean(tma) * 100,
        1
      ),

    ########################################################
    # TTP
    ########################################################

    ttp_n =
    sum(ttp),

    ttp_pct =
    round(
        mean(ttp) * 100,
        1
    ),

    ########################################################
    # ADAMTS13 testing
    ########################################################

    adam_n =
      sum(adam),

    adam_pct =
      round(
        mean(adam) * 100,
        1
      ),

    ########################################################
    # PE
    ########################################################

    pe_n =
      sum(pe),

    pe_pct =
      round(
        mean(pe) * 100,
        1
      ),

    ########################################################
    # Hepatic failure in PE
    ########################################################

    pe_hepatic_n =
      sum(
        pe &
        hepatic
      ),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe) == 0,
          NA,
          100 *
            sum(
              pe &
              hepatic
            ) /
            sum(pe)
        ),
        1
      ),

    ########################################################
    # Drug
    ########################################################

    drug_n =
      sum(drug),

    drug_pct =
      round(
        mean(drug) * 100,
        1
      ),

    ########################################################
    # Any treatment
    ########################################################

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(
        mean(any_treatment) * 100,
        1
      ),

    ########################################################
    # ICU mortality
    ########################################################

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(
        mean(icu_mortality) * 100,
        1
      ),

    ########################################################
    # Hospital mortality
    ########################################################

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(
        mean(hospital_mortality) * 100,
        1
      ),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst) 

############################################################
# 12d. Aggregate by PLASMIC score (stratified by JAAM)
############################################################

plasmic_summary_all_jaam_lt4 <- patient_level %>%

  filter(jaam_worst < 4) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)


plasmic_summary_all_jaam_ge4 <- patient_level %>%

  filter(jaam_worst >= 4) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12e. Aggregate by PLASMIC score (sepsis, stratified by JAAM)
############################################################

plasmic_summary_sepsis_jaam_lt4 <- patient_level %>%

  filter(jaam_worst < 4) %>%
  
  filter(sepsis) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

plasmic_summary_sepsis_jaam_ge4 <- patient_level %>%

  filter(jaam_worst >= 4) %>%
  
  filter(sepsis) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12f. Aggregate by PLASMIC score (stratified by platelet)
############################################################

plasmic_summary_all_pt_lt30000 <- patient_level %>%

  filter(pt_score == TRUE) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)


plasmic_summary_all_pt_ge30000 <- patient_level %>%

  filter(pt_score == FALSE) %>%
  
  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12g. Aggregate by PLASMIC score (sepsis, stratified by platelet)
############################################################

plasmic_summary_sepsis_pt_lt30000 <- patient_level %>%

  filter(pt_score == TRUE) %>%
  
  filter(sepsis) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

plasmic_summary_sepsis_pt_ge30000 <- patient_level %>%

  filter(pt_score == FALSE) %>%
  
  filter(sepsis) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

############################################################
# 12h. Aggregate by PLASMIC score (non-sepsis, stratified by platelet)
############################################################

plasmic_summary_nonsepsis_pt_lt30000 <- patient_level %>%

  filter(pt_score == TRUE) %>%
  
  filter(sepsis == FALSE) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)

plasmic_summary_nonsepsis_pt_ge30000 <- patient_level %>%

  filter(pt_score == FALSE) %>%
  
  filter(sepsis == FALSE) %>%

  filter(
    plasmic_worst %in% 0:7
  ) %>%

  group_by(plasmic_worst) %>%

  summarise(

    n_patients = n(),

    tma_n = sum(tma),
    tma_pct = round(mean(tma)*100,1),

    ttp_n = sum(ttp),
    ttp_pct = round(mean(ttp)*100,1),

    adam_n = sum(adam),
    adam_pct = round(mean(adam)*100,1),

    pe_n = sum(pe),
    pe_pct = round(mean(pe)*100,1),

    pe_hepatic_n =
      sum(pe & hepatic),

    pe_hepatic_among_pe_pct =
      round(
        ifelse(
          sum(pe)==0,
          NA,
          100*sum(pe & hepatic)/sum(pe)
        ),
        1
      ),

    drug_n = sum(drug),
    drug_pct = round(mean(drug)*100,1),

    any_treatment_n =
      sum(any_treatment),

    any_treatment_pct =
      round(mean(any_treatment)*100,1),

    icu_mortality_n =
      sum(icu_mortality),

    icu_mortality_pct =
      round(mean(icu_mortality)*100,1),

    hospital_mortality_n =
      sum(hospital_mortality),

    hospital_mortality_pct =
      round(mean(hospital_mortality)*100,1),

    .groups = "drop"
  ) %>%

  arrange(plasmic_worst)  

############################################################
# 12i. PLASMIC score = 7 
############################################################

plasmic7 <- patient_level %>%

  filter(
    plasmic_worst == 7
  )

    ############################################################
    # table
    ############################################################

    plasmic7_adam_summary <- plasmic7 %>%

    group_by(adam) %>%

    summarise(

        n_patients =
        n(),

        ########################################################
        # ICU mortality
        ########################################################

        icu_mortality_n =
        sum(icu_mortality),

        icu_mortality_pct =
        round(
            mean(icu_mortality) * 100,
            1
        ),

        ########################################################
        # Hospital mortality
        ########################################################

        hospital_mortality_n =
        sum(hospital_mortality),

        hospital_mortality_pct =
        round(
            mean(hospital_mortality) * 100,
            1
        ),

        .groups = "drop"
    )

############################################################
# 13. Save as CSV
############################################################

write.csv(
  plasmic_summary_all,
  file = paste0(
    output_dir,
    "plasmic_summary_all_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_sepsis,
  file = paste0(
    output_dir,
    "plasmic_summary_sepsis_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_nonsepsis,
  file = paste0(
    output_dir,
    "plasmic_summary_nonsepsis_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_all_jaam_lt4,
  file = paste0(
    output_dir,
    "plasmic_summary_all_jaam_lt4_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_all_jaam_ge4,
  file = paste0(
    output_dir,
    "plasmic_summary_all_jaam_ge4_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_sepsis_jaam_lt4,
  file = paste0(
    output_dir,
    "plasmic_summary_sepsis_jaam_lt4_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_sepsis_jaam_ge4,
  file = paste0(
    output_dir,
    "plasmic_summary_sepsis_jaam_ge4_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic7_adam_summary,
  file = paste0(
    output_dir,
    "plasmic7_adam_mortality_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_all_pt_lt30000,
  file = paste0(
    output_dir,
    "plasmic_summary_all_pt_lt30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_all_pt_ge30000,
  file = paste0(
    output_dir,
    "plasmic_summary_all_pt_ge30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_sepsis_pt_lt30000,
  file = paste0(
    output_dir,
    "plasmic_summary_sepsis_pt_lt30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_sepsis_pt_ge30000,
  file = paste0(
    output_dir,
    "plasmic_summary_sepsis_pt_ge30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_nonsepsis_pt_lt30000,
  file = paste0(
    output_dir,
    "plasmic_summary_nonsepsis_pt_lt30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)

write.csv(
  plasmic_summary_nonsepsis_pt_ge30000,
  file = paste0(
    output_dir,
    "plasmic_summary_nonsepsis_pt_ge30000_",
    output_ver,
    ".csv"
  ),
  row.names = FALSE
)
