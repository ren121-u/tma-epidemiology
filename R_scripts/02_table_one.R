# ===============================
# Packages
# ===============================
if (!require('tidyverse')) install.packages('tidyverse')
if (!require('tableone')) install.packages('tableone')

library(tidyverse)
library(tableone)
library(mgcv)

# ===============================
# Directories
# ===============================
data_dir   <- './data/'
output_dir <- './output/tableone/'
data_ver   <- '20260821'
output_ver <- '20260821'

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ===============================
# Load data
# ===============================
df <- read.csv(paste0(data_dir, data_ver, '_tma_base.csv'))

# ===============================
# Variable formatting
# ===============================
df <- df %>%
  mutate(
    # Categorical variables
    # Only Male is reported for sex and only Yes for mv/vasopressor/rrt,
    # Place the level to be reported as the first level of the factor
    sex = factor(female, levels = c(0,1), labels = c("Male","Female")),
    icu_admission_type = factor(icu_admission_type, levels = c("emergency","scheduled_surgery"), labels = c("Emergency","Surgery")),
    tma  = factor(tma_flag, levels = c(1,0), labels = c("Yes","No")),
    ttp  = factor(ttp_flag, levels = c(1,0), labels = c("Yes","No")),
    sepsis  = factor(sepsis_flag, levels = c(1,0), labels = c("Yes","No")),
    dic  = factor(dic_flag, levels = c(1,0), labels = c("Yes","No")),
    ADAMTS13  = factor(adam_flag, levels = c(0,1), labels = c("ADAMTS13 not examined","ADAMTS13 examined")),
    mechanical_ventilation = factor(mv_use, levels = c(1,0), labels = c("Yes","No")),
    vasopressor = factor(vaso_use, levels = c(1,0), labels = c("Yes","No")),
    rrt = factor(rrt_use, levels = c(1,0), labels = c("Yes","No"))
  )

# Variable definitions
vars <- c(
  "age",
  "sex",
  "body_weight",
  "icu_admission_type",
  "pt_min",
  "cre_min",
  "ret_max",
  "hp_min",
  "ib_max",
  "mcv_min",
  "pt_inr_min",
  "ck_max",
  "ld_max",
  "hb_min",
  "fdp_max",
  "d_dimer_max",
  "apache2_score",
  "sofa_max",
  "tma",
  "ttp",
  "sepsis",
  "dic",
  "mechanical_ventilation",
  "vasopressor",
  "rrt"
)

# Categorical variables
catVars <- c("sex", "icu_admission_type", "tma", "ttp", "sepsis", "dic", "mechanical_ventilation", "vasopressor", "rrt")

# Build Table 1 (stratified by ADAMTS13)
table1 <- CreateTableOne(
  vars = vars,
  strata = "ADAMTS13",
  factorVars = catVars,
  data = df,
  addOverall = TRUE
)

# ===============================
# Output (median [IQR], n (%))
# Use one decimal place for both continuous and categorical variables
# Because units and the " (median [IQR])" / " (%)" annotations are given in the table legend,
# removed from the body of the table.
# ===============================
table1_out <- print(
  table1,
  nonnormal = vars,
  quote = FALSE,
  noSpaces = TRUE,
  showAllLevels = TRUE,
  test = FALSE,
  smd = TRUE,
  printToggle = FALSE,
  contDigits = 1,
  catDigits = 1
)

# ===============================
# Helper function to control the number of digits displayed
# ===============================
format_median_iqr <- function(x, digits = 1){

  med <- median(x, na.rm = TRUE)
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)

  sprintf(
    paste0("%.", digits, "f [%." , digits, "f, %.", digits, "f]"),
    med, q1, q3
  )
}

