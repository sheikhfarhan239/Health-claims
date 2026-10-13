-- ============================================================
-- 04_claims_analysis.sql
-- Health Insurance Claims Analysis (MySQL 8.0+)
-- Run 01_create_tables.sql, 02_insert_data.sql and 03_data_validation.sql first.
-- ============================================================

USE health_claims;

-- Data preview
SELECT * FROM claims LIMIT 10;


-- ============================================================
-- 1. Claim Type Cost Breakdown
-- Total billed, total paid and number of claims per claim type,
-- ranked from most to least expensive by total paid.
-- ============================================================
SELECT claim_type,
       SUM(billed_amount) AS total_billed_amount,
       SUM(paid_amount)   AS total_paid_amount,
       COUNT(*)           AS total_claims,
       RANK() OVER (ORDER BY SUM(paid_amount) DESC) AS cost_rank
FROM claims
GROUP BY claim_type
ORDER BY cost_rank;

-- Findings:
-- * Inpatient is the most expensive claim type: about 1.09M paid, roughly 70% of the
--   1.55M total paid, from only 99 of 449 claims (about 22%).
-- * Emergency is second (about 294K). Outpatient, Lab and Pharmacy together are about 11%.


-- ============================================================
-- 2. CPT & ICD Cost Drivers
-- ============================================================

-- Top 10 CPT codes by total paid amount
WITH TotalPaid AS (
    SELECT cpt_code,
           SUM(paid_amount) AS total_paid_amount,
           COUNT(*)         AS claim_count
    FROM claims
    GROUP BY cpt_code
),
Rankings AS (
    SELECT cpt_code, total_paid_amount, claim_count,
           DENSE_RANK() OVER (ORDER BY total_paid_amount DESC) AS rank_nums
    FROM TotalPaid
)
SELECT cpt_code, total_paid_amount, claim_count
FROM Rankings
WHERE rank_nums <= 10
ORDER BY total_paid_amount DESC;

-- Findings:
-- * 67890 (about 243K from 25 claims) and 23456 (about 204K from 29 claims) are the two
--   biggest cost drivers. Together they account for about 29% of all paid.
-- * 12345 ranks 4th mainly through volume (47 claims), while 00123 and 99223 reach the
--   top 5 with only 12 and 6 claims, which means a high cost per claim.

-- Top 10 ICD codes by total paid amount
WITH TotalPaid AS (
    SELECT icd_code,
           SUM(paid_amount) AS total_paid_amount,
           COUNT(*)         AS claim_count
    FROM claims
    GROUP BY icd_code
),
Rankings AS (
    SELECT icd_code, total_paid_amount, claim_count,
           DENSE_RANK() OVER (ORDER BY total_paid_amount DESC) AS rank_nums
    FROM TotalPaid
)
SELECT icd_code, total_paid_amount, claim_count
FROM Rankings
WHERE rank_nums <= 10
ORDER BY total_paid_amount DESC;

-- Findings:
-- * I10 is the costliest diagnosis (about 260K paid, 34 claims), followed by A12.3
--   (about 152K, 42 claims) and B20 (about 141K, 17 claims).
-- * A01.1 (3 claims) and B99.4 (4 claims) make the top 10 on very few claims, so a few
--   expensive claims drive them.

-- Average paid per claim by CPT code: which procedures are most expensive?
-- Only codes with at least 2 claims are kept, because a code with a single
-- claim has an "average" equal to that one claim.
WITH TotalPaid AS (
    SELECT cpt_code,
           SUM(paid_amount) AS total_paid_amount,
           COUNT(*)         AS claim_count
    FROM claims
    GROUP BY cpt_code
)
SELECT cpt_code,
       claim_count,
       ROUND(total_paid_amount / claim_count, 2) AS average_paid_per_claim
FROM TotalPaid
WHERE claim_count >= 2
ORDER BY average_paid_per_claim DESC
LIMIT 10;

-- Findings:
-- * The most expensive procedures per claim are 00123 (about 10.2K), 67890 (about 9.7K)
--   and 99223 (about 9.6K).
-- * 00123 and 67890 are also top cost drivers by total paid, so they are expensive
--   per claim and billed often.
-- * Codes with 1 claim were excluded (97 of 134 CPT codes appear only once).


-- ============================================================
-- 3. Member-Level Analysis
-- ============================================================

-- Total paid amount per member
SELECT m.member_id,
       SUM(c.paid_amount) AS total_paid_amount
FROM members AS m
JOIN claims  AS c
  ON m.member_id = c.member_id
