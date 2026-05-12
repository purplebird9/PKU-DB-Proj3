-- Database Lab 3 bootstrap script.
-- Target database: SQLite 3, executed by Python's built-in sqlite3 module.

PRAGMA foreign_keys = OFF;

DROP VIEW IF EXISTS v_task1_quality_summary;
DROP VIEW IF EXISTS v_task1_before_after;
DROP VIEW IF EXISTS v_task2_similar_users;
DROP VIEW IF EXISTS v_task2_user_top_watch_genres;
DROP VIEW IF EXISTS v_task2_user_top_rating_genres;
DROP VIEW IF EXISTS v_task2_genre_top_movies;
DROP VIEW IF EXISTS v_task2_top_movies;
DROP VIEW IF EXISTS v_task2_dataset_summary;
DROP VIEW IF EXISTS v_task3_joint_metrics;
DROP VIEW IF EXISTS v_task3_feature_importance;
DROP VIEW IF EXISTS v_task3_entropy_metrics;
DROP VIEW IF EXISTS v_happiness_feature_bins;

DROP TABLE IF EXISTS user_standard_data;
DROP TABLE IF EXISTS user_raw_data;
DROP TABLE IF EXISTS movie_genres;
DROP TABLE IF EXISTS ratings;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS happiness_binned;
DROP TABLE IF EXISTS happiness;
DROP TABLE IF EXISTS happiness_raw_2019;
DROP TABLE IF EXISTS happiness_raw_2018;
DROP TABLE IF EXISTS happiness_raw_2017;
DROP TABLE IF EXISTS happiness_raw_2016;
DROP TABLE IF EXISTS happiness_raw_2015;

CREATE TABLE user_raw_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_name TEXT,
    raw_phone TEXT,
    raw_email TEXT,
    raw_register_time TEXT,
    raw_address TEXT,
    raw_age TEXT,
    raw_remark TEXT
);

CREATE TABLE movies (
    movieId INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    genres TEXT NOT NULL
);

CREATE TABLE ratings (
    userId INTEGER NOT NULL,
    movieId INTEGER NOT NULL,
    rating REAL NOT NULL,
    rating_ts INTEGER NOT NULL
);

CREATE INDEX idx_ratings_movie ON ratings(movieId);
CREATE INDEX idx_ratings_user ON ratings(userId);
CREATE INDEX idx_ratings_user_movie ON ratings(userId, movieId);

CREATE TABLE movie_genres (
    movieId INTEGER NOT NULL,
    genre TEXT NOT NULL,
    PRIMARY KEY (movieId, genre)
);

CREATE INDEX idx_movie_genres_genre ON movie_genres(genre);

CREATE TABLE happiness_raw_2015 (
    country TEXT,
    region TEXT,
    happiness_rank INTEGER,
    happiness_score REAL,
    standard_error REAL,
    economy_gdp_per_capita REAL,
    family REAL,
    health_life_expectancy REAL,
    freedom REAL,
    trust_government_corruption REAL,
    generosity REAL,
    dystopia_residual REAL
);

CREATE TABLE happiness_raw_2016 (
    country TEXT,
    region TEXT,
    happiness_rank INTEGER,
    happiness_score REAL,
    lower_confidence_interval REAL,
    upper_confidence_interval REAL,
    economy_gdp_per_capita REAL,
    family REAL,
    health_life_expectancy REAL,
    freedom REAL,
    trust_government_corruption REAL,
    generosity REAL,
    dystopia_residual REAL
);

CREATE TABLE happiness_raw_2017 (
    country TEXT,
    happiness_rank INTEGER,
    happiness_score REAL,
    whisker_high REAL,
    whisker_low REAL,
    economy_gdp_per_capita REAL,
    family REAL,
    health_life_expectancy REAL,
    freedom REAL,
    generosity REAL,
    trust_government_corruption REAL,
    dystopia_residual REAL
);

CREATE TABLE happiness_raw_2018 (
    overall_rank INTEGER,
    country_or_region TEXT,
    score REAL,
    gdp_per_capita REAL,
    social_support REAL,
    healthy_life_expectancy REAL,
    freedom_to_make_life_choices REAL,
    generosity REAL,
    perceptions_of_corruption REAL
);

CREATE TABLE happiness_raw_2019 (
    overall_rank INTEGER,
    country_or_region TEXT,
    score REAL,
    gdp_per_capita REAL,
    social_support REAL,
    healthy_life_expectancy REAL,
    freedom_to_make_life_choices REAL,
    generosity REAL,
    perceptions_of_corruption REAL
);

CREATE TABLE happiness (
    year INTEGER NOT NULL,
    overall_rank INTEGER,
    country TEXT NOT NULL,
    region TEXT,
    score REAL,
    gdp_per_capita REAL,
    social_support REAL,
    healthy_life_expectancy REAL,
    freedom REAL,
    generosity REAL,
    perceptions_of_corruption REAL
);

CREATE INDEX idx_happiness_year ON happiness(year);
CREATE INDEX idx_happiness_country ON happiness(country);

