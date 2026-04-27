-- ============================================================
--  World Layoffs 2020–2023
--  Advanced EDA — Professional Edition
--  Database : world_layoff
--  Table    : layoff_staging1
--  Author   : [Your Name]
--  Date     : 2024
-- ============================================================
--
--  ANALYSIS ROADMAP
--  ────────────────────────────────────────────────────────────
--  SECTION A  │ Pivot Analysis     — Stage × Year breakdown
--  SECTION B  │ Company Behavior   — Multi-round layoff tracking
--  SECTION C  │ Cross Analysis     — Industry × Stage matrix
--  SECTION D  │ Distribution       — Percentiles & spread
--  SECTION E  │ Group Segmentation — Huge vs Small events
--  SECTION F  │ Z-Score Analysis   — Outlier scoring
--  ────────────────────────────────────────────────────────────

USE world_layoff;


-- ============================================================
-- SECTION A — PIVOT ANALYSIS
-- Business Question:
--   Which funding stage drove layoffs in each year?
--   Did Post-IPO companies dominate in 2022 vs 2020?
-- ============================================================

/*
  WHY THIS MATTERS:
  A pivot lets you compare all stages side-by-side per year.
  If one stage suddenly jumps in 2022, that tells a story
  (e.g., overvalued late-stage companies correcting post-rate-hike).

  COLUMNS EXPLAINED:
    [YYYY]    = absolute layoffs in that year
    [YYYY_%]  = that stage's share of ALL layoffs that year
    grand_total = total across all years
    [total_%]   = that stage's share of the entire dataset
*/

SELECT
    stage,

    -- ── 2020 ────────────────────────────────────────────────
    SUM(CASE WHEN YEAR([date]) = 2020 THEN total_laid_off ELSE 0 END)
        AS [2020],

    CAST(
        SUM(CASE WHEN YEAR([date]) = 2020 THEN total_laid_off ELSE 0 END) * 100.0
        / NULLIF(SUM(SUM(CASE WHEN YEAR([date]) = 2020 THEN total_laid_off ELSE 0 END)) OVER (), 0)
    AS DECIMAL(5,1))
        AS [2020_%],

    -- ── 2021 ────────────────────────────────────────────────
    SUM(CASE WHEN YEAR([date]) = 2021 THEN total_laid_off ELSE 0 END)
        AS [2021],

    CAST(
        SUM(CASE WHEN YEAR([date]) = 2021 THEN total_laid_off ELSE 0 END) * 100.0
        / NULLIF(SUM(SUM(CASE WHEN YEAR([date]) = 2021 THEN total_laid_off ELSE 0 END)) OVER (), 0)
    AS DECIMAL(5,1))
        AS [2021_%],

    -- ── 2022 ────────────────────────────────────────────────
    SUM(CASE WHEN YEAR([date]) = 2022 THEN total_laid_off ELSE 0 END)
        AS [2022],

    CAST(
        SUM(CASE WHEN YEAR([date]) = 2022 THEN total_laid_off ELSE 0 END) * 100.0
        / NULLIF(SUM(SUM(CASE WHEN YEAR([date]) = 2022 THEN total_laid_off ELSE 0 END)) OVER (), 0)
    AS DECIMAL(5,1))
        AS [2022_%],

    -- ── 2023 ────────────────────────────────────────────────
    SUM(CASE WHEN YEAR([date]) = 2023 THEN total_laid_off ELSE 0 END)
        AS [2023],

    CAST(
        SUM(CASE WHEN YEAR([date]) = 2023 THEN total_laid_off ELSE 0 END) * 100.0
        / NULLIF(SUM(SUM(CASE WHEN YEAR([date]) = 2023 THEN total_laid_off ELSE 0 END)) OVER (), 0)
    AS DECIMAL(5,1))
        AS [2023_%],

    -- ── Grand Total ─────────────────────────────────────────
    SUM(total_laid_off) AS grand_total,

    CAST(
        SUM(total_laid_off) * 100.0
        / NULLIF(SUM(SUM(total_laid_off)) OVER (), 0)
    AS DECIMAL(5,1))
        AS [total_%]

