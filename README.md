# Health Insurance Claims Analysis (MySQL)

SQL analysis of health insurance claims: which claim types, procedures and diagnoses drive cost, which members cost the most and why, and how much the insurer pays compared with what providers bill.

**Tools:** MySQL 8.0 (joins, CTEs, window functions, aggregation), Tableau Public

**Dashboard:** [View on Tableau Public](https://public.tableau.com/app/profile/mohammed.farhan.sheikh/viz/PortfolioProject2_17918873938310/Dashboard1)

## Dataset

Two related tables (100 members, 449 claims):

**members**: one row per insured person

| Column | Type | Description |
|---|---|---|
| member_id | INT (primary key) | Member identifier |
| member_age | TINYINT | Age |
| member_gender | ENUM('F','M') | Gender |
| plan_type | ENUM('PPO','HMO','EPO','POS') | Plan type |
| enrollment_start_date | DATE | Enrollment start |
| enrollment_end_date | DATE (nullable) | Enrollment end; NULL means still enrolled |

**claims**: one row per claim; each claim belongs to one member (foreign key to `members`)

| Column | Type | Description |
|---|---|---|
| claim_id | INT (primary key) | Claim identifier |
| member_id | INT (foreign key) | Member who made the claim |
| provider_id | VARCHAR(10) | Provider identifier |
| claim_date | DATE | Date of claim |
| claim_type | ENUM | Outpatient, Inpatient, Emergency, Pharmacy, Lab |
| cpt_code | VARCHAR(10) | Procedure code, stored as text so leading zeros are kept |
| icd_code | VARCHAR(10) | Diagnosis code |
| billed_amount | DECIMAL(10,2) | Amount billed by the provider |
| paid_amount | DECIMAL(10,2) | Amount paid by the insurer |

> **Data note:** This is a synthetic dataset. It contains no real member information.

## Data validation (`sql/03_data_validation.sql`)

Checked before analysis:

- Row counts match the source files: 100 members, 449 claims.
- Only `enrollment_end_date` has NULLs (15 members, who are still enrolled).
- No duplicate members and no duplicate claims.
- No claim has a paid amount greater than its billed amount; none has a billed amount of 0 (needed for the ratio calculations).
- 2 claims have a paid amount of 0 (denied claims): one Inpatient, one Pharmacy.

**Data issues noted:**

- **260 of 449 claims are dated after the member's enrollment end date.** This may be late-arriving claims or a data quality issue. It does not affect the analyses below, which do not use enrollment dates.
- **6 claims have CPT values that are not standard 5-character codes**: `GPI1234`, `IRX123`, `9230`, `0210090`, and two with stray leading spaces. They are small claims, except `0210090` (9,800 paid), and do not change the top-10 results. CPT codes are stored as text, so valid codes like `00123` keep their leading zeros.

## Analysis and findings (`sql/04_claims_analysis.sql`)

### 1. Claim type cost breakdown

| Claim type | Total paid | Claims |
|---|---|---|
| Inpatient | 1,092,456.00 | 99 |
| Emergency | 294,441.36 | 88 |
| Outpatient | 129,052.75 | 105 |
| Lab | 23,412.35 | 76 |
| Pharmacy | 11,382.45 | 81 |

Inpatient claims are about 22% of all claims but about 70% of the 1.55M total paid.

### 2. CPT and ICD cost drivers

- The biggest CPT cost drivers are `67890` (about 243K, 25 claims) and `23456` (about 204K, 29 claims), together about 29% of all paid.
- The costliest diagnoses are `I10` (about 260K), `A12.3` (about 152K) and `B20` (about 141K).
- Most expensive per claim (codes with 2+ claims): `00123` (about 10.2K), `67890` (about 9.7K) and `99223` (about 9.6K). Codes with a single claim were excluded because their average is just one claim.

### 3. Member-level analysis

- The five highest-cost members (6, 32, 58, 82, 28) each cost about 30.6K to 43.3K.
- For all five, **Inpatient claims are the main driver**, at about 70% to 87% of each member's cost. Emergency claims are usually second.

### 4. Billed vs paid ratio

- Overall, the insurer pays about **75 cents of every billed dollar** (0.752).
- By claim type, the insurer pays least on **Inpatient** (0.757 average ratio) and most on **Lab** (0.915).
- No claim type is paid above billed.
- Among 18 providers with 5+ claims, ratios range from 0.785 to 0.916. Among 22 CPT codes with 5+ claims, they range from 0.749 to 0.936.
- The top cost driver, `67890`, is among the lowest-paid codes (0.752): the most expensive procedures are paid at a smaller share of what is billed.

Two averages are shown: `avg_ratio` averages each claim's own ratio, and `paid_ratio` is total paid divided by total billed, where large claims count for more. A minimum of 5 claims was used for providers and CPT codes so that a single claim cannot decide the result.

## Repository structure

```
health-claims-sql/
├── README.md
├── data/
│   ├── members.csv
│   ├── claims.csv
│   └── tableau_tables/      # query results used to build the Tableau dashboards
└── sql/
    ├── 01_create_tables.sql
    ├── 02_insert_data.sql
    ├── 03_data_validation.sql
    └── 04_claims_analysis.sql
```

## How to run

1. Run `sql/01_create_tables.sql` to create the `health_claims` database and tables.
2. Run `sql/02_insert_data.sql` to load the data (no file paths needed). The last line should show 100 members and 449 claims.
3. Run `sql/03_data_validation.sql`, then `sql/04_claims_analysis.sql`.

Run each script in full (Ctrl+A, then Ctrl+Shift+Enter in MySQL Workbench). The analysis needs MySQL 8.0 or later.
