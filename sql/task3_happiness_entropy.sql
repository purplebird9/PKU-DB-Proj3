-- Task 3: entropy analysis on the World Happiness Report data in SQLite.
-- Python's runner registers LN().

DROP VIEW IF EXISTS v_task3_joint_metrics;
DROP VIEW IF EXISTS v_task3_feature_importance;
DROP VIEW IF EXISTS v_task3_entropy_metrics;
DROP VIEW IF EXISTS v_happiness_feature_bins;
DROP TABLE IF EXISTS happiness_binned;

DELETE FROM happiness;

INSERT INTO happiness
    (year, overall_rank, country, region, score, gdp_per_capita, social_support,
     healthy_life_expectancy, freedom, generosity, perceptions_of_corruption)
SELECT
    2015, happiness_rank, country, region, happiness_score, economy_gdp_per_capita,
    family, health_life_expectancy, freedom, generosity, trust_government_corruption
FROM happiness_raw_2015
UNION ALL
SELECT
    2016, happiness_rank, country, region, happiness_score, economy_gdp_per_capita,
    family, health_life_expectancy, freedom, generosity, trust_government_corruption
FROM happiness_raw_2016
UNION ALL
SELECT
    2017, happiness_rank, country, NULL, happiness_score, economy_gdp_per_capita,
    family, health_life_expectancy, freedom, generosity, trust_government_corruption
FROM happiness_raw_2017
UNION ALL
SELECT
    2018, overall_rank, country_or_region, NULL, score, gdp_per_capita,
    social_support, healthy_life_expectancy, freedom_to_make_life_choices,
    generosity, perceptions_of_corruption
FROM happiness_raw_2018
UNION ALL
SELECT
    2019, overall_rank, country_or_region, NULL, score, gdp_per_capita,
    social_support, healthy_life_expectancy, freedom_to_make_life_choices,
    generosity, perceptions_of_corruption
FROM happiness_raw_2019;

CREATE TABLE happiness_binned AS
SELECT
    h.*,
    CASE
        WHEN score >= 6.0 THEN 'high'
        WHEN score >= 4.5 THEN 'middle'
        ELSE 'low'
    END AS score_level,
    NTILE(3) OVER (PARTITION BY year ORDER BY gdp_per_capita) AS gdp_bin,
    NTILE(3) OVER (PARTITION BY year ORDER BY social_support) AS social_support_bin,
    NTILE(3) OVER (PARTITION BY year ORDER BY healthy_life_expectancy) AS health_bin,
    NTILE(3) OVER (PARTITION BY year ORDER BY freedom) AS freedom_bin,
    NTILE(3) OVER (PARTITION BY year ORDER BY generosity) AS generosity_bin,
    NTILE(3) OVER (PARTITION BY year ORDER BY perceptions_of_corruption) AS corruption_bin
FROM happiness h
WHERE score IS NOT NULL;

CREATE INDEX idx_happiness_binned_year ON happiness_binned(year);
CREATE INDEX idx_happiness_binned_level ON happiness_binned(score_level);

CREATE VIEW v_happiness_feature_bins AS
SELECT year, country, score_level, 'gdp_per_capita' AS feature_name, CAST(gdp_bin AS TEXT) AS feature_bin
FROM happiness_binned
UNION ALL
SELECT year, country, score_level, 'social_support', CAST(social_support_bin AS TEXT)
FROM happiness_binned
UNION ALL
SELECT year, country, score_level, 'healthy_life_expectancy', CAST(health_bin AS TEXT)
FROM happiness_binned
UNION ALL
SELECT year, country, score_level, 'freedom', CAST(freedom_bin AS TEXT)
FROM happiness_binned
UNION ALL
SELECT year, country, score_level, 'generosity', CAST(generosity_bin AS TEXT)
FROM happiness_binned
UNION ALL
SELECT year, country, score_level, 'perceptions_of_corruption', CAST(corruption_bin AS TEXT)
FROM happiness_binned;

CREATE VIEW v_task3_entropy_metrics AS
WITH scoped AS (
    SELECT CAST(year AS TEXT) AS scope_year, score_level
    FROM happiness_binned
    UNION ALL
    SELECT 'all' AS scope_year, score_level
    FROM happiness_binned
),
label_counts AS (
    SELECT scope_year, score_level, COUNT(*) AS cnt
    FROM scoped
    GROUP BY scope_year, score_level
),
totals AS (
    SELECT scope_year, SUM(cnt) AS total_count
    FROM label_counts
    GROUP BY scope_year
),
entropy AS (
    SELECT
        lc.scope_year,
        ROUND(SUM(-(1.0 * lc.cnt / t.total_count) * (LN(1.0 * lc.cnt / t.total_count) / LN(2))), 6) AS entropy_y,
        ROUND(1 - SUM(POWER(1.0 * lc.cnt / t.total_count, 2)), 6) AS gini,
        t.total_count
    FROM label_counts lc
    JOIN totals t ON lc.scope_year = t.scope_year
    GROUP BY lc.scope_year, t.total_count
)
SELECT
    scope_year,
    total_count,
    entropy_y,
    gini