FROM  layoff_staging1
WHERE stage            NOT IN ('Unknown')
  AND total_laid_off    IS NOT NULL
  AND [date]            IS NOT NULL
GROUP BY stage
ORDER BY grand_total DESC;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ Which stage has the highest [2022_%]?
    → Likely Post-IPO: these companies over-hired at peak
      valuations and were first to cut when rates rose.
  ✔ Compare [2020_%] vs [2023_%] for early-stage companies.
    → Rising share in 2023 = seed/Series A startups
      running out of runway as VC funding dried up.
  ✔ A stage with high [total_%] but concentrated in one year
    → means a short, sharp crisis rather than a structural trend.
  ────────────────────────────────────────────────────────────
*/


-- ============================================================
-- SECTION B — COMPANY BEHAVIOR ANALYSIS
-- Business Question:
--   Which companies went through multiple rounds of layoffs?
--   Are they escalating (getting worse) or stabilizing?
-- ============================================================

/*
  WHY THIS MATTERS:
  A company with one layoff round could be a one-time restructure.
  A company with 4+ rounds that are Escalating is in a death spiral.
  This analysis identifies which companies were in chronic trouble
  vs. which made a single decisive cut and moved on.

  COLUMNS EXPLAINED:
    total_rounds      = how many separate layoff events
    first/last_date   = timeline of the problem
    day_between       = how long the crisis lasted (in days)
    cumulative_layoffs = total headcount lost
    trend             = Escalating / Declining / Stable
      Escalating → each round is bigger than the last (danger)
      Declining  → rounds are shrinking (controlled wind-down)
      Stable     → same size each time (planned restructuring)
*/

WITH rounds AS (
    SELECT
        company,
        country,
        industry,
        [date],
        total_laid_off,

        -- Assign a sequential number to each layoff event per company
        ROW_NUMBER() OVER (
            PARTITION BY company
            ORDER BY [date]
        ) AS round_num,

        -- Count total number of rounds per company
        COUNT(*) OVER (
            PARTITION BY company
        ) AS total_rounds

    FROM  layoff_staging1
    WHERE total_laid_off IS NOT NULL
      AND [date]          IS NOT NULL
)
SELECT
    company,
    country,
    industry,
    total_rounds,

    -- First round details
    MAX(CASE WHEN round_num = 1 THEN [date]          END) AS first_date,
    MAX(CASE WHEN round_num = 1 THEN total_laid_off  END) AS first_layoffs,

    -- Last round details
    MAX(CASE WHEN round_num = total_rounds THEN [date]         END) AS last_date,
    MAX(CASE WHEN round_num = total_rounds THEN total_laid_off END) AS last_layoffs,

    -- Cumulative impact
    SUM(total_laid_off) AS cumulative_layoffs,

    -- Duration: how many days did the layoff cycle last?
    DATEDIFF(
        DAY,
        MAX(CASE WHEN round_num = 1            THEN [date] END),
        MAX(CASE WHEN round_num = total_rounds THEN [date] END)
    ) AS days_of_crisis,

    -- Trend classification: is it getting worse or better?
    CASE
        WHEN MAX(CASE WHEN round_num = total_rounds THEN total_laid_off END)
           > MAX(CASE WHEN round_num = 1            THEN total_laid_off END)
        THEN 'Escalating'   -- Last round > First round → worsening
        WHEN MAX(CASE WHEN round_num = total_rounds THEN total_laid_off END)
           < MAX(CASE WHEN round_num = 1            THEN total_laid_off END)
        THEN 'Declining'    -- Last round < First round → slowing down
        ELSE 'Stable'       -- Equal size rounds → planned/systematic
    END AS trend

FROM  rounds
WHERE total_rounds > 1   -- Only companies with repeated layoffs
GROUP BY company, country, industry, total_rounds
ORDER BY total_rounds DESC, cumulative_layoffs DESC;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ Companies with total_rounds >= 4 AND trend = 'Escalating'
    → These are the most distressed companies in the dataset.
  ✔ Sort by days_of_crisis DESC
    → Long crisis + many rounds = structural business problem,
      not just a market reaction.
  ✔ Compare first_layoffs vs last_layoffs
    → If last_layoffs >> first_layoffs the company
      underestimated its problem and kept cutting.
  ✔ Filter WHERE trend = 'Declining' AND total_rounds >= 3
    → These companies managed the process well: big first cut,
      then tapered off. This is the "rip the bandaid" approach.
  ────────────────────────────────────────────────────────────
