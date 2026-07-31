/*===============================================================================
Medallion Architecture: Bronze to Silver Data Cleansing & Validation Script
===============================================================================
Purpose:
    - Performs Data Profiling, Quality Audits, and Transformations on raw 
      Bronze Layer tables (CRM & ERP sources) to prepare them for Silver loading.
Key Cleaning Rules:
    1. Primary Key Uniqueness & Integrity Inspections
    2. String Standardizations (Trimming spaces, string slicing, prefix removal)
    3. Null Handling & Default Fallbacks (`ISNULL`, zero replacements)
    4. Date Format Standardizations (Converting YYYYMMDD integers to DATE data types)
    5. Domain-Logic Financial & Cross-Column Validation Checks
    6. Categorical Value Mapping (Gender & Country standardization)
===============================================================================*/


-- =============================================================================
-- SECTION 1: CRM PRODUCT DATA (Bronze.crm_prd_info / Silver.crm_prd_info)
-- =============================================================================

-- 1.1 Source Table Inspection
-- Raw dump review of Bronze CRM product entity
SELECT * 
FROM Bronze.crm_prd_info;


-- 1.2 Uniqueness & Null Primary Key Validation (Silver Layer Audit)
-- Checks for duplicate primary keys or missing key values in Silver
SELECT 
    prd_id, 
    COUNT(*) AS occurences 
FROM Silver.crm_prd_info 
GROUP BY prd_id 
HAVING COUNT(*) > 1 OR prd_id IS NULL;


-- 1.3 Key Nullity Check (Bronze Layer Audit)
-- Verifies if raw product surrogate keys contain NULL values
SELECT prd_key 
FROM Bronze.crm_prd_info 
WHERE prd_key IS NULL;


-- 1.4 Formatting Check: Unwanted Spaces
-- Identifies strings with leading/trailing spaces that require TRIM cleansing
SELECT prd_nm 
FROM Bronze.crm_prd_info 
WHERE prd_nm != TRIM(prd_nm);


-- 1.5 String Parsing & Cost Imputation Test
-- Parses composite prd_key into Category ID and Product ID substrings.
-- Imputes NULL costs with 0 to prevent downstream aggregation issues.
SELECT prd_cost
FROM (
    SELECT 
        prd_id,
        prd_key,
        SUBSTRING(prd_key, 1, 5) AS cat_id,                  -- First 5 chars represent Category ID
        SUBSTRING(prd_key, 6, LEN(prd_key)) AS product_id,   -- Remaining chars represent Product ID
        prd_nm,
        ISNULL(prd_cost, 0) AS prd_cost,                     -- Default missing cost to 0
        prd_line,
        prd_start_dt,
        prd_end_dt  
    FROM Silver.crm_prd_info 
) t 
WHERE prd_cost IS NULL;


-- 1.6 Temporal Integrity Check
-- Detects invalid logical timelines where effective start date postdates end date
SELECT * 
FROM Silver.crm_prd_info 
WHERE prd_start_dt > prd_end_dt 
ORDER BY prd_start_dt;


-- =============================================================================
-- SECTION 2: CRM SALES DATA (Bronze.crm_sales_details)
-- =============================================================================

-- 2.1 Foreign Key Referential Integrity & Integer-to-Date Parsing
-- Validates YYYYMMDD integer dates and converts them into SQL DATE types.
-- Filters out sales records whose product keys do not exist in Silver Product Dim (Orphan Records).
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,

    -- Date Parsing Rule: Standardizes YYYYMMDD integer representation to DATE type
    CASE 
        WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS NVARCHAR) AS DATE)
    END AS sls_order_dt,

    CASE 
        WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS NVARCHAR) AS DATE)
    END AS sls_ship_dt,

    CASE 
        WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_due_dt AS NVARCHAR) AS DATE)
    END AS sls_due_dt,

    sls_sales,
    sls_quantity,
    sls_price
FROM Bronze.crm_sales_details 
WHERE sls_prd_key NOT IN (SELECT prd_key FROM Silver.crm_prd_info);


-- 2.2 Date Outlier & Boundary Testing
-- Flags dates outside the plausible business boundary (1990 to 2050) or invalid lengths
SELECT sls_due_dt 
FROM Bronze.crm_sales_details 
WHERE sls_due_dt <= 0 
   OR LEN(sls_due_dt) != 8 
   OR sls_due_dt < 19900101 
   OR sls_due_dt > 20500101;


-- 2.3 Chronological Sequence Check
-- Flags shipping or due dates occurring BEFORE the order date (Logical impossible state)
SELECT * 
FROM Bronze.crm_sales_details 
WHERE sls_due_dt < sls_order_dt 
   OR sls_ship_dt < sls_order_dt;


-- 2.4 Financial Integrity & Equation Audit
-- Detects financial discrepancies where Sales != Price * Quantity or contains non-positive numbers
SELECT DISTINCT 
    sls_sales,
    sls_price, 
    sls_quantity 
FROM Silver.crm_sales_details
WHERE sls_sales != sls_price * sls_quantity 
   OR sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL 
   OR sls_sales <= 0 OR sls_price <= 0 OR sls_quantity <= 0
ORDER BY sls_sales, sls_price, sls_quantity;


