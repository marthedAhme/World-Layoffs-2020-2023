/* ============================================================
   Layoff Data Load Procedure

   Purpose:
   - Load raw CSV data into the staging table with NVARCHAR columns.
   - Truncate table before load for a clean dataset.
   - Track load duration and handle errors via TRY...CATCH.

   Notes:
   - No transformations applied; data cleaning occurs later.
   - Designed for UTF-8 CSV files in data analysis workflows.
   ============================================================ */
USE world_layoff
IF OBJECT_ID('layoff','U') IS NOT NULL
	DROP TABLE layoff
GO

CREATE TABLE layoff 
(
	company               NVARCHAR(100),
	[location]            NVARCHAR(100),
	industry              NVARCHAR(100),
	total_laid_off        NVARCHAR(100),
	percentage_laid_off   NVARCHAR(100),
	[date]                NVARCHAR(100),
	stage                 NVARCHAR(100),
	country               NVARCHAR(100),
	funds_raised_millions NVARCHAR(100)
);

CREATE OR ALTER PROCEDURE load_data AS
BEGIN
	DECLARE
		@start_time DATETIME,
		@end_time DATETIME

	BEGIN TRY
		SET @start_time = GETDATE();
		PRINT '-----------------------------';
		PRINT 'Truncate Table layoff';
		PRINT '-----------------------------';
		PRINT 'Done Truncate Table';
		TRUNCATE TABLE layoff;

		PRINT '-----------------------------';
		PRINT 'Load Data into layoff table'; 
		PRINT '-----------------------------';
		BULK INSERT layoff
		FROM 'C:\SQL_DB\Projects\Data_Analysis\Projects\Data_Cleaning\layoffs.csv'
		WITH (
				FIRSTROW = 2,          
				FIELDTERMINATOR = ',', 
				ROWTERMINATOR = '0x0a', 
				CODEPAGE = '65001',     
				TABLOCK
		);

		SET @end_time = GETDATE();
		PRINT'-----------------------------';
		PRINT'LOADING TIME: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' SECOND';
		PRINT'-----------------------------';


	END TRY

	BEGIN CATCH
		PRINT'-----------------------------------------------------------';
		PRINT'ERROR OCCURE DURING THE LOADING';
		PRINT'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT'ERROR MESSAGE' + CAST(ERROR_STATE()  AS NVARCHAR);
		PRINT'-----------------------------------------------------------';
	END CATCH

END;

EXEC load_data