*/


-- ============================================================
-- SECTION C — CROSS ANALYSIS: INDUSTRY × STAGE
-- Business Question:
--   In each funding stage, which industry was hit hardest?
--   Does the pattern differ by maturity of the company?
-- ============================================================

/*
  WHY THIS MATTERS:
  Not all layoffs are equal. A Series B startup cutting 200 people
  is very different from a Post-IPO company cutting 200 people.
  This cross-table reveals whether certain industries are
  vulnerable at specific funding stages.

  COLUMNS EXPLAINED:
    rank_in_stage    = ranking of this industry within its stage
                       (rank 1 = worst-hit industry in that stage)
    rank_in_industry = ranking of this stage within its industry
                       (rank 1 = the stage where this industry hurts most)
    pct_of_industry  = % of this industry's total layoffs from this stage
    pct_of_stage     = % of this stage's total layoffs from this industry
*/

WITH cross_base AS (
    SELECT
        industry,
        stage,
        COUNT(DISTINCT company) AS num_companies,
        SUM(total_laid_off)     AS total_laid_off,
        AVG(total_laid_off)     AS avg_laid_off,
        COUNT(*)                AS num_events
    FROM  layoff_staging1
    WHERE industry      NOT IN ('Unknown')
      AND stage         NOT IN ('Unknown')
      AND stage          IS NOT NULL
      AND total_laid_off IS NOT NULL
    GROUP BY industry, stage
),
ranked AS (
    SELECT
        *,

        -- Which industry is most affected within each funding stage?
        RANK() OVER (
            PARTITION BY stage
            ORDER BY total_laid_off DESC
        ) AS rank_in_stage,

        -- Which funding stage hits each industry the most?
        RANK() OVER (
            PARTITION BY industry
            ORDER BY total_laid_off DESC
        ) AS rank_in_industry,

        -- What share of this industry's total layoffs came from this stage?
        CAST(
            total_laid_off * 100.0
            / NULLIF(SUM(total_laid_off) OVER (PARTITION BY industry), 0)
        AS DECIMAL(5,1)) AS pct_of_industry,

        -- What share of this stage's total layoffs came from this industry?
        CAST(
            total_laid_off * 100.0
            / NULLIF(SUM(total_laid_off) OVER (PARTITION BY stage), 0)
        AS DECIMAL(5,1)) AS pct_of_stage

    FROM cross_base
)
SELECT
    industry,
    stage,
    num_companies,
    total_laid_off,
    avg_laid_off,
    num_events,
    pct_of_industry,
    pct_of_stage,
    rank_in_stage,
    rank_in_industry
