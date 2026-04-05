# 🌍 World Layoffs 2020–2023 — Data Analysis Project

This project analyzes global layoff events (2020–2023) across 51 countries and 31 industries, using a dataset of 2,361 records. Following a full data pipeline — from raw ingestion to cleaning, exploration, analysis, and visualization — the goal is to uncover workforce reduction patterns and deliver actionable insights for decision-makers.

---

## 📁 Project Structure

```
world-layoffs/
├── data/
│   └── layoffs.csv                  # Raw dataset
├── sql/
│   ├── 01_data_cleaning.sql         # Full cleaning script
│   └── 02_data_exploration.sql      # Full EDA script
├── dashboard/
│   └── layoffs_dashboard.pbix       # Power BI dashboard
└── README.md
```

---

## 🗂️ Dataset

| Field | Details |
|---|---|
| **Source** | Kaggle — World Layoffs Dataset |
| **Period** | March 2020 – March 2023 |
| **Raw Rows** | 2,361 |
| **Clean Rows** | 1,995 |
| **Columns** | 9 |

### Columns

| Column | Type | Description |
|---|---|---|
| `company` | NVARCHAR | Company name |
| `location` | NVARCHAR | City |
| `country` | NVARCHAR | Country |
| `industry` | NVARCHAR | Sector |
| `stage` | NVARCHAR | Funding stage |
| `date` | DATE | Event date |
| `total_laid_off` | INT | Number of employees laid off |
| `percentage_laid_off` | DECIMAL | Share of workforce laid off (0–1) |
| `funds_raised_millions` | DECIMAL | Total funding raised (USD millions) |

---

## 🔧 Pipeline

```
Raw CSV  →  Data Cleaning  →  Data Exploration  →  Data Analysis  →  Visualization
```

### 1 — Data Cleaning
- Removed duplicate rows using `ROW_NUMBER()` window function
- Standardized text columns — `TRIM`, `CASE`, industry normalization
- Converted date strings to `DATE` type using `TRY_CONVERT`
- Handled `NULL` and blank values — self `JOIN` to fill missing industry
- Removed invisible characters (`CHAR(160)`, `CHAR(13)`, `CHAR(10)`) from numeric columns
- Cast all columns to correct data types (`INT`, `DECIMAL`, `DATE`)
- Removed rows where both key metrics (`total_laid_off`, `percentage_laid_off`) are `NULL`

### 2 — Data Exploration (EDA)
- Universal NULL checker using Dynamic SQL
- KPI Summary — total layoffs, estimated workforce, overall layoff rate
- Time analysis — yearly breakdown, monthly rolling total, annual share
- Industry & funding stage ranking with cohort analysis
- Company analysis — top 10, outliers, shutdowns, top 5 per year
- Geographic analysis — country ranking, city-level breakdown with `layoff_rate`
- Pearson correlation between funding raised and total layoffs

### 3 — Data Analysis
- Root cause analysis for the January 2023 peak
- Funding paradox — why high-funded companies laid off more
- Riskiest funding stage for employees
- Survival rate vs shutdown rate

### 4 — Visualization (Power BI)
- KPI cards — Total Laid Off, Companies, Countries, Avg Layoff Rate
- Line chart — monthly rolling total (2020–2023)
- Bar charts — top 10 industries and top 10 companies
- Choropleth map — layoffs by country
- Slicers — Year, Country, Industry, Funding Stage

---

## 📊 Key Findings

- **386,379** employees laid off across **1,995** companies
- **January 2023** was the single worst month — **84,714** layoffs
- **United States** accounts for **65%** of all layoff events
- **Finance** is the most represented industry in the dataset
- **Pearson correlation** between funding and layoffs is weak (~0.18) — raising more money does not predict more layoffs
- Companies that raised over **$1B** still shut down completely

---

## ⚠️ Limitations

- 33% of rows are missing `total_laid_off` or `percentage_laid_off`
- Estimated workforce figures are approximations, not official headcounts
- Some companies appear multiple times due to multiple layoff rounds
- Dataset ends March 2023 — does not reflect subsequent recovery