FROM entropy
ORDER BY CASE WHEN scope_year = 'all' THEN 0 ELSE 1 END, scope_year;

CREATE VIEW v_task3_feature_importance AS
WITH scoped_features AS (
    SELECT CAST(year AS TEXT) AS scope_year, score_level, feature_name, feature_bin
    FROM v_happiness_feature_bins
    UNION ALL
    SELECT 'all' AS scope_year, score_level, feature_name, feature_bin
    FROM v_happiness_feature_bins
),
totals AS (
    SELECT scope_year, feature_name, COUNT(*) AS total_count
    FROM scoped_features
    GROUP BY scope_year, feature_name
),
label_counts AS (
    SELECT scope_year, feature_name, score_level, COUNT(*) AS cnt
    FROM scoped_features
    GROUP BY scope_year, feature_name, score_level
),
entropy_y AS (
    SELECT
        lc.scope_year,
        lc.feature_name,
        SUM(-(1.0 * lc.cnt / t.total_count) * (LN(1.0 * lc.cnt / t.total_count) / LN(2))) AS entropy_y
    FROM label_counts lc
    JOIN totals t
      ON lc.scope_year = t.scope_year
     AND lc.feature_name = t.feature_name
    GROUP BY lc.scope_year, lc.feature_name
),
feature_counts AS (
    SELECT scope_year, feature_name, feature_bin, COUNT(*) AS feature_count
    FROM scoped_features
    GROUP BY scope_year, feature_name, feature_bin
),
feature_label_counts AS (
    SELECT scope_year, feature_name, feature_bin, score_level, COUNT(*) AS cnt
    FROM scoped_features
    GROUP BY scope_year, feature_name, feature_bin, score_level
),
bin_entropy AS (
    SELECT
        fl.scope_year,
        fl.feature_name,
        fl.feature_bin,
        fc.feature_count,
        SUM(-(1.0 * fl.cnt / fc.feature_count) * (LN(1.0 * fl.cnt / fc.feature_count) / LN(2))) AS entropy_y_given_bin
    FROM feature_label_counts fl
    JOIN feature_counts fc
      ON fl.scope_year = fc.scope_year
     AND fl.feature_name = fc.feature_name
     AND fl.feature_bin = fc.feature_bin
    GROUP BY fl.scope_year, fl.feature_name, fl.feature_bin, fc.feature_count
),
conditional_entropy AS (
    SELECT
        be.scope_year,
        be.feature_name,
        SUM((1.0 * be.feature_count / t.total_count) * be.entropy_y_given_bin) AS conditional_entropy
    FROM bin_entropy be
    JOIN totals t
      ON be.scope_year = t.scope_year
     AND be.feature_name = t.feature_name
    GROUP BY be.scope_year, be.feature_name
),
feature_entropy AS (
    SELECT
        fc.scope_year,
        fc.feature_name,
        SUM(-(1.0 * fc.feature_count / t.total_count) * (LN(1.0 * fc.feature_count / t.total_count) / LN(2))) AS feature_entropy
    FROM feature_counts fc
    JOIN totals t
      ON fc.scope_year = t.scope_year
     AND fc.feature_name = t.feature_name
    GROUP BY fc.scope_year, fc.feature_name
)
SELECT
    ey.scope_year,
    ey.feature_name,
    ROUND(ey.entropy_y, 6) AS entropy_y,
    ROUND(ce.conditional_entropy, 6) AS conditional_entropy,
    ROUND(ey.entropy_y - ce.conditional_entropy, 6) AS information_gain,
    ROUND(fe.feature_entropy, 6) AS feature_entropy,
    ROUND((ey.entropy_y - ce.conditional_entropy) / NULLIF(fe.feature_entropy, 0), 6) AS gain_ratio
FROM entropy_y ey
JOIN conditional_entropy ce
  ON ey.scope_year = ce.scope_year
 AND ey.feature_name = ce.feature_name
JOIN feature_entropy fe
  ON ey.scope_year = fe.scope_year
 AND ey.feature_name = fe.feature_name