FROM  ranked
ORDER BY total_laid_off DESC;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ WHERE rank_in_stage = 1 (for each stage, the #1 industry)
    → Filter: WHERE rank_in_stage = 1
    → This shows the dominant industry at each maturity level.
  ✔ WHERE rank_in_industry = 1 (for each industry, the worst stage)
    → Filter: WHERE rank_in_industry = 1
    → If Consumer industry's worst stage is Post-IPO, it means
      large consumer tech companies drove those layoffs.
  ✔ High pct_of_industry from one stage (>50%)
    → That industry's layoffs are highly concentrated in that
      stage — a structural vulnerability, not broad market risk.
  ✔ High avg_laid_off with few num_events
    → Few large events, not many small ones (concentrated risk).
  ────────────────────────────────────────────────────────────
*/


-- ============================================================
-- SECTION D — DISTRIBUTION ANALYSIS
-- Business Question:
--   What is the "normal" layoff event size?
--   Where is the cutoff between a small and a massive event?
-- ============================================================

/*
  WHY THIS MATTERS:
  Averages are misleading when data is skewed (and layoff data
  almost always is). Percentiles give a truthful picture.
  The gap between median and P90 tells you how extreme the tail is.

  COLUMNS EXPLAINED:
    Q1     = 25th percentile: 25% of events are below this size
    median = 50th percentile: the "typical" layoff event
    Q3     = 75th percentile: 75% of events are below this
    P90    = only 10% of events are larger than this
    P99    = the extreme outlier threshold
*/

-- Full dataset percentiles
SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_laid_off) OVER () AS Q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_laid_off) OVER () AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_laid_off) OVER () AS Q3,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_laid_off) OVER () AS P90,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_laid_off) OVER () AS P99
FROM  layoff_staging1
WHERE total_laid_off IS NOT NULL;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ If median << average → distribution is right-skewed.
    A few giant events pull the average up. The median is
    the better representation of a "typical" layoff event.
  ✔ The IQR (Q3 - Q1) = the range for the "middle 50%" of events.
  ✔ P99 vs P90 gap → if P99 is 10x P90, the top 1% of events
    are true outliers that need separate treatment.
  ✔ Use P90 or P99 as your threshold for "huge event" rather
    than an arbitrary number like 3,000.
  ────────────────────────────────────────────────────────────
*/


-- ============================================================
-- SECTION E — GROUP SEGMENTATION
-- Business Question:
--   Do "Huge" events (≥3,000 laid off) follow different patterns
--   than "Small" events (<3,000)?
--   Are they in the same industries? Same years?
-- ============================================================

/*
  WHY THIS MATTERS:
  Combining huge and small events in one analysis distorts everything.
  Amazon laying off 18,000 and a startup laying off 50 are
  fundamentally different events. Segmenting them reveals whether
  the crisis was driven by a few massive collapses or widespread
  small-scale cuts across the economy.
*/

-- ── E1: Group Summary with Descriptive Statistics ────────────
WITH base_small AS (
    SELECT total_laid_off FROM layoff_staging1
    WHERE total_laid_off <  3000 AND total_laid_off IS NOT NULL
),
base_huge AS (
    SELECT total_laid_off FROM layoff_staging1
    WHERE total_laid_off >= 3000 AND total_laid_off IS NOT NULL
),
stats_small AS (
    SELECT
        'Small (<3,000)'                             AS group_label,
        COUNT(*)                                     AS total_events,
        MIN(total_laid_off)                          AS min_value,
        MAX(total_laid_off)                          AS max_value,
        ROUND(AVG(total_laid_off * 1.0), 0)          AS avg_value,
        ROUND(STDEV(total_laid_off), 0)              AS std_dev,
        -- CV = Std Dev / Mean → measures relative spread
        -- CV > 1 means high variability within the group
        ROUND(AVG(total_laid_off * 1.0)
              / NULLIF(STDEV(total_laid_off), 0), 2) AS cv_ratio
    FROM base_small
),
stats_huge AS (
    SELECT
        'Huge (≥3,000)'                              AS group_label,
        COUNT(*)                                     AS total_events,
        MIN(total_laid_off)                          AS min_value,
        MAX(total_laid_off)                          AS max_value,
        ROUND(AVG(total_laid_off * 1.0), 0)          AS avg_value,
        ROUND(STDEV(total_laid_off), 0)              AS std_dev,
        ROUND(AVG(total_laid_off * 1.0)
              / NULLIF(STDEV(total_laid_off), 0), 2) AS cv_ratio
    FROM base_huge
),
median_small AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_laid_off)
        OVER () AS median
    FROM base_small
),
median_huge AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_laid_off)
        OVER () AS median
    FROM base_huge
)
SELECT s.group_label, s.total_events, s.min_value, s.max_value,
       s.avg_value, ms.median, s.std_dev, s.cv_ratio
FROM stats_small s CROSS JOIN median_small ms
UNION ALL
SELECT h.group_label, h.total_events, h.min_value, h.max_value,
       h.avg_value, mh.median, h.std_dev, h.cv_ratio
FROM stats_huge h CROSS JOIN median_huge mh;


