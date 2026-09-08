# tma-epidemiology

This repository contains SQL and R code to analyze ADAMTS13 testing, TMA and TTP diagnoses, and in-hospital mortality according to the maximum PLASMIC score.
Using data from 6 ICUs in Japan between 2018 and 2025, recorded in the OneICU database, the scripts extract PLASMIC scores and presence of ADAMTS13 testing, TMA (including TTP), and in-hospital-death. Then the proportion of patients undergoing ADAMTS13 testing, the frequency of TMA and TTP diagnoses, and mortality were tabulated within the category of PLASMIC score.

---
## Table of Contents
- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Usage](#usage)
  - [SQL Queries](#sql-queries)
  - [R Scripts](#r-scripts)
- [Contact](#contact)
- [License](#license)

---
## Overview
The TMA-Epidemiology repository includes:

1. SQL code to extract PLASMIC scores, ADAMTS13 testing, diagnoses, and mortality from the OneICU database.
2. R scripts to create the main descriptive table, and the baseline characteristics table.

The study population consists of patients admitted to 6 ICUs in Japan between 2018 and December 2025, in which ADAMTS13 test is available. Patients younger than 18 years, and patients with not first ICU admission are excluded.

By running these scripts, researchers can reproduce the analysis of this research.

---
## Repository Structure
```
TMA-Epidemiology
├── README.md
├── LICENSE
├── sql
│   ├── 01_plasmic_score.sql
│   ├── 02_eligibility_criteria.sql
│   ├── 03_static_variables.sql
│   └── 04_all_data.sql
└── R_scripts
    ├── 01_plasmic_table.R
    └── 02_table_one.R
```

### `sql`
SQL scripts to extract the study population, PLASMIC scores, ADAMTS13 testing, diagnoses, and mortality from the OneICU database in Google BigQuery. The numbering indicates the order of execution: each script refers to the tables created by the scripts before it.

| Script | Contents |
| --- | --- |
| `01_plasmic_score.sql` | Calculating plasmic score of each patients |
| `02_eligibility_criteria.sql` | Application of the inclusion and exclusion criteria |
| `03_static_variables.sql` | Baseline patient characteristics |
| `04_all_data.sql` | Extracting ADAMTS13 testing, diagnoses, and mortality |


### `R_scripts`
R scripts to create the main descriptive table, and the baseline characteristics table.

| Directory / file | Contents |
| --- | --- |
| `01_plasmic_table` | Tabulating the proportion of patients undergoing ADAMTS13 testing, the frequency of TMA and TTP diagnoses, and mortality stratified by PLASMIC score |
| `02_table_one.R` | Baseline characteristics table |

---
## Requirements
1. Google BigQuery Access
    - To run the SQL scripts, you will need access to Google BigQuery and appropriate credentials to query the OneICU database.
2. R
    - R (version 4.4 or higher recommended).
3. R Packages
    - `tidyverse` (including `dplyr` and `tidyr`), `mgcv`, and `tableone`.

---
## Usage

The scripts read their input from a `data` directory and write their figures and tables to an `output` directory. Neither directory is included in this repository; create them locally and adjust the paths defined at the top of each script to match your environment.

### SQL Queries
1. Navigate to the `sql` directory.
2. Run the scripts in the order given by their numbering, saving the result of each script as a table **named after the script itself** (for example, `03_static_variables.sql` is saved as the table `03_static_variables`). Later scripts refer to these tables by that name.
  - Ensure that you have access to the OneICU database and that your [BigQuery billing project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) is configured correctly.
  - The dataset name in the `from` clauses (`medicu-production.research_tma_epidemiology_2026`) must be replaced with your own project and dataset.
3. Export the resulting tables as CSV files into your local `data` directory.

### R Scripts
1. Clone this repository or download the files locally.
2. Open your R environment (RStudio or equivalent).
3. Install any missing R packages with:
  ```r
  install.packages("<package_name>")
  ```
4. Set `data_dir`, `output_dir`, and the data version at the top of each script.
5. Run the scripts to generate the tables.

---
## Contact
For questions or collaboration inquiries, please reach out to us by email:
 - [MeDiCU, Inc.](mailto:info@medicu.co.jp)

---
## License
This project is licensed under the GNU General Public License (GPL) - see the [LICENSE](LICENSE) file for details.

---
**Disclaimer:**
The code in this repository is provided for academic research and educational purposes. Individual patient data are not provided.
