/*
=================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
    - Truncates Silver tables.
    - Inserts transformed and cleansed data from Bronze into Silver tables.
Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.
Usage Example:
    EXEC Silver.load_silver;
=================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN

	DECLARE @start_time DATETIME2, @end_time DATETIME2, @batch_start_time DATETIME2, @batch_end_time DATETIME2;

	BEGIN TRY
		SET @batch_start_time = GETDATE();


		PRINT'=====================================';
		PRINT'Loading Silver Layer';
		PRINT'=====================================';
		
		PRINT'---------------------------------------';
		PRINT'Loading CRM Tables';
		PRINT'---------------------------------------';

		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.crm_cust_info '
		TRUNCATE TABLE silver.crm_cust_info;
		
		PRINT '>> Inserting data into: silver.crm_cust_info'
		INSERT INTO silver.crm_cust_info
		(
			cst_id,
			cst_key,
			cst_create_date,
			cst_firstname,
			cst_lastname,
			cst_gndr,
			cst_marital_status
		)

		SELECT
			cst_id,
			cst_key,
			cst_create_date,

			-- Remove extra spaces from names
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,

			-- Turn letter code into full word
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				 WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				 ELSE 'n/a'
			END cst_gndr,

			-- Turn letter code into full word
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				 ELSE 'n/a'
		END cst_marital_status

		FROM
			(SELECT 
			*,
			-- Number each customer's records by date, oldest = 1
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date) as flag_last
			FROM bronze.crm_cust_info
			) 
		-- Keep only the most recent record per customer
		t WHERE flag_last = 1;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';

		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.crm_prd_info '
		TRUNCATE TABLE silver.crm_prd_info;
		
		-- Put data into the silver products table
		PRINT '>> Inserting data into: silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info (
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

			-- Grab the first 5 chars of prd_key and swap dashes for underscores to get category id
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,

			-- Strip the category prefix, keep only the actual product key
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

			prd_nm,

			-- If cost is missing, use 0 instead
			ISNULL(prd_cost, 0) AS prd_cost,

			-- Turn the short letter code into a full word
			CASE UPPER(TRIM(prd_line))
				 WHEN 'M' THEN 'Mountain'
				 WHEN 'R' THEN 'Road'
				 WHEN 'S' THEN 'Other Sales'
				 WHEN 'T' THEN 'Touring'
				 ELSE 'n/a'
			END AS prd_line,

			CAST(prd_start_dt AS DATE) AS prd_start_dt,

			-- End date is one day before the next version of this product starts
			CAST(LEAD(prd_end_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE) AS prd_end_dt

		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';

		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.crm_sales_details '
		TRUNCATE TABLE silver.crm_sales_details;

		PRINT '>> Inserting data into: silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details (
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

			-- Dates are stored as integers (e.g. 20130101), convert to real dates or NULL if invalid
			CASE WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,

			-- Corrected sales value, computed once via CROSS APPLY so it can be reused below
			fixed.sls_sales,

			sls_quantity,

			-- If price is missing or invalid, derive it from the corrected sales / quantity
			CASE WHEN sls_price IS NULL OR sls_price <= 0 
				 THEN fixed.sls_sales / NULLIF(sls_quantity, 0)
				 ELSE sls_price
			END AS sls_price

		FROM bronze.crm_sales_details
		-- Recalculate sales here once, so both sls_sales and the sls_price fallback use the same corrected value
		CROSS APPLY (
			SELECT CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
		 				THEN sls_quantity * ABS(sls_price)
		 				ELSE sls_sales
				   END AS sls_sales
		) fixed;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';



		PRINT'---------------------------------------';
		PRINT'Loading ERP Tables';
		PRINT'---------------------------------------';


		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.erp_cust_az12 '
		TRUNCATE TABLE silver.erp_cust_az12;

		PRINT '>> Inserting data into: silver.erp_cust_az12'
		INSERT INTO silver.erp_cust_az12(
			cid,
			bdate ,
			gen
		)

		SELECT 
			-- Strip the 'NAS' prefix from cid if it exists, so it matches other tables
			CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) 
				 ELSE cid
			END AS cid,
			-- Remove invalid future birthdates by setting them to NULL
			CASE WHEN bdate > CAST(GETDATE() AS DATE) THEN NULL
				 ELSE bdate
			END AS bdate,
			-- Standardize gender values into Male/Female, default unknowns to 'n/a'
			CASE WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
				 WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
				 ELSE 'n/a'
			END AS gen
		FROM bronze.erp_cust_az12;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';

		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.erp_loc_a101 '
		TRUNCATE TABLE silver.erp_loc_a101;

		PRINT '>> Inserting data into: silver.erp_loc_a101'
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)

		SELECT 
			-- Remove dashes from cid so it matches the format used in other tables
			REPLACE(TRIM(cid), '-', '') AS cid,
			-- Standardize country values: expand abbreviations, fix blanks/nulls to 'n/a'
			CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
				 WHEN UPPER(TRIM(cntry)) IN ('USA', 'US') THEN 'United States'
				 WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
				 ELSE TRIM(cntry)
			END AS cntry

		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';

		-- Clear out old data so we don't get duplicates on reload
		SET @start_time = GETDATE();
		PRINT '>> Truncating silver.erp_px_cat_g1v2 '
		TRUNCATE TABLE silver.erp_px_cat_g1v2;

		PRINT '>> Inserting data into: silver.erp_px_cat_g1v2'
		-- Load product category data from bronze into silver
		INSERT INTO silver.erp_px_cat_g1v2(
			id,
			cat,
			subcat,
			maintenance
		)

		-- Straight copy, no transformations needed for this table
		SELECT 
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		SET @batch_end_time = GETDATE();
		PRINT'=====================================';
		PRINT'Silver Layer Load is complete';
		PRINT'	-Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT'======================================';

	END TRY
	BEGIN CATCH
		PRINT '=====================================';
		PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
		PRINT 'Error Message: ' + ERROR_MESSAGE();
		PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=====================================';
	END CATCH
END