-- ── E2: Overall Group Share ───────────────────────────────────
-- How much of the total damage came from huge vs small events?
SELECT
    CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
        AS group_label,
    COUNT(*)            AS events,
    SUM(total_laid_off) AS total_workers,
    ROUND(
        CAST(SUM(total_laid_off) * 100.0
             / SUM(SUM(total_laid_off)) OVER () AS FLOAT)
    , 2)                AS pct_of_all_layoffs
FROM  layoff_staging1
WHERE total_laid_off IS NOT NULL
GROUP BY CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ If Huge events = ~10% of count but ~70% of workers:
    → The crisis is driven by concentrated mega-events,
      not a broad market collapse.
  ✔ Compare cv_ratio between groups:
    → High CV in "Huge" group means those events vary wildly
      in size (10k vs 3k), not all huge events are equal.
  ✔ If avg_value >> median in either group:
    → Even within the group, a few outliers pull the average up.
  ────────────────────────────────────────────────────────────
*/


-- ── E3: Huge Events — Industry Breakdown ─────────────────────
-- Which industries had the most "Huge" layoff events?
SELECT
    industry,
    COUNT(*)                      AS events,
    SUM(total_laid_off)           AS total_workers,
    ROUND(AVG(total_laid_off), 0) AS avg_per_event,
    ROUND(
        CAST(SUM(total_laid_off) * 100.0
             / SUM(SUM(total_laid_off)) OVER () AS FLOAT)
    , 2)                          AS pct_of_huge_group
FROM  layoff_staging1
WHERE total_laid_off >= 3000
  AND total_laid_off  IS NOT NULL
GROUP BY industry
ORDER BY total_workers DESC;


-- ── E4: Small Events — Industry Breakdown ────────────────────
-- Which industries had the most "Small" layoff events?
-- (Different industries may dominate this vs the huge group)
SELECT
    industry,
    COUNT(*)                      AS events,
    SUM(total_laid_off)           AS total_workers,
    ROUND(AVG(total_laid_off), 0) AS avg_per_event,
    ROUND(
        CAST(SUM(total_laid_off) * 100.0
             / SUM(SUM(total_laid_off)) OVER () AS FLOAT)
    , 2)                          AS pct_of_small_group
FROM  layoff_staging1
WHERE total_laid_off <  3000
  AND total_laid_off  IS NOT NULL
GROUP BY industry
ORDER BY total_workers DESC;


-- ── E5: Group Breakdown by Country ───────────────────────────
-- Are huge events concentrated in specific countries?
SELECT
    CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
        AS group_label,
    country,
    COUNT(*)                      AS events,
    SUM(total_laid_off)           AS total_workers,
    ROUND(AVG(total_laid_off), 0) AS avg_per_event,
    ROUND(
        CAST(SUM(total_laid_off) * 100.0
             / SUM(SUM(total_laid_off)) OVER (
                 PARTITION BY CASE WHEN total_laid_off >= 3000
                              THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
               ) AS FLOAT)
    , 2)                          AS pct_within_group
FROM  layoff_staging1
WHERE total_laid_off IS NOT NULL
GROUP BY
    CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END,
    country
ORDER BY group_label, total_workers DESC;


-- ── E6: Group Breakdown by Year ──────────────────────────────
-- Did huge events cluster in a specific year?
SELECT
    CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
        AS group_label,
    YEAR([date])                  AS [year],
    COUNT(*)                      AS events,
    SUM(total_laid_off)           AS total_workers,
    ROUND(AVG(total_laid_off), 0) AS avg_per_event,
    ROUND(
        CAST(SUM(total_laid_off) * 100.0
             / SUM(SUM(total_laid_off)) OVER (
                 PARTITION BY CASE WHEN total_laid_off >= 3000
                              THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
               ) AS FLOAT)
    , 2)                          AS pct_within_group
FROM  layoff_staging1
WHERE total_laid_off IS NOT NULL
  AND [date]          IS NOT NULL
GROUP BY
    CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END,
    YEAR([date])
