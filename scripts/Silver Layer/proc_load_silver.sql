/*
===============================================================================
Stored procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script purpose:
    Okay so This stored procedure performs the ETL process to populate the Silver layer
    tables from the Bronze layer...........

actions performed here:
    - Truncates Silver tables.
    - Inserts cleaned and transformed data from Bronze tables into Silver tables.
    - Removes duplicates where required.
    - Standardizes text values such as gender, marital status, country, and product line.
    - Handles invalid dates, NULL values, and incorrect sales/price values.
    - Prints table-wise and full batch load duration.

Parameters:
    None..
    This stored procedure does not accept any parameters or return any values...........

Usage Example:
    EXEC Silver.load_Silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE Silver.load_Silver AS
BEGIN
    DECLARE 
        @start_time DATETIME2,
        @end_time DATETIME2,
        @batch_start_time DATETIME2,
        @batch_end_time DATETIME2;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';


        /*
        ------------------------------------------------------------------------
        DATA CLEANING AND TRANSFORMATION FOR TABLE: Silver.crm_cust_info
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: Silver.crm_cust_info';
        TRUNCATE TABLE Silver.crm_cust_info;

        PRINT '>> Inserting Data Into: Silver.crm_cust_info';

        INSERT INTO Silver.crm_cust_info (
            cst_id, 
            cst_key, 
            cst_firstname, 
            cst_lastname, 
            cst_marital_status, 
            cst_gndr,
            cst_create_date
        )
        SELECT 
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,

            CASE 
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                ELSE 'n/a'
            END AS cst_marital_status,

            CASE 
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date
        FROM (
            SELECT 
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id 
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM Bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) AS t
        WHERE flag_last = 1;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        /*
        ------------------------------------------------------------------------
        DATA CLEANING AND TRANSFORMATION FOR TABLE: Silver.crm_prd_info
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: Silver.crm_prd_info';
        TRUNCATE TABLE Silver.crm_prd_info;

        PRINT '>> Inserting Data Into: Silver.crm_prd_info';

        INSERT INTO Silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,	
            prd_cost,	
            prd_line,	
            prd_start_dt,
            prd_end_dt
        )
        SELECT 
            prd_id,

            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,

            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

            prd_nm,

            ISNULL(prd_cost, 0) AS prd_cost,

            CASE 
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,

            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY prd_key 
                    ORDER BY prd_start_dt
                ) - 1 
                AS DATE
            ) AS prd_end_dt
        FROM Bronze.crm_prd_info;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        /*
        ------------------------------------------------------------------------
        DATA CLEANING AND TRANSFORMATION FOR TABLE: Silver.crm_sales_details
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncatinggg Table: Silver.crm_sales_details';
        TRUNCATE TABLE Silver.crm_sales_details;

        PRINT '>> Insertinggg Data Into: Silver.crm_sales_details';

        INSERT INTO Silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            CASE 
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,

            CASE 
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,

            CASE 
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,

            CASE 
                WHEN sls_sales IS NULL 
                     OR sls_sales <= 0 
                     OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,

            CASE 
                WHEN sls_price IS NULL 
                     OR sls_price <= 0
                    THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price
        FROM Bronze.crm_sales_details;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';


        /*
        ------------------------------------------------------------------------
        DATA CLEANING AND TRANSFORMATION FOR TABLE: Silver.erp_CUST_AZ12
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: Silver.erp_CUST_AZ12';
        TRUNCATE TABLE Silver.erp_CUST_AZ12;

        PRINT '>> Inserting Data Into: Silver.erp_CUST_AZ12';

        INSERT INTO Silver.erp_CUST_AZ12 (
            cid,
            bdate,
            gen
        )
        SELECT
            CASE 
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,

            CASE 
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,

            CASE 
                WHEN UPPER(TRIM(gen)) IN ('FEMALE', 'F') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('MALE', 'M') THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM Bronze.erp_CUST_AZ12;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        /*
        ------------------------------------------------------------------------
        DATA CLEANING AND TRANSFORMATION FOR TABLE: Silver.erp_LOC_A101
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncatinggg Table: Silver.erp_LOC_A101';
        TRUNCATE TABLE Silver.erp_LOC_A101;

        PRINT '>> Insertinggg Data Into: Silver.erp_LOC_A101';

        INSERT INTO Silver.erp_LOC_A101 (
            cid,
            cntry
        )
        SELECT 
            REPLACE(cid, '-', '') AS cid,

            CASE 
                WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry
        FROM Bronze.erp_LOC_A101;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        /*
        ------------------------------------------------------------------------
        DATA LOADING FOR TABLE: Silver.erp_PX_CAT_G1V2
        ------------------------------------------------------------------------
        */

        SET @start_time = GETDATE();

        PRINT '>> Truncatinggg Table: Silver.erp_PX_CAT_G1V2';
        TRUNCATE TABLE Silver.erp_PX_CAT_G1V2;

        PRINT '>> Insertinggg Data Into: Silver.erp_PX_CAT_G1V2';

        INSERT INTO Silver.erp_PX_CAT_G1V2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM Bronze.erp_PX_CAT_G1V2;

        SET @end_time = GETDATE();

        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        SET @batch_end_time = GETDATE();

        PRINT '==========================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT 'Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';

    END TRY

    BEGIN CATCH

        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT '==========================================';

    END CATCH

END;
