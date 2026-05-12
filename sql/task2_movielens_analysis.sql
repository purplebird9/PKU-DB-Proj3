-- Task 2: MovieLens analysis queries in SQLite.
-- Run after movies.csv and ratings.csv have been loaded by scripts/run_sqlite_pipeline.py.

DROP VIEW IF EXISTS v_task2_similar_users;
DROP VIEW IF EXISTS v_task2_user_top_watch_genres;
DROP VIEW IF EXISTS v_task2_user_top_rating_genres;
DROP VIEW IF EXISTS v_task2_genre_top_movies;
DROP VIEW IF EXISTS v_task2_top_movies;
DROP VIEW IF EXISTS v_task2_dataset_summary;

DELETE FROM movie_genres;

INSERT OR IGNORE INTO movie_genres (movieId, genre)
WITH RECURSIVE split(movieId, rest, genre) AS (
    SELECT
        movieId,
        genres || '|',
        ''
    FROM movies
    WHERE genres <> '(no genres listed)'
    UNION ALL
    SELECT
        movieId,
        SUBSTR(rest, INSTR(rest, '|') + 1),
        TRIM(SUBSTR(rest, 1, INSTR(rest, '|') - 1))
    FROM split
    WHERE rest <> ''
)
SELECT movieId, genre
FROM split
WHERE genre <> '';

CREATE VIEW v_task2_dataset_summary AS
SELECT 'movies' AS metric, COUNT(*) AS value FROM movies
UNION ALL
SELECT 'ratings', COUNT(*) FROM ratings
UNION ALL
SELECT 'users', COUNT(DISTINCT userId) FROM ratings
UNION ALL
SELECT 'genres', COUNT(DISTINCT genre) FROM movie_genres;

CREATE VIEW v_task2_top_movies AS
SELECT
    m.movieId,
    m.title,
    COUNT(*) AS rating_count,
    ROUND(AVG(r.rating), 3) AS avg_rating
FROM ratings r
JOIN movies m ON r.movieId = m.movieId
GROUP BY m.movieId, m.title
HAVING COUNT(*) >= 20
ORDER BY avg_rating DESC, rating_count DESC, m.title
LIMIT 10;

CREATE VIEW v_task2_genre_top_movies AS
WITH movie_rating AS (
    SELECT
        mg.genre,
        m.movieId,
        m.title,
        COUNT(*) AS rating_count,
        ROUND(AVG(r.rating), 3) AS avg_rating
    FROM ratings r
    JOIN movies m ON r.movieId = m.movieId
    JOIN movie_genres mg ON m.movieId = mg.movieId
    GROUP BY mg.genre, m.movieId, m.title
    HAVING COUNT(*) >= 10
),
ranked AS (
    SELECT
        movie_rating.*,
        ROW_NUMBER() OVER (
            PARTITION BY genre
            ORDER BY avg_rating DESC, rating_count DESC, title
        ) AS genre_rank
    FROM movie_rating
)
SELECT
    genre,
    genre_rank,
    movieId,
    title,
    rating_count,
    avg_rating
FROM ranked
WHERE genre_rank <= 10
ORDER BY genre, genre_rank;

CREATE VIEW v_task2_user_top_rating_genres AS
WITH user_genre AS (
    SELECT
        r.userId,
        mg.genre,
        COUNT(*) AS watch_count,
        ROUND(AVG(r.rating), 3) AS avg_user_genre_rating
    FROM ratings r
    JOIN movie_genres mg ON r.movieId = mg.movieId
    GROUP BY r.userId, mg.genre
    HAVING COUNT(*) >= 2
),
ranked AS (
    SELECT
        user_genre.*,
        ROW_NUMBER() OVER (
            PARTITION BY userId
            ORDER BY avg_user_genre_rating DESC, watch_count DESC, genre
        ) AS genre_rank
    FROM user_genre
)
SELECT
    userId,
    genre_rank,
    genre,
    watch_count,
    avg_user_genre_rating
FROM ranked
WHERE genre_rank <= 5
ORDER BY userId, genre_rank;

CREATE VIEW v_task2_user_top_watch_genres AS
WITH user_genre AS (
    SELECT
        r.userId,
        mg.genre,
        COUNT(*) AS watch_count,
        ROUND(AVG(r.rating), 3) AS avg_user_genre_rating
    FROM ratings r
    JOIN movie_genres mg ON r.movieId = mg.movieId
    GROUP BY r.userId, mg.genre
),
ranked AS (
    SELECT
        user_genre.*,
        ROW_NUMBER() OVER (
            PARTITION BY userId
            ORDER BY watch_count DESC, avg_user_genre_rating DESC, genre
        ) AS genre_rank
    FROM user_genre
)
SELECT
    userId,
    genre_rank,
    genre,
    watch_count,
    avg_user_genre_rating
FROM ranked
WHERE genre_rank <= 5
ORDER BY userId, genre_rank;

CREATE VIEW v_task2_similar_users AS
WITH common_movies AS (
    SELECT
        r1.userId AS user_a,
        r2.userId AS user_b,
        r1.movieId,
        r1.rating AS rating_a,
        r2.rating AS rating_b,
        r1.rating - r2.rating AS rating_diff
    FROM ratings r1
    JOIN ratings r2
      ON r1.movieId = r2.movieId
     AND r1.userId < r2.userId
),
genre_common_counts AS (
    SELECT
        cm.user_a,
        cm.user_b,
        mg.genre,
        COUNT(DISTINCT cm.movieId) AS common_watch_count
    FROM common_movies cm
    JOIN movie_genres mg ON cm.movieId = mg.movieId
    GROUP BY cm.user_a, cm.user_b, mg.genre
    HAVING COUNT(DISTINCT cm.movieId) >= 3
),
qualified_pairs AS (
    SELECT
        user_a,
        user_b,
        COUNT(*) AS qualified_common_genre_count,
        GROUP_CONCAT(genre || ':' || common_watch_count, '; ') AS common_genres
    FROM genre_common_counts
    GROUP BY user_a, user_b
    HAVING COUNT(*) >= 2
),
pair_rating_stats AS (
    SELECT
        user_a,
        user_b,
        COUNT(DISTINCT movieId) AS total_common_movies,
        ROUND(STDDEV_SAMP(rating_diff), 4) AS rating_diff_stddev,
        ROUND(AVG(ABS(rating_diff)), 4) AS avg_abs_rating_diff
    FROM common_movies
    GROUP BY user_a, user_b
    HAVING COUNT(DISTINCT movieId) >= 2
)
SELECT
    qp.user_a,
    qp.user_b,
    qp.qualified_common_genre_count,
    prs.total_common_movies,
    prs.rating_diff_stddev,
    prs.avg_abs_rating_diff,
    qp.common_genres
FROM qualified_pairs qp
JOIN pair_rating_stats prs
  ON qp.user_a = prs.user_a
 AND qp.user_b = prs.user_b
WHERE prs.rating_diff_stddev <= 0.75
ORDER BY
    qp.qualified_common_genre_count DESC,
    prs.total_common_movies DESC,
    prs.rating_diff_stddev ASC
LIMIT 100;

