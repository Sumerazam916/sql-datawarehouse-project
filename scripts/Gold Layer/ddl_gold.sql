/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/




-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

IF OBJECT_ID('Gold.dim_customers','V') IS NOT NULL
	DROP VIEW Gold.dim_customers
GO
CREATE VIEW Gold.dim_customers AS
select 
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
cst_id AS customer_id,
cst_key as customer_number,
cst_firstname AS first_name,
cst_lastname AS last_name,
cst_marital_status AS marital_status,
CASE WHEN ca.cst_gndr != 'n/a' THEN ca.cst_gndr
	ELSE COALESCE(cb.gen, 'n/a')
END AS gender,
cb.bdate AS birthdate,
cc.cntry AS country,
cst_create_date AS create_date
from Silver.crm_cust_info ca
LEFT JOIN Silver.erp_CUST_AZ12 cb
ON ca.cst_key=cb.cid
LEFT JOIN Silver.erp_LOC_A101 cc
ON ca.cst_key = cc.cid



  -- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================

IF OBJECT_ID('Gold.dim_products','V') IS NOT NULL
	DROP VIEW Gold.dim_products
GO
CREATE VIEW Gold.dim_products AS
select
ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key) AS product_key,
prd_id AS product_id,
prd_key AS product_number,
prd_nm AS product_name,
prd_cost AS product_cost,
prd_line AS product_line,
ca.cat AS category,
cat_id AS category_id,
ca.subcat AS subcategory,
ca.maintenance AS maintenance_required,
prd_start_dt AS start_date,
prd_end_dt AS end_date
from Silver.crm_prd_info ci
LEFT JOIN Silver.erp_PX_CAT_G1V2 ca
ON ci.cat_id = ca.id




-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================


IF OBJECT_ID('Gold.fact_sales','V') IS NOT NULL
	DROP VIEW Gold.fact_sales
GO
CREATE OR ALTER VIEW Gold.fact_sales AS
select 
sls_ord_num AS order_number,
pb.product_key,
pc.customer_key,
sls_order_dt AS order_date,
sls_ship_dt AS ship_date,
sls_due_dt AS due_date,
sls_sales AS sales_amount,
sls_quantity AS quantity,
sls_price AS price
from Silver.crm_sales_details pa
LEFT JOIN Gold.dim_products pb
ON pa.sls_prd_key = pb.product_number
LEFT JOIN Gold.dim_customers pc
ON pa.sls_cust_id = pc.customer_id