GROUP BY m.member_id
ORDER BY total_paid_amount DESC;

-- The 5 highest-cost members
WITH TotalPaid AS (
    SELECT m.member_id, SUM(c.paid_amount) AS total_paid_amount
    FROM members AS m
    JOIN claims  AS c
      ON m.member_id = c.member_id
    GROUP BY m.member_id
),
Rankings AS (
    SELECT member_id, total_paid_amount,
           DENSE_RANK() OVER (ORDER BY total_paid_amount DESC) AS rank_nums
    FROM TotalPaid
)
SELECT member_id, total_paid_amount
FROM Rankings
WHERE rank_nums <= 5
ORDER BY total_paid_amount DESC;

-- For each high-cost member: which claim types drive their costs?
WITH TotalPaid AS (
    SELECT m.member_id, SUM(c.paid_amount) AS total_paid_amount
    FROM members AS m
    JOIN claims  AS c
      ON m.member_id = c.member_id
    GROUP BY m.member_id
    ORDER BY total_paid_amount DESC
    LIMIT 5
)
SELECT c.member_id,
       c.claim_type,
       SUM(c.paid_amount) AS paid_by_type,
       ROUND(100 * SUM(c.paid_amount) / tp.total_paid_amount, 1) AS pct_of_member_total
FROM TotalPaid AS tp
JOIN claims    AS c
  ON tp.member_id = c.member_id
GROUP BY c.member_id, c.claim_type, tp.total_paid_amount
ORDER BY tp.total_paid_amount DESC, c.member_id, paid_by_type DESC;

-- Findings:
-- * The top 5 members (6, 32, 58, 82, 28) each cost between about 30.6K and 43.3K.
-- * For all five, Inpatient is the main driver (about 70% to 87% of the member's cost).
--   Emergency is usually second.


-- ============================================================
-- 4. Billed vs Paid Ratio
-- paid_ratio = paid_amount / billed_amount
-- avg_ratio  = average of each claim's own ratio
-- paid_ratio = SUM(paid) / SUM(billed), where large claims count for more
-- ============================================================

-- Overall paid ratio
SELECT ROUND(SUM(paid_amount) / SUM(billed_amount), 3) AS paid_ratio
FROM claims;
-- Finding: the insurer pays about 75 cents of every billed dollar overall (0.752).

-- By claim type
SELECT claim_type,
       COUNT(*) AS claim_count,
       ROUND(AVG(paid_amount / billed_amount), 3)      AS avg_ratio,
       ROUND(SUM(paid_amount) / SUM(billed_amount), 3) AS paid_ratio
FROM claims
GROUP BY claim_type
ORDER BY avg_ratio;
-- Findings:
-- * The insurer pays the least on Inpatient claims (average ratio 0.757) and the most on
--   Lab claims (0.915). Emergency (0.785) is also paid below the overall level.
-- * No claim type is paid above billed: the highest ratio possible here is 1.0.
--   (Data check: no claim has paid_amount greater than billed_amount.)

-- By provider (providers with at least 5 claims, so one claim cannot decide the result)
SELECT provider_id,
       COUNT(*) AS claim_count,
       ROUND(AVG(paid_amount / billed_amount), 3)      AS avg_ratio,
       ROUND(SUM(paid_amount) / SUM(billed_amount), 3) AS paid_ratio
FROM claims
GROUP BY provider_id
HAVING COUNT(*) >= 5
ORDER BY avg_ratio;
-- Findings (18 providers with 5+ claims):
-- * Ratios range from 0.785 (PRV54321) to 0.916 (PRV13579).
-- * For many providers the weighted paid_ratio is well below avg_ratio
--   (for example PRV98765: 0.789 vs 0.662), meaning their largest claims are paid at
--   lower rates than their small ones.

-- By CPT code (codes with at least 5 claims)
SELECT cpt_code,
       COUNT(*) AS claim_count,
       ROUND(AVG(paid_amount / billed_amount), 3)      AS avg_ratio,
       ROUND(SUM(paid_amount) / SUM(billed_amount), 3) AS paid_ratio
FROM claims
GROUP BY cpt_code
HAVING COUNT(*) >= 5
ORDER BY avg_ratio;
-- Findings (22 CPT codes with 5+ claims):
-- * Ratios range from 0.749 (54321) to 0.936 (80053).
-- * 67890, the top cost driver, is among the lowest-paid at 0.752: the most expensive
--   procedures are paid at a smaller share of what is billed.