ORDER BY
    CASE WHEN ey.scope_year = 'all' THEN 0 ELSE 1 END,
    ey.scope_year,
    information_gain DESC,
    ey.feature_name;

CREATE VIEW v_task3_joint_metrics AS
WITH base AS (
    SELECT
        CAST(year AS TEXT) AS scope_year,
        score_level,
        'gdp_plus_social_support' AS combo_name,
        CAST(gdp_bin AS TEXT) || '-' || CAST(social_support_bin AS TEXT) AS combo_bin
    FROM happiness_binned
    UNION ALL
    SELECT
        CAST(year AS TEXT),
        score_level,
        'social_support_plus_health',
        CAST(social_support_bin AS TEXT) || '-' || CAST(health_bin AS TEXT)
    FROM happiness_binned
    UNION ALL
    SELECT
        CAST(year AS TEXT),
        score_level,
        'freedom_plus_corruption',
        CAST(freedom_bin AS TEXT) || '-' || CAST(corruption_bin AS TEXT)
    FROM happiness_binned
    UNION ALL
    SELECT
        'all',
        score_level,
        'gdp_plus_social_support',
        CAST(gdp_bin AS TEXT) || '-' || CAST(social_support_bin AS TEXT)
    FROM happiness_binned
    UNION ALL
    SELECT
        'all',
        score_level,
        'social_support_plus_health',
        CAST(social_support_bin AS TEXT) || '-' || CAST(health_bin AS TEXT)
    FROM happiness_binned
    UNION ALL
    SELECT
        'all',
        score_level,
        'freedom_plus_corruption',
        CAST(freedom_bin AS TEXT) || '-' || CAST(corruption_bin AS TEXT)
    FROM happiness_binned
),
totals AS (
    SELECT scope_year, combo_name, COUNT(*) AS total_count
    FROM base
    GROUP BY scope_year, combo_name
),
label_counts AS (
    SELECT scope_year, combo_name, score_level, COUNT(*) AS cnt
    FROM base
    GROUP BY scope_year, combo_name, score_level
),
combo_counts AS (
    SELECT scope_year, combo_name, combo_bin, COUNT(*) AS cnt
    FROM base
    GROUP BY scope_year, combo_name, combo_bin
),
joint_counts AS (
    SELECT scope_year, combo_name, combo_bin, score_level, COUNT(*) AS cnt
    FROM base
    GROUP BY scope_year, combo_name, combo_bin, score_level
),
entropy_y AS (
    SELECT
        lc.scope_year,
        lc.combo_name,
        SUM(-(1.0 * lc.cnt / t.total_count) * (LN(1.0 * lc.cnt / t.total_count) / LN(2))) AS h_y
    FROM label_counts lc
    JOIN totals t ON lc.scope_year = t.scope_year AND lc.combo_name = t.combo_name
    GROUP BY lc.scope_year, lc.combo_name
),
entropy_x AS (
    SELECT
        cc.scope_year,
        cc.combo_name,
        SUM(-(1.0 * cc.cnt / t.total_count) * (LN(1.0 * cc.cnt / t.total_count) / LN(2))) AS h_x
    FROM combo_counts cc
    JOIN totals t ON cc.scope_year = t.scope_year AND cc.combo_name = t.combo_name
    GROUP BY cc.scope_year, cc.combo_name
),
joint_entropy AS (
    SELECT
        jc.scope_year,
        jc.combo_name,
        SUM(-(1.0 * jc.cnt / t.total_count) * (LN(1.0 * jc.cnt / t.total_count) / LN(2))) AS h_xy
    FROM joint_counts jc
    JOIN totals t ON jc.scope_year = t.scope_year AND jc.combo_name = t.combo_name
    GROUP BY jc.scope_year, jc.combo_name
)
SELECT
    ey.scope_year,
    ey.combo_name,
    ROUND(ey.h_y, 6) AS entropy_y,
    ROUND(ex.h_x, 6) AS feature_entropy,
    ROUND(je.h_xy, 6) AS joint_entropy,
    ROUND(je.h_xy - ex.h_x, 6) AS conditional_entropy_y_given_x,
    ROUND(ey.h_y + ex.h_x - je.h_xy, 6) AS mutual_information
FROM entropy_y ey
JOIN entropy_x ex ON ey.scope_year = ex.scope_year AND ey.combo_name = ex.combo_name
JOIN joint_entropy je ON ey.scope_year = je.scope_year AND ey.combo_name = je.combo_name
ORDER BY
    CASE WHEN ey.scope_year = 'all' THEN 0 ELSE 1 END,
    ey.scope_year,
    mutual_information DESC,
    ey.combo_name;