replace_row <- function(table1_out, row_name, variable, digits){

  table1_out[row_name, "Overall"] <-
    format_median_iqr(df[[variable]], digits)

  table1_out[row_name, "ADAMTS13 not examined"] <-
    format_median_iqr(df[[variable]][df$adam_flag == 0], digits)

  table1_out[row_name, "ADAMTS13 examined"] <-
    format_median_iqr(df[[variable]][df$adam_flag == 1], digits)

  table1_out
}

# ===============================
# Remove unnecessary level rows
#   - Drop the "Female" row for sex (show "Male" only)
#   - Drop the "No" rows for mv / rrt (show "Yes" only)
# Because the first level of each factor is set to the level to be kept,
#   The rows to keep (Male / Yes) are header rows, and the rows to drop are those immediately below them.
# ===============================
level_col <- table1_out[, "level"]
rows_to_drop <- level_col %in% c("Female", "No")
table1_out <- table1_out[!rows_to_drop, , drop = FALSE]

# ===============================
# Format labels for the manuscript
#   - Capitalize the first letter
#   - Append units in parentheses
#   - Replace underscores with spaces
# ===============================
label_map <- c(
  "age" = "Age, years",
  "sex" = "Male, n (%)",
  "body_weight" = "Body weight, kg",
  "icu_admission_type" = "ICU admission type, n (%)",

  "pt_min" = "Platelet count, ×10³/µL",
  "cre_min" = "Creatinine, mg/dL",
  "ret_max" = "Reticulocyte, %",
  "hp_min" = "Haptoglobin, mg/dL",
  "ib_max" = "Indirect bilirubin, mg/dL",
  "mcv_min" = "MCV, fL",
  "pt_inr_min" = "PT-INR",
  "ck_max" = "Creatine kinase, U/L",
  "ld_max" = "LDH, U/L",
  "hb_min" = "Hemoglobin, g/dL",
  "fdp_max" = "FDP, µg/mL",
  "d_dimer_max" = "D-dimer, µg/mL",

  "apache2_score" = "APACHE II score",
  "sofa_max" = "SOFA score",

  "tma" = "TMA, n (%)",
  "ttp" = "TTP, n (%)",
  "sepsis" = "Sepsis, n (%)",
  "dic" = "DIC, n (%)",

  "mechanical_ventilation" = "Mechanical ventilation, n (%)",
  "vasopressor" = "Vasopressor use, n (%)",
  "rrt" = "Renal replacement therapy, n (%)"
)

# the suffixes " (median [IQR])", " (%)" and " = <level>" that tableone adds automatically
# are stripped to recover the original variable names.
strip_suffix <- function(x) {
  x <- sub(" \\(median \\[IQR\\]\\)$", "", x)
  x <- sub(" \\(%\\)$", "", x)
  x <- sub(" = .*$", "", x)
  x
}

new_rownames <- vapply(
  rownames(table1_out),
  function(x) {
    var <- strip_suffix(x)
    if (nzchar(var) && var %in% names(label_map)) {
      label_map[[var]]
    } else {
      x
    }
  },
  character(1)
)

rownames(table1_out) <- new_rownames

table1_out <- replace_row(table1_out, "Age, years", "age", 0)
table1_out <- replace_row(table1_out, "Platelet count, ×10³/µL", "pt_min", 0)
table1_out <- replace_row(table1_out, "PT-INR", "pt_inr_min", 2)
table1_out <- replace_row(table1_out, "Creatine kinase, U/L", "ck_max", 0)
table1_out <- replace_row(table1_out, "LDH, U/L", "ld_max", 0)
table1_out <- replace_row(table1_out, "APACHE II score", "apache2_score", 0)
table1_out <- replace_row(table1_out, "SOFA score", "sofa_max", 0)

# Print（with SMD）
print(
  table1_out,
  showAllLevels = TRUE,
  smd = TRUE,
  quote = FALSE,
  noSpaces = TRUE
)

View(table1_out)

# ===============================
# Save
# ===============================
write.csv(
  table1_out,
  paste0(output_dir, "table1_", output_ver, ".csv"),
  row.names = TRUE
)