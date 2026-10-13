-- ============================================================
-- 03_data_validation.sql
-- Checks run on the data before any analysis.
-- Expected results are noted next to each check.
-- ============================================================

USE health_claims;

-- 1. Row counts (expect 100 members, 449 claims)
SELECT COUNT(*) AS members_count FROM members;
SELECT COUNT(*) AS claims_count  FROM claims;

-- 2. NULL check on members. Only enrollment_end_date may be NULL
--    (NULL = member still enrolled). Expect 15.
SELECT
    COUNT(*) AS total,
    SUM(CASE WHEN member_id             IS NULL THEN 1 ELSE 0 END) AS null_member_id,
    SUM(CASE WHEN member_age            IS NULL THEN 1 ELSE 0 END) AS null_member_age,
    SUM(CASE WHEN member_gender         IS NULL THEN 1 ELSE 0 END) AS null_member_gender,
    SUM(CASE WHEN plan_type             IS NULL THEN 1 ELSE 0 END) AS null_plan_type,
    SUM(CASE WHEN enrollment_start_date IS NULL THEN 1 ELSE 0 END) AS null_start_date,
    SUM(CASE WHEN enrollment_end_date   IS NULL THEN 1 ELSE 0 END) AS null_end_date
FROM members;

-- 3. Duplicate members: same details under a different member_id (expect no rows)
SELECT member_age, member_gender, plan_type, enrollment_start_date, enrollment_end_date,
       COUNT(*) AS copies
FROM members
GROUP BY member_age, member_gender, plan_type, enrollment_start_date, enrollment_end_date
HAVING COUNT(*) > 1;

-- 4. Duplicate claims: same member, provider, date, type, codes and amounts
--    under a different claim_id (expect no rows)
SELECT member_id, provider_id, claim_date, claim_type, cpt_code, icd_code,
       billed_amount, paid_amount, COUNT(*) AS copies
FROM claims
GROUP BY member_id, provider_id, claim_date, claim_type, cpt_code, icd_code,
         billed_amount, paid_amount
HAVING COUNT(*) > 1;

-- 5. Paid amount greater than billed amount (expect no rows)
SELECT * FROM claims WHERE paid_amount > billed_amount;

-- 6. Zero amounts: billed = 0 would break the paid-ratio division (expect 0);
--    paid = 0 would mean a denied claim.
SELECT SUM(billed_amount = 0) AS zero_billed,
       SUM(paid_amount   = 0) AS zero_paid
FROM claims;

-- 7. Claims dated after the member's enrollment end date.
--    Members with no end date are still enrolled and are not counted.
--    Finding: 260 of 449 claims. Could be late-arriving claims or a data issue.
SELECT COUNT(*) AS claims_after_enrollment_end
FROM claims AS c
JOIN members AS m ON m.member_id = c.member_id
WHERE c.claim_date > m.enrollment_end_date;

-- 8. CPT codes that are not 5 characters long, or have stray spaces
--    (CPT codes are normally 5 characters)
SELECT cpt_code, LENGTH(cpt_code) AS code_length, COUNT(*) AS claim_count,
       ROUND(SUM(paid_amount), 2) AS total_paid
FROM claims
WHERE LENGTH(cpt_code) <> 5 OR cpt_code <> TRIM(cpt_code)
GROUP BY cpt_code
ORDER BY claim_count DESC;
