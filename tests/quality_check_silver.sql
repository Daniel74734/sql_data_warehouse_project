/*
=================================================================
Quality Checks: Silver Layer
=================================================================
Script Purpose:
    This script runs data quality checks against the 'silver' schema tables
    to catch issues that should have been fixed during the bronze -> silver load.
    Checks Performed:
    - Null or duplicate primary keys
    - Unwanted leading/trailing spaces in text fields
    - Data standardization and consistency (e.g. gender, marital status, country)
    - Invalid date ranges and date order (start date > end date)
    - Data consistency between related fields (e.g. sales = quantity * price)
Usage Notes:
    - Run this after executing silver.load_silver.
    - Any row returned by a check below indicates a problem that needs
      investigation. These queries should return NO ROWS if the data is clean.
=================================================================
*/

-- =================================================================
-- Checking: silver.crm_cust_info
-- =================================================================

-- Check for NULLs or duplicates in the primary key
-- Expectation: No results
SELECT 
    cst_id,
    COUNT(*) 
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted leading/trailing spaces in first name
-- Expectation: No results
SELECT 
    cst_firstname 
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Check for unwanted leading/trailing spaces in last name
-- Expectation: No results
SELECT 
    cst_lastname 
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Data standardization & consistency check for gender values
-- Expectation: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    cst_gndr 
FROM silver.crm_cust_info;

-- Data standardization & consistency check for marital status values
-- Expectation: Only 'Single', 'Married', 'n/a'
SELECT DISTINCT 
    cst_marital_status 
FROM silver.crm_cust_info;


-- =================================================================
-- Checking: silver.crm_prd_info
-- =================================================================

-- Check for NULLs or duplicates in the primary key
-- Expectation: No results
SELECT 
    prd_id,
    COUNT(*) 
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted leading/trailing spaces in product name
-- Expectation: No results
SELECT 
    prd_nm 
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check for NULLs or negative values in product cost
-- Expectation: No results
SELECT 
    prd_cost 
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data standardization & consistency check for product line values
-- Expectation: Only 'Mountain', 'Road', 'Other Sales', 'Touring', 'n/a'
SELECT DISTINCT 
    prd_line 
FROM silver.crm_prd_info;

-- Check for invalid date orders (start date after end date)
-- Expectation: No results
SELECT 
    * 
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- =================================================================
-- Checking: silver.crm_sales_details
-- =================================================================

-- Check for invalid dates (order date after ship date, or order date after due date)
-- Expectation: No results
SELECT 
    * 
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt 
   OR sls_order_dt > sls_due_dt;

-- Check data consistency: sales = quantity * price, and no NULLs/negatives/zeros
-- Expectation: No results
SELECT DISTINCT 
    sls_sales,
    sls_quantity,
    sls_price 
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- =================================================================
-- Checking: silver.erp_cust_az12
-- =================================================================

-- Check for out-of-range birthdates (too old or in the future)
-- Expectation: Birthdates between 1924-01-01 and today
SELECT DISTINCT 
    bdate 
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' 
   OR bdate > GETDATE();

-- Data standardization & consistency check for gender values
-- Expectation: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    gen 
FROM silver.erp_cust_az12;


-- =================================================================
-- Checking: silver.erp_loc_a101
-- =================================================================

-- Data standardization & consistency check for country values
-- Expectation: Full country names, no blanks/abbreviations, 'n/a' for unknowns
SELECT DISTINCT 
    cntry 
FROM silver.erp_loc_a101
ORDER BY cntry;


-- =================================================================
-- Checking: silver.erp_px_cat_g1v2
-- =================================================================

-- Check for unwanted leading/trailing spaces across category fields
-- Expectation: No results
SELECT 
    * 
FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat) 
   OR subcat != TRIM(subcat) 
   OR maintenance != TRIM(maintenance);

-- Data standardization & consistency check for maintenance values
-- Expectation: Only expected distinct values (e.g. 'Yes', 'No')
SELECT DISTINCT 
    maintenance 
FROM silver.erp_px_cat_g1v2;