/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE Bronze.load_bronze AS 
BEGIN
	BEGIN TRY
		
		DECLARE @start_time DATETIME, @end_time DATETIME;

		PRINT '==================================================';
		PRINT 'LOADING THE CRM SOURCE SYSTEM DATA..............';
		PRINT '==================================================';

		PRINT '';

		SET @start_time = GETDATE();
		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.crm_cust_info';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.crm_cust_info;
		PRINT '--------------------------------------------------';
		PRINT 'INSERTING TABLE : Bronze.crm_cust_info' ;
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.crm_cust_info 
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_crm\cust_info.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);

		PRINT ''
		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.crm_prd_info';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.crm_prd_info
		PRINT '--------------------------------------------------';
		PRINT 'INSERTING TABLE : Bronze.crm_prd_info';
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.crm_prd_info
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_crm/prd_info.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);


		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.crm_sales_details';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.crm_sales_details 
		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.crm_sales_details';
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.crm_sales_details 
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_crm/sales_details.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);
		
		PRINT '==================================================';
		PRINT 'LOADING THE ERP SOURCE SYSTEM DATA..............';
		PRINT '==================================================';

		PRINT '';

		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.erp_CUST_AZ12';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.erp_CUST_AZ12;
		PRINT '--------------------------------------------------';
		PRINT 'INSERTING TABLE : Bronze.erp_CUST_AZ12';
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.erp_CUST_AZ12
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_erp\CUST_AZ12.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);

		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.erp_LOC_A101';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.erp_LOC_A101
		PRINT '--------------------------------------------------';
		PRINT 'INSERTING TABLE : Bronze.erp_LOC_A101';
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.erp_LOC_A101
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_erp\LOC_A101.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);

		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.erp_PX_CAT_G1V2';
		PRINT '--------------------------------------------------';
		TRUNCATE TABLE Bronze.erp_PX_CAT_G1V2
		PRINT '--------------------------------------------------';
		PRINT 'TRUNCATING TABLE : Bronze.erp_PX_CAT_G1V2';
		PRINT '--------------------------------------------------';
		BULK INSERT Bronze.erp_PX_CAT_G1V2
		FROM 'C:\DATA WAREHOUSE PROJECT (data with baraa)\datasets\source_erp\PX_CAT_G1V2.csv'
		WITH(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
			);

		SET @end_time = GETDATE();
		PRINT 'TOTAL TIME FOR LOADING DATA INTO BRONZE LAYER WAS :' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds'
	END TRY

	BEGIN CATCH
		PRINT 'ERROR OCCURE WHILE LOADING THE BRONZE LAYER...........';
		PRINT '-------------------------------------------------------';
		PRINT 'ERROR MSG - ' + ERROR.MESSAGE();
		PRINT 'ERROR NUMBER - ' + CAST(ERROR.NUMBER() AS NVARCHAR );
		PRINT 'ERROR STATE - ' + CAST(ERROR.STATE() AS NVARCHAR );
	END CATCH
END
