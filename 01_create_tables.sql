-- ============================================================
-- 01_create_tables.sql
-- Project: Health Insurance Claims Analysis
-- Creates the database and two tables: members and claims.
-- Works on MySQL 8.0.16+ (CHECK constraints are enforced from there).
-- ============================================================

CREATE DATABASE IF NOT EXISTS health_claims;
USE health_claims;

-- Drop the child table (claims) BEFORE the parent (members),
-- otherwise the foreign key blocks the drop.
DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS members;

-- ------------------------------------------------------------
-- members: one row per insured person (the "parent" table)
-- ------------------------------------------------------------
CREATE TABLE members (
    member_id             INT UNSIGNED NOT NULL,
    member_age            TINYINT UNSIGNED NOT NULL,
    member_gender         ENUM('F','M') NOT NULL,
    plan_type             ENUM('PPO','HMO','EPO','POS') NOT NULL,
    enrollment_start_date DATE NOT NULL,
    enrollment_end_date   DATE NULL,          -- NULL = still enrolled
    PRIMARY KEY (member_id),
    CONSTRAINT chk_enrollment_dates
        CHECK (enrollment_end_date IS NULL
               OR enrollment_end_date >= enrollment_start_date)
);

-- ------------------------------------------------------------
-- claims: one row per claim submitted (the "child" table)
-- Each claim belongs to exactly one member.
-- ------------------------------------------------------------
CREATE TABLE claims (
    claim_id      INT UNSIGNED NOT NULL,
    member_id     INT UNSIGNED NOT NULL,
    provider_id   VARCHAR(10)  NOT NULL,
    claim_date    DATE         NOT NULL,
    claim_type    ENUM('Outpatient','Inpatient','Emergency','Pharmacy','Lab') NOT NULL,
    cpt_code      VARCHAR(10)  NOT NULL,      -- text, not a number (see notes)
    icd_code      VARCHAR(10)  NOT NULL,
    billed_amount DECIMAL(10,2) NOT NULL,
    paid_amount   DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (claim_id),
    CONSTRAINT fk_claims_member
        FOREIGN KEY (member_id) REFERENCES members (member_id),
    CONSTRAINT chk_amounts_not_negative
        CHECK (billed_amount >= 0 AND paid_amount >= 0),
    INDEX idx_claims_member   (member_id),
    INDEX idx_claims_date     (claim_date),
    INDEX idx_claims_provider (provider_id)
);

-- ------------------------------------------------------------
-- Check your work (run these after the script):
--   SHOW TABLES;
--   DESCRIBE members;
--   DESCRIBE claims;
-- ------------------------------------------------------------