---

## 🛠️ Tools

| Tool | Purpose |
|---|---|
| SQL Server (SSMS) | Data storage, cleaning, and exploration |
| T-SQL | Querying, window functions, dynamic SQL |
| Power BI | Dashboard and visualization |
| Notion | Project management and documentation |

---

## 🚀 How to Run

**1. Set up the database:**
```sql
CREATE DATABASE world_layoff;
USE world_layoff;
```

**2. Load the raw data:**
```sql
-- script/load_raw_data.sql
-- Option 1: Using SSMS Import Wizard
-- Right-click database → Tasks → Import Flat File → select dataset/layoffs.csv

-- Option 2: Using store procedure (load_data) C:\path\to\layoffs.csv'
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

EXEC load_data;

-- Verify load
SELECT COUNT(*) AS num_raw_rows FROM layoff;
```

**3. Run the cleaning script:**
```sql
-- Execute script/data_cleaning.sql
-- Output: layoff_staging1 (clean table)

IF OBJECT_ID ('layoff_staging1','U') IS NOT NULL
	DROP TABLE layoff_staging1
	PRINT 'Delete the table: layoff_staging1';
PRINT'______________________________________';
GO
PRINT'Create the table layoff_staging1';
CREATE TABLE layoff_staging1 (
	company               NVARCHAR(50),
	[location]            NVARCHAR(50),
	country               NVARCHAR(50),
	industry              NVARCHAR(50),
	stage                 NVARCHAR(50),
	[date]                DATE,
	total_laid_off        INT,
	percentage_laid_off   FLOAT,
	funds_raised_millions FLOAT
);

CREATE OR ALTER PROCEDURE clean_date AS
BEGIN
	BEGIN TRY
		PRINT '--------------------------------------';
		PRINT 'Truncate the table: layoff_staging1';
		TRUNCATE TABLE layoff_staging1;

		-- Step 1: insert cleaned data (no duplicates, no useless rows)
		PRINT '--------------------------------------';
		PRINT 'Insert data into table: layoff_staging1';
		INSERT INTO layoff_staging1
			(
				company, [location],country,industry,stage,
				[date],total_laid_off,percentage_laid_off,
				funds_raised_millions
			)
		SELECT 
			TRIM(company)                                    AS company,
			[location],
			CASE 
				  WHEN country LIKE 'United State%'  
					  THEN TRIM(TRAILING '.' FROM country)
				  ELSE TRIM(country)
			END					                             AS country,
			CASE
				  WHEN industry LIKE 'Crypto%'        THEN 'Crypto'
				  WHEN industry IS NULL 
				    OR industry = 'Null'                THEN  NULL
				  ELSE industry
			END                                              AS industry,
			CASE 
				  WHEN stage = 'Null' THEN 'Unknown'
				  ELSE stage
			END												 AS stage,
			TRY_CONVERT(DATE,[date],101)                     AS [date],
			TRY_CAST(total_laid_off AS INT)                  AS total_laid_off,
			TRY_CAST(percentage_laid_off AS FLOAT)    AS percentage_laid_off,
			ROUND(TRY_CAST(
					REPLACE(REPLACE(REPLACE(
						funds_raised_millions,
						CHAR(160), ''),
						CHAR(13),  ''),
						CHAR(10),  '')
					AS FLOAT),2
					)									     AS funds_raised_millions
		FROM (

		     -- Remove duplicates before inserting
			SELECT *,
				   ROW_NUMBER() OVER(
						PARTITION BY company,[location],country,industry,stage,
									 [date],total_laid_off,percentage_laid_off,
									 funds_raised_millions
						ORDER BY	 company
					) rn
			FROM layoff
		) src
		WHERE rn = 1

		-- Step 2: remove rows where both key metrics are missing
		DELETE FROM layoff_staging1
		WHERE total_laid_off     IS NULL
		  AND percentage_laid_off IS NULL;

		-- Step 3: fill missing industry from same company
        UPDATE t1
        SET    t1.industry = t2.industry
        FROM   layoff_staging1 t1
        JOIN   layoff_staging1 t2 ON t1.company = t2.company
        WHERE  t1.industry IS NULL
          AND  t2.industry IS NOT NULL;

        -- Step 4: label any remaining unknown industries
        UPDATE layoff_staging1
        SET    industry = 'Unknown'
        WHERE  industry IS NULL;
        PRINT '--------------------------------------';
        PRINT 'Done successfully';
	END TRY
	BEGIN CATCH
		PRINT'------------------------------------';
		PRINT'ERROR OUCCARE';
		PRINT'ERORR MESSAGE' + ERROR_MESSAGE();
		PRINT'ERROR LINE'    + CAST(ERROR_LINE()   AS NVARCHAR);
		PRINT'ERROR STATE'   + CAST(ERROR_STATE()  AS NVARCHAR);
		PRINT'ERROR NUMVER'  + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT'------------------------------------';
	END CATCH
END;

EXEC clean_date

```