-- 2.5 Financial Recalculation & Data Repair
-- Automatically corrects negative/missing price and sales values using mathematical relationships
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    
    CASE 
        WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS NVARCHAR) AS DATE)
    END AS sls_order_dt,
    
    CASE 
        WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS NVARCHAR) AS DATE)
    END AS sls_ship_dt,
    
    CASE 
        WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_due_dt AS NVARCHAR) AS DATE)
    END AS sls_due_dt,
    
    sls_sales AS OLD_sls_sales,
    sls_price AS OLD_sls_price,
    
    -- Recalculate Sales Amount if missing, negative, or mathematically inconsistent
    CASE 
        WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,

    -- Recalculate Unit Price if missing or negative using Sales / Quantity
    CASE 
        WHEN sls_price <= 0 OR sls_price IS NULL
            THEN sls_sales / ISNULL(sls_quantity, 0)
        ELSE sls_price
    END AS sls_price,

    sls_quantity
FROM Bronze.crm_sales_details 
WHERE sls_quantity > 1;


-- =============================================================================
-- SECTION 3: ERP CUSTOMER DATA (Bronze.erp_CUST_AZ12)
-- =============================================================================

-- 3.1 Unmatched Customer Audit
-- Identifies customer IDs present in ERP system but absent in CRM Master dataset
SELECT * 
FROM Bronze.erp_CUST_AZ12 
WHERE cid NOT IN (SELECT cst_key FROM Silver.crm_cust_info);


-- 3.2 Key Standardization & Prefix Cleaning
-- Strips system prefixes ('NAS') from ERP customer keys to align formats with CRM keys
SELECT * 
FROM (
    SELECT
        cid,
        CASE 
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(UPPER(TRIM(cid)), 4, LEN(cid))
            ELSE cid
        END AS NEW_cid,
        bdate,
        gen
    FROM Bronze.erp_CUST_AZ12
) t
WHERE t.NEW_cid NOT IN (SELECT cst_key FROM Silver.crm_cust_info WHERE cst_key IS NOT NULL);


-- 3.3 Birth Date Boundary Validation
-- Flags extreme outlier birthdates (e.g., future dates or before 1920)
SELECT bdate 
FROM Bronze.erp_CUST_AZ12 
WHERE bdate > '20500101' OR bdate < '19200101';


-- 3.4 Future Birth Date Nullification
-- Invalidates birth dates occurring in the future relative to system execution time
SELECT
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(UPPER(TRIM(cid)), 4, LEN(cid))
        ELSE cid
    END AS cid,
    bdate,
    CASE 
        WHEN bdate > GETDATE() THEN NULL
        ELSE bdate
    END AS newbdate,
    gen
FROM Bronze.erp_CUST_AZ12 
WHERE bdate > '20260505';


-- 3.5 Gender Field Categorical Normalization
-- Standardizes multi-source gender variants ('M','F','MALE','FEMALE') into clean domain values
SELECT
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(UPPER(TRIM(cid)), 4, LEN(cid))
        ELSE cid
    END AS cid,

    CASE 
        WHEN bdate > GETDATE() THEN NULL
        ELSE bdate
    END AS bdate,

    -- Categorical Mapping: Normalizes gender strings to standardized Title Case
    CASE 
        WHEN UPPER(TRIM(gen)) IN ('FEMALE', 'F') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('MALE', 'M') THEN 'Male' 
        WHEN UPPER(TRIM(gen)) = '' THEN NULL 
        ELSE gen
    END AS newgen,
    gen
FROM Bronze.erp_CUST_AZ12 
WHERE gen IN ('M', 'F', ' ');


-- 3.6 Silver Validation Verification
-- Final quality check ensuring no future birth dates exist in Silver ERP dataset
SELECT * 
FROM Silver.erp_CUST_AZ12 
WHERE bdate > GETDATE();


-- =============================================================================
-- SECTION 4: ERP LOCATION DATA (Bronze.erp_LOC_A101)
-- =============================================================================

-- 4.1 Uniqueness Check on ERP Location Primary Keys
SELECT cid, COUNT(*)	
FROM Bronze.erp_LOC_A101  
GROUP BY cid  
HAVING COUNT(*) > 1 
ORDER BY cid;


-- 4.2 Country Code Profiling
SELECT DISTINCT cntry 
FROM Bronze.erp_LOC_A101 
ORDER BY cntry;


-- 4.3 Key Sanitization & Country Standardization
-- Removes hyphens from Customer IDs and normalizes country abbreviations ('DE','US','USA')
SELECT DISTINCT cntry 
FROM (
    SELECT 
        REPLACE(cid, '-', '') AS cid,                         -- Strips formatting hyphens
        CASE 
            WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'GERMANY'
            WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
            WHEN UPPER(TRIM(cntry)) = '' OR UPPER(TRIM(cntry)) IS NULL THEN 'n/a'
            ELSE cntry
        END AS cntry
    FROM Bronze.erp_LOC_A101
) t;


-- =============================================================================
-- SECTION 5: ERP PRODUCT CATEGORY DATA (Bronze.erp_PX_CAT_G1V2)
-- =============================================================================

-- 5.1 Categorical Value Audits
SELECT DISTINCT cat FROM Bronze.erp_PX_CAT_G1V2;
SELECT DISTINCT subcat FROM Bronze.erp_PX_CAT_G1V2;
SELECT DISTINCT maintenance FROM Bronze.erp_PX_CAT_G1V2;


-- 5.2 Whitespace Audit
-- Flags entries with hidden leading/trailing spaces across product taxonomy dimensions
SELECT * 
FROM Bronze.erp_PX_CAT_G1V2
WHERE cat != TRIM(cat) 
   OR subcat != TRIM(subcat) 
   OR maintenance != TRIM(maintenance);
