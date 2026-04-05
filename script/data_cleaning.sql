-- ============================================================
--  Data Cleaning Script — World Layoffs 2020-2023
--  Database : world_layoff
--  Output   : layoff_staging1 (clean table)
-- ============================================================

-- ============================================================
-- STEP 1 — Drop existing staging table if it exists
-- ============================================================

IF OBJECT_ID('layoff_staging1', 'U') IS NOT NULL
    DROP TABLE layoff_staging1;
    PRINT 'Deleted table: layoff_staging1';
PRINT '______________________________________';
GO

-- ============================================================
-- STEP 2 — Create clean staging table with correct schema
-- ============================================================

PRINT 'Creating table: layoff_staging1';
CREATE TABLE layoff_staging1 (
    company               NVARCHAR(50),  -- company name
    [location]            NVARCHAR(50),  -- city
    country               NVARCHAR(50),  -- country
    industry              NVARCHAR(50),  -- sector
    stage                 NVARCHAR(50),  -- funding stage
    [date]                DATE,          -- event date (converted from string)
    total_laid_off        INT,           -- number of employees laid off
    percentage_laid_off   FLOAT,         -- share of workforce laid off (0.0 - 1.0)
    funds_raised_millions FLOAT          -- total funding raised in USD millions
);
GO

-- ============================================================
-- STEP 3 — Create stored procedure to clean and load data
-- ============================================================

CREATE OR ALTER PROCEDURE clean_data AS
BEGIN
    BEGIN TRY

        -- --------------------------------------------------------
        -- Clear the table before inserting fresh data
        -- --------------------------------------------------------

        PRINT 'Truncating table: layoff_staging1';
        TRUNCATE TABLE layoff_staging1;

        -- --------------------------------------------------------
        -- Insert cleaned data from the raw source table
        -- --------------------------------------------------------

        PRINT 'Inserting cleaned data into: layoff_staging1';
        INSERT INTO layoff_staging1 (
            company, [location], country, industry, stage,
            [date], total_laid_off, percentage_laid_off, funds_raised_millions
        )
        SELECT
            TRIM(company)                                        AS company,
            [location],
            CASE
                WHEN country LIKE 'United State%'
                    THEN TRIM(TRAILING '.' FROM country)
                ELSE TRIM(country)
            END                                                  AS country,
            CASE
                WHEN industry LIKE 'Crypto%'     THEN 'Crypto'
                WHEN industry IS NULL
                  OR industry = 'Null'           THEN NULL
                ELSE industry
            END                                                  AS industry,
            CASE
                WHEN stage = 'Null' THEN 'Unknown'
                ELSE stage
            END                                                  AS stage,
            TRY_CONVERT(DATE, [date], 101)                       AS [date],
            TRY_CAST(total_laid_off AS INT)                      AS total_laid_off,
            TRY_CAST(percentage_laid_off AS FLOAT)               AS percentage_laid_off,
            ROUND(
                TRY_CAST(
                    REPLACE(REPLACE(REPLACE(
                        funds_raised_millions,
                        CHAR(160), ''),   -- remove non-breaking space
                        CHAR(13),  ''),   -- remove carriage return
                        CHAR(10),  '')    -- remove line feed
                AS FLOAT)
            , 2)                                                 AS funds_raised_millions


        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY company, [location], country, industry, stage,
                                    [date], total_laid_off, percentage_laid_off,
                                    funds_raised_millions
                       ORDER BY company
                   ) AS rn
            FROM layoff
        ) src
        WHERE rn = 1;

        -- --------------------------------------------------------
        -- Remove rows with no useful data
        -- --------------------------------------------------------
        DELETE FROM layoff_staging1
        WHERE total_laid_off      IS NULL
          AND percentage_laid_off IS NULL;

        -- --------------------------------------------------------
        -- Fill missing industry values from the same company
        -- --------------------------------------------------------
        UPDATE t1
        SET    t1.industry = t2.industry
        FROM   layoff_staging1 t1
        JOIN   layoff_staging1 t2 ON t1.company = t2.company
        WHERE  t1.industry IS NULL
          AND  t2.industry IS NOT NULL;

        -- --------------------------------------------------------
        -- Label any remaining unknown industries
        -- --------------------------------------------------------

        UPDATE layoff_staging1
        SET    industry = 'Unknown'
        WHERE  industry IS NULL;

        PRINT '--------------------------------------';
        PRINT 'Done successfully';

    END TRY

    -- --------------------------------------------------------
    -- Error handling
    -- --------------------------------------------------------
    BEGIN CATCH
        PRINT '------------------------------------';
        PRINT 'ERROR OCCURRED';
        PRINT 'Message : ' + ERROR_MESSAGE();
        PRINT 'Line    : ' + CAST(ERROR_LINE()   AS NVARCHAR);
        PRINT 'State   : ' + CAST(ERROR_STATE()  AS NVARCHAR);
        PRINT 'Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT '------------------------------------';
    END CATCH
END;
GO

-- ============================================================
-- STEP 4 — Execute the procedure
-- ============================================================
EXEC clean_data;

-- Verify output
SELECT COUNT(*) AS num_clean_rows FROM layoff_staging1;  -- Expected: ~1,995