**4. Run the exploration script:**
```sql
-- Execute script/data_exploration.sql
-- Output: EDA results across 9 sections
-- ============================================================
--  World Layoffs 2020–2023 — Exploratory Data Analysis (EDA)
--  Database : world_layoff
--  Table    : layoff_staging1 (cleaned)
-- ============================================================

USE world_layoff;

-- ============================================================
-- SECTION 0 — Dataset Overview
-- ============================================================

/*
  Dataset : World Layoffs 2020–2023
  Rows    : 2,361 (raw) | varies after cleaning
  Columns : 9
  Scope   : Global tech-sector layoff events
  Source  : layoff_staging1 (cleaned from layoff)

  Columns:
    company               — company name
    location              — city
    country               — country
    industry              — sector
    stage                 — funding stage
    date                  — event date
    total_laid_off        — number of employees laid off
    percentage_laid_off   — share of workforce laid off (0–1)
    funds_raised_millions — total funding raised (USD millions)
*/


-- ============================================================
-- SECTION 1 — Row Counts
-- ============================================================

-- Raw rows before cleaning
SELECT COUNT(*) AS num_raw_rows
FROM   layoff;

-- Rows after cleaning
SELECT COUNT(*) AS num_clean_rows
FROM   layoff_staging1;


-- ============================================================
-- SECTION 2 — Data Duration
-- ============================================================

-- Years covered, with first and last event per year
SELECT
    YEAR([date])  AS [year],
    MIN([date])   AS first_event,
    MAX([date])   AS last_event,
    COUNT(*)      AS num_events
FROM   layoff_staging1
WHERE  [date] IS NOT NULL
GROUP BY YEAR([date])
ORDER BY [year];


-- ============================================================
-- SECTION 3 — Data Quality (Universal Null Checker)
-- ============================================================

-- Dynamically checks every column for NULL percentage
-- Works on any table — just change @table
DECLARE @sql   NVARCHAR(MAX) = '';
DECLARE @table NVARCHAR(128) = 'layoff_staging1';

SELECT @sql += '
    SELECT
        ''' + COLUMN_NAME + '''                              AS [column],
        COUNT(*)                                             AS total_rows,
        COUNT(*) - COUNT([' + COLUMN_NAME + '])              AS null_count,
        CONCAT((COUNT(*) - COUNT([' + COLUMN_NAME + ']))
               * 100 / COUNT(*), ''%'')                      AS null_percentage
    FROM ' + @table + ' UNION ALL'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @table;

-- Remove trailing UNION ALL and wrap in ORDER BY
SET @sql = LEFT(@sql, LEN(@sql) - 9);
SET @sql = 'SELECT * FROM (' + @sql + ') t ORDER BY null_count DESC';

EXEC sp_executesql @sql;


-- ============================================================
-- SECTION 4 — KPI Summary
-- ============================================================

-- Part A: High-level metrics
SELECT 'Number of Companies'  AS measure_name, FORMAT(COUNT(DISTINCT company),  'N0') AS measure_value FROM layoff_staging1
UNION ALL
SELECT 'Number of Industries' AS measure_name, FORMAT(COUNT(DISTINCT industry), 'N0') AS measure_value FROM layoff_staging1
UNION ALL
SELECT 'Number of Countries'  AS measure_name, FORMAT(COUNT(DISTINCT country),  'N0') AS measure_value FROM layoff_staging1
UNION ALL
SELECT 'Total Layoffs'        AS measure_name, FORMAT(SUM(total_laid_off),       'N0') AS measure_value FROM layoff_staging1 WHERE total_laid_off        IS NOT NULL
UNION ALL
SELECT 'Average Layoffs'      AS measure_name, FORMAT(AVG(total_laid_off),       'N0') AS measure_value FROM layoff_staging1 WHERE total_laid_off        IS NOT NULL
UNION ALL
SELECT 'Total Funds Raised'   AS measure_name, FORMAT(SUM(funds_raised_millions),'N0') AS measure_value FROM layoff_staging1 WHERE funds_raised_millions IS NOT NULL
UNION ALL
SELECT 'Average Funds Raised' AS measure_name,
       CONCAT(CAST(ROUND(AVG(funds_raised_millions), 0) AS NVARCHAR), 'M')              AS measure_value FROM layoff_staging1 WHERE funds_raised_millions IS NOT NULL
UNION ALL
SELECT 'Average Layoff Rate'  AS measure_name,
       CAST(ROUND(CAST(AVG(percentage_laid_off) AS FLOAT) * 100, 2) AS NVARCHAR) + '%' AS measure_value
FROM   layoff_staging1
WHERE  percentage_laid_off IS NOT NULL
  AND  percentage_laid_off > 0;


-- Part B: Estimated total workforce and overall layoff rate
-- Logic: estimated_employees = total_laid_off / percentage_laid_off
--        overall_rate        = total_laid_off / estimated_employees * 100
WITH num_of_employees AS (
    SELECT
        total_laid_off,
        percentage_laid_off,
        CAST(ROUND(total_laid_off / NULLIF(percentage_laid_off, 0), 0) AS FLOAT) AS estimated_total_employees
    FROM layoff_staging1
    WHERE total_laid_off      IS NOT NULL
      AND percentage_laid_off IS NOT NULL
      AND percentage_laid_off > 0
)
SELECT
    FORMAT(CAST(SUM(estimated_total_employees) AS BIGINT), 'N0') AS estimated_total_employees,
    FORMAT(SUM(total_laid_off), 'N0')                            AS total_laid_off,
    CONCAT(ROUND(SUM(total_laid_off) * 100.0
           / NULLIF(SUM(estimated_total_employees), 0), 2), '%') AS overall_layoff_rate
FROM num_of_employees;


-- ============================================================
-- SECTION 5 — Time Analysis
-- ============================================================

-- Q: Which year was the hardest?
SELECT
    YEAR([date])        AS [year],
    SUM(total_laid_off) AS total_laid_off,
    COUNT(*)            AS num_events,
    MAX(total_laid_off) AS largest_single_event
FROM   layoff_staging1
WHERE  [date] IS NOT NULL
GROUP BY YEAR([date])
ORDER BY total_laid_off DESC;


-- Q: What is the month-over-month trend? (Rolling Total)
-- rolling_total shows cumulative layoffs from the start of the dataset
DROP TABLE IF EXISTS #monthly;

SELECT
    YEAR([date])              AS yr,
    MONTH([date])             AS mn,
    FORMAT([date], 'yyyy-MM') AS yr_month,
    SUM(total_laid_off)       AS monthly_total
INTO #monthly
FROM   layoff_staging1
WHERE  [date]          IS NOT NULL
  AND  total_laid_off  IS NOT NULL
GROUP BY YEAR([date]), MONTH([date]), FORMAT([date], 'yyyy-MM');

SELECT
    yr_month,
    monthly_total,
    SUM(monthly_total) OVER (
        ORDER BY yr, mn
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_total
FROM   #monthly
ORDER BY yr, mn;


-- Annual share: what percentage of total layoffs happened each year?
WITH annual_layoff_cte AS (
    SELECT
        YEAR([date])                        AS [year],
        SUM(total_laid_off)                 AS total_laid_off,
        AVG(total_laid_off)                 AS avg_laid_off,
        ROUND(SUM(funds_raised_millions), 2) AS total_funds_raised,
        ROUND(AVG(funds_raised_millions),  2) AS avg_funds_raised
    FROM layoff_staging1
    WHERE [date]              IS NOT NULL
      AND total_laid_off      IS NOT NULL
      AND funds_raised_millions IS NOT NULL
    GROUP BY YEAR([date])
)
SELECT
    *,
    CONCAT(
        ROUND(total_laid_off * 100 / SUM(total_laid_off) OVER (), 2)
    , '%') AS annual_percentage
FROM   annual_layoff_cte
ORDER BY total_laid_off DESC;


-- ============================================================
-- SECTION 6 — Industry Analysis
-- ============================================================

-- Q: Which industry was hit the hardest?
SELECT
    industry,
    COUNT(DISTINCT company) AS num_companies,
    SUM(total_laid_off)     AS total_laid_off,
    AVG(total_laid_off)     AS avg_laid_off
FROM   layoff_staging1
WHERE  industry != 'Unknown'
  AND  total_laid_off IS NOT NULL
GROUP BY industry
ORDER BY total_laid_off DESC;


-- Q: Which funding stage was most affected?
SELECT
    stage,
    COUNT(DISTINCT company)     AS num_companies,
    SUM(total_laid_off)         AS total_laid_off,
    AVG(total_laid_off)         AS avg_laid_off,
    SUM(funds_raised_millions)  AS total_funds_raised
FROM   layoff_staging1
WHERE  stage                != 'Unknown'
  AND  total_laid_off        IS NOT NULL
  AND  funds_raised_millions IS NOT NULL
GROUP BY stage
ORDER BY total_laid_off DESC;


-- Q: Which funding stage had the most layoffs per year? (Cohort Analysis)
SELECT
    YEAR([date])        AS [year],
    stage,
    SUM(total_laid_off) AS total_laid_off
FROM   layoff_staging1
WHERE  [date] IS NOT NULL
  AND  stage NOT IN ('Unknown')
  AND  total_laid_off IS NOT NULL
GROUP BY YEAR([date]), stage
ORDER BY [year], total_laid_off DESC;


-- ============================================================
-- SECTION 7 — Company Analysis
-- ============================================================

-- Q: Which companies laid off the most employees? (Top 10)
SELECT TOP 10
    company,
    industry,
    country,
    SUM(total_laid_off) AS total_laid_off,
    COUNT(*)            AS num_rounds       -- number of times company appears in dataset
FROM   layoff_staging1
WHERE  total_laid_off IS NOT NULL
GROUP BY company, industry, country
ORDER BY total_laid_off DESC;


-- Q: Which companies shut down completely? (100% laid off)
-- These companies likely went bankrupt or were fully acquired
SELECT
    company,
    industry,
    country,
    funds_raised_millions,
    [date]
FROM   layoff_staging1
WHERE  percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;


-- Q: Which companies are outliers? (laid off more than 2x the average)
-- Outliers can skew the overall analysis
SELECT
    company,
    industry,
    country,
    total_laid_off,
    AVG(total_laid_off) OVER () AS global_avg
FROM   layoff_staging1
WHERE  total_laid_off > 2 * (
           SELECT AVG(total_laid_off)
           FROM   layoff_staging1
           WHERE  total_laid_off IS NOT NULL
       )
ORDER BY total_laid_off DESC;


-- Q: Top 5 companies per year by layoffs
WITH ranked AS (
    SELECT
        YEAR([date])        AS [year],
        company,
        industry,
        SUM(total_laid_off) AS total_laid_off,
        RANK() OVER (
            PARTITION BY YEAR([date])
            ORDER BY SUM(total_laid_off) DESC
        ) AS rnk
    FROM   layoff_staging1
    WHERE  [date]          IS NOT NULL
      AND  total_laid_off  IS NOT NULL
    GROUP BY YEAR([date]), company, industry
)
SELECT *
FROM   ranked
WHERE  rnk <= 5
ORDER BY [year], rnk;


-- ============================================================
-- SECTION 8 — Geographic Analysis
-- ============================================================

-- Q: Which country was most affected?
SELECT
    country,
    COUNT(DISTINCT company) AS num_companies,
    SUM(total_laid_off)     AS total_laid_off,
    AVG(total_laid_off)     AS avg_laid_off
FROM   layoff_staging1
WHERE  total_laid_off IS NOT NULL
GROUP BY country
ORDER BY total_laid_off DESC;


-- Q: City-level breakdown within each country
-- layoff_rate = what % of the estimated workforce was laid off
WITH country_details AS (
    SELECT
        country,
        [location]                                                              AS city,
        COUNT(DISTINCT company)                                                 AS num_companies,
        SUM(total_laid_off)                                                     AS total_laid_off,
        ROUND(AVG(CAST(total_laid_off AS FLOAT)), 0)                            AS avg_laid_off,
        ROUND(SUM(funds_raised_millions),  2)                                   AS total_funds_raised,
        ROUND(AVG(funds_raised_millions),  2)                                   AS avg_funds_raised,
        -- estimated headcount per city = SUM(laid_off / layoff_rate)
        SUM(CAST(total_laid_off AS FLOAT) / NULLIF(percentage_laid_off, 0))     AS estimated_total_employees
    FROM layoff_staging1
    WHERE total_laid_off        IS NOT NULL
      AND funds_raised_millions IS NOT NULL
      AND percentage_laid_off   IS NOT NULL
      AND percentage_laid_off   > 0
    GROUP BY country, [location]
),
ranked_country_cte AS (
    SELECT
        country,
        city,
        num_companies,
        total_laid_off,
        avg_laid_off,
        total_funds_raised,
        avg_funds_raised,
        CONCAT(
            ROUND(total_laid_off * 100.0 / NULLIF(estimated_total_employees, 0), 2)
        , '%')                                                                  AS layoff_rate,
        -- rank cities within each country from most to least layoffs
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY total_laid_off DESC)   AS city_rank
    FROM country_details
)
SELECT
    country,
    city_rank,
    city,
    num_companies,
    total_laid_off,
    avg_laid_off,
    avg_funds_raised,
    layoff_rate
FROM   ranked_country_cte
ORDER BY country, city_rank;


-- ============================================================
-- SECTION 9 — Correlation Analysis
-- ============================================================

/*
  Pearson correlation between funds raised and total layoffs.
  Measures whether companies that raised more money laid off more employees.

  Result interpretation:
    0.0 – 0.3  → weak correlation   (funding has little effect on layoffs)
    0.3 – 0.6  → moderate correlation
    0.6 – 1.0  → strong correlation (more funding = more layoffs)
  Negative values → inverse relationship
*/
SELECT
    ROUND(
        (
            COUNT(*) * SUM(CAST(total_laid_off AS FLOAT) * CAST(funds_raised_millions AS FLOAT))
            - SUM(CAST(total_laid_off AS FLOAT)) * SUM(CAST(funds_raised_millions AS FLOAT))
        ) /
        SQRT(
            (
                COUNT(*) * SUM(POWER(CAST(total_laid_off      AS FLOAT), 2))
                - POWER(SUM(CAST(total_laid_off      AS FLOAT)), 2)
            ) *
            (
                COUNT(*) * SUM(POWER(CAST(funds_raised_millions AS FLOAT), 2))
                - POWER(SUM(CAST(funds_raised_millions AS FLOAT)), 2)
            )
        ),
    3) AS pearson_correlation
FROM layoff_staging1
WHERE total_laid_off        IS NOT NULL
  AND funds_raised_millions IS NOT NULL;
```
**5. Data analysis:**
```

```
**6. Open the dashboard:**
```
- Open dashboard/layoffs_dashboard.pbix in Power BI Desktop
- Update the data source connection to your SQL Server instance
- Refresh the data
```

---

## 👤 Author

**Marthed Ahmed**
Data Analyst — SQL Server · Power BI · Notion

---

*Last updated: April 2026*
