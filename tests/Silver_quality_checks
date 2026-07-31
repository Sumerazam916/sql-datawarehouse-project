/*===============================================================================
Medallion Architecture: Silver-to-Gold Integration & Quality Audit Script
===============================================================================
Purpose:
    - Validates data integrity, entity relationships, and cross-system attribute 
      reconciliation during the transformation from Silver to Gold Star Schema.
Key Quality Audits:
    1. Foreign Key / Reference Integrity Checks (Category & Dimension Mappings)
    2. Data Multiplicity & Fan-Out Tests (Checking `LEFT JOIN` row duplication)
    3. Surrogate Key Uniqueness Verification (Evaluating `ROW_NUMBER()` logic)
    4. Conflict Resolution & Attribute Fusion Audits (CRM vs. ERP Gender precedence)
    5. Gold Star Schema Orphaned Fact Detection (Fact-to-Dimension Key Alignment)
===============================================================================*/


-- =============================================================================
-- SECTION 1: PRODUCT DIMENSION INTEGRATION TESTS (Silver.crm_prd_info & Silver.erp_PX_CAT_G1V2)
-- =============================================================================

-- 1.1 Category Reference Integrity Audit
-- Identifies product category IDs in CRM that fail to match category master records in ERP
SELECT * FROM Silver.crm_prd_info
WHERE cat_id NOT IN (
    SELECT cat_id
    FROM Silver.crm_prd_info ci
    LEFT JOIN Silver.erp_PX_CAT_G1V2 ca
        ON ci.cat_id = ca.id
);


-- 1.2 Baseline Source Row Count
-- Establishes baseline record count of Silver CRM Products prior to dimension joining
SELECT COUNT(*) 
FROM Silver.crm_prd_info;


-- 1.3 Join Multiplication / Fan-Out Test
-- Compares record count post-LEFT JOIN against baseline count.
-- If joined count > baseline count, it alerts to duplicate keys in ERP Category table (1-to-Many explosion).
SELECT COUNT(*) 
FROM (
    SELECT
        prd_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt,
        cat_id
    FROM Silver.crm_prd_info ci
    LEFT JOIN Silver.erp_PX_CAT_G1V2 ca
        ON ci.cat_id = ca.id
) t;


-- 1.4 Product Surrogate Key Uniqueness & Grain Test
-- Evaluates the proposed Gold Dimension structure (generating surrogate `prd_key` via `ROW_NUMBER()`).
-- Checks if grouping by `prd_id` produces duplicates (Verifies 1-row-per-product grain).
SELECT COUNT(*) 
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY prd_id) AS prd_key,      -- Generating Gold Surrogate Key
        prd_id,
        prd_key AS prd_number,                               -- Retaining source natural key
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt,
        cat_id,
        ca.cat,
        ca.subcat,
        ca.maintenance
    FROM Silver.crm_prd_info ci
    LEFT JOIN Silver.erp_PX_CAT_G1V2 ca
        ON ci.cat_id = ca.id
) t 
GROUP BY prd_id 
HAVING COUNT(*) > 1;


-- =============================================================================
-- SECTION 2: CUSTOMER DIMENSION INTEGRATION TESTS (Silver CRM & ERP Tables)
-- =============================================================================

-- 2.1 Customer Surrogate Key Uniqueness & Grain Test
-- Joins CRM Customer, ERP Demographics, and ERP Location tables.
-- Verifies that multi-source joining produces exactly 1 row per customer (`cst_id`).
SELECT COUNT(*) 
FROM (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY cst_id) AS cst_key,      -- Generating Gold Customer Surrogate Key
        cst_id,
        cst_key AS cst_num,                                  -- Retaining natural customer number
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date,
        cb.bdate,
        cb.gen,
        cc.cntry
    FROM Silver.crm_cust_info ca
    LEFT JOIN Silver.erp_CUST_AZ12 cb
        ON ca.cst_key = cb.cid
    LEFT JOIN Silver.erp_LOC_A101 cc
        ON ca.cst_key = cc.cid
) t 
GROUP BY cst_id 
HAVING COUNT(*) > 1;


-- 2.2 Gender Discrepancy & Fallback Precedence Test
-- Audits instances where CRM gender (`cst_gndr`) conflicts with ERP gender (`gen`).
-- Tests fallback logic: Use ERP gender only if CRM gender is missing/unassigned ('n/a').
SELECT 
    CASE 
        WHEN ca.cst_gndr = 'n/a' AND cb.gen IS NOT NULL AND cb.gen != 'n/a'
            THEN TRIM(gen)
        ELSE ca.cst_gndr
    END AS new_cst_gndr,
    cb.gen,
    cst_gndr
FROM Silver.crm_cust_info ca
LEFT JOIN Silver.erp_CUST_AZ12 cb
    ON ca.cst_key = cb.cid
LEFT JOIN Silver.erp_LOC_A101 cc
    ON ca.cst_key = cc.cid
WHERE ca.cst_gndr != cb.gen 
ORDER BY 1, 2;


-- 2.3 COALESCE Gender Consolidation Rule Verification
-- Evaluates final production logic: Prioritizes CRM gender; falls back to ERP gender; defaults to 'n/a'.
SELECT 
    CASE 
        WHEN ca.cst_gndr != 'n/a' THEN ca.cst_gndr
        ELSE COALESCE(cb.gen, 'n/a')
    END AS new_gen,
    cb.gen,
    cst_gndr
FROM Silver.crm_cust_info ca
LEFT JOIN Silver.erp_CUST_AZ12 cb
    ON ca.cst_key = cb.cid
LEFT JOIN Silver.erp_LOC_A101 cc
    ON ca.cst_key = cc.cid;


-- =============================================================================
-- SECTION 3: GOLD STAR SCHEMA INTEGRATION TESTS (Gold.fact_sales Audit)
-- =============================================================================

-- 3.1 Orphaned Fact & Referential Integrity Audit
-- Audits the Gold Fact table against Customer and Product dimensions to find unlinked sales records.

SELECT * FROM Gold.fact_sales aa
LEFT JOIN Gold.dim_customers ab
    ON aa.customer_key = ab.customer_key
LEFT JOIN Gold.dim_products ac
    ON aa.product_key = ac.product_key                     
WHERE ab.customer_key IS NULL 
   OR ab.customer_key IS NULL;                              -- Flags sales records missing dimension matches