ORDER BY group_label, [year];

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ E3 vs E4 industry comparison:
    → If "Consumer" tops huge events but "Healthcare" tops small
      events, these are two separate crises, not one.
  ✔ E5 country split:
    → If USA dominates huge events but other countries lead
      small events → the mega-layoffs are a US tech phenomenon.
  ✔ E6 year split:
    → If huge events spike in 2022 but small events are spread
      evenly → 2022 was a concentrated shock, not a slow burn.
  ────────────────────────────────────────────────────────────
*/


-- ============================================================
-- SECTION F — Z-SCORE ANALYSIS
-- Business Question:
--   Within each group, which specific events were true outliers?
--   Which companies were extreme even among the "huge" ones?
-- ============================================================

/*
  WHY THIS MATTERS:
  Saying "Amazon laid off a lot" is obvious.
  A z-score tells you HOW unusual that event was relative
  to its peer group. A z-score of 3.0 means the event was
  3 standard deviations above the group mean — a statistical outlier.

  Z-SCORE INTERPRETATION:
    < 1.0  = Normal, within expected range
    1–2    = Noteworthy, above average
    2–3    = Unusual, worth investigating
    > 3    = Statistical outlier, extreme event
    > 4    = Extremely rare, likely a structural event

  FORMULA:
    z = (x − mean) / standard_deviation
    Computed separately for each group so the comparison
    is fair (huge events are compared to other huge events).
*/

WITH group_stats AS (
    -- Calculate mean and std dev separately for each segment
    SELECT
        CASE WHEN total_laid_off >= 3000 THEN 'Huge (≥3,000)'
             ELSE 'Small (<3,000)'
        END                        AS group_label,
        AVG(total_laid_off * 1.0)  AS group_mean,
        STDEV(total_laid_off)      AS group_std
    FROM  layoff_staging1
    WHERE total_laid_off IS NOT NULL
    GROUP BY CASE WHEN total_laid_off >= 3000
             THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END
)
SELECT
    l.company,
    l.industry,
    l.country,
    l.[date],
    l.total_laid_off,
    s.group_label,
    s.group_mean,
    s.group_std,

    -- Z-score: how many standard deviations from the group mean?
    ROUND(
        (l.total_laid_off - s.group_mean) / NULLIF(s.group_std, 0)
    , 2) AS z_score,

    -- Severity label for easy filtering and reporting
    CASE
        WHEN ABS((l.total_laid_off - s.group_mean)
             / NULLIF(s.group_std, 0)) >= 4 THEN 'Extreme Outlier'
        WHEN ABS((l.total_laid_off - s.group_mean)
             / NULLIF(s.group_std, 0)) >= 3 THEN 'Strong Outlier'
        WHEN ABS((l.total_laid_off - s.group_mean)
             / NULLIF(s.group_std, 0)) >= 2 THEN 'Unusual'
        WHEN ABS((l.total_laid_off - s.group_mean)
             / NULLIF(s.group_std, 0)) >= 1 THEN 'Above Average'
        ELSE 'Normal'
    END AS severity_label

FROM  layoff_staging1 l
JOIN  group_stats s
   ON CASE WHEN l.total_laid_off >= 3000
           THEN 'Huge (≥3,000)' ELSE 'Small (<3,000)' END = s.group_label
WHERE l.total_laid_off IS NOT NULL
  AND l.[date]          IS NOT NULL
ORDER BY z_score DESC;

/*
  ── WHAT TO LOOK FOR ────────────────────────────────────────
  ✔ Filter WHERE severity_label = 'Extreme Outlier'
    → These events are so unusual they can skew every other
      metric in the dataset. Document them separately.
  ✔ Filter WHERE group_label = 'Small (<3,000)' AND z_score > 3
    → A z-score of 3 in the Small group is relatively speaking
      as extreme as the largest huge events.
  ✔ Sort by z_score DESC and look at the top 10:
    → Do they cluster in one year or one industry?
    → If yes → that year/industry had a structural crisis,
      not just a market correction.
  ✔ Negative z-scores (z < -1):
    → These are unusually SMALL events. Could indicate:
      - Early warning cuts before a bigger round
      - Companies that managed layoffs in a controlled way
  ────────────────────────────────────────────────────────────
*/

