/*
=================================================================
Procedure: bronze.load_bronze

Purpose:
Loads all Bronze layer tables by clearing old data and replacing
it with the latest data from CRM and ERP source files.

Load times are tracked per table and for the full batch to help
spot slow-loading tables.
=================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

	/* Timestamps used to track how long each table load takes
	   and how long the full batch takes from start to finish. */
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;

	BEGIN TRY

		/* Record the time the batch started. */
		SET @batch_start_time = GETDATE();

		PRINT'=====================================';
		PRINT'Loading Bronze Layer';
		PRINT'=====================================';

		PRINT'---------------------------------------';
		PRINT'Loading CRM Tables';
		PRINT'---------------------------------------';

		/* CRM Customer Load
		   Clear the table, then load fresh data from the source file. */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.crm_cust_info';
		TRUNCATE TABLE bronze.crm_cust_info;

		PRINT'>> Loading Data into: bronze.crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		/* Print how long this table took to load. */
		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		/* CRM Product Load */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.crm_prd_info';
		TRUNCATE TABLE bronze.crm_prd_info;

		PRINT'>> Loading Data into: bronze.crm_prd_info';
		BULK INSERT bronze.crm_prd_info
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		/* CRM Sales Load
		   Raw sales data is loaded as-is. Cleaning happens in later layers. */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details;

		PRINT'>> Loading Data into: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		PRINT'---------------------------------------';
		PRINT'Loading ERP Tables';
		PRINT'---------------------------------------';


		/* ERP Customer Enrichment Load
		   Extra customer details that aren't stored in the CRM. */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.erp_cust_az12';
		TRUNCATE TABLE bronze.erp_cust_az12;

		PRINT'>> Loading Data into: bronze.erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		/* ERP Location Load */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.erp_loc_a101';
		TRUNCATE TABLE bronze.erp_loc_a101;

		PRINT'>> Loading Data into: bronze.erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		/* ERP Product Category Load
		   Reference data used later to add category and subcategory
		   names to product records. */
		SET @start_time = GETDATE();

		PRINT'>> Truncating Table: bronze.erp_px_cat_g1v2';
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;

		PRINT'>> Loading Data into: bronze.erp_px_cat_g1v2';
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'C:\Users\DELL\OneDrive\Documents\Barra\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);

		SET @end_time = GETDATE();

		PRINT'Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT'---------------';


		/* Record the time the batch ended and print total runtime. */
		SET @batch_end_time = GETDATE();

		PRINT'=====================================';
		PRINT'Bronze Layer Load is complete';
		PRINT'	-Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT'======================================';

	END TRY

	BEGIN CATCH

		/* If any load fails, print the error details to help with debugging. */
		PRINT'===========================================';
		PRINT'ERROR OCCURED WHILE LOADING DATA';
		PRINT'Error message: ' + ERROR_MESSAGE();
		PRINT'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT'===========================================';

	END CATCH
END
