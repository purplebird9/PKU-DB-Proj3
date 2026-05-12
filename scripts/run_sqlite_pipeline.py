"""Run the full DBProj3 SQLite pipeline.

This script requires no database server and no third-party Python package.
It creates data/dbproj3.sqlite, loads the CSV datasets, executes all SQL
scripts, and exports the result views into results/*.csv.

Example:
    python scripts/run_sqlite_pipeline.py
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from sqlite_utils import connect_sqlite


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = REPO_ROOT / "data" / "dbproj3.sqlite"
SQL_DIR = REPO_ROOT / "sql"
RESULTS_DIR = REPO_ROOT / "results"
MOVIELENS_DIR = REPO_ROOT / "data" / "movielen数据集"
HAPPINESS_DIR = REPO_ROOT / "data" / "世界幸福指数数据集"

EXPORTS = {
    "v_task1_before_after": "task1_before_after.csv",
    "v_task1_quality_summary": "task1_quality_summary.csv",
    "v_task2_dataset_summary": "task2_dataset_summary.csv",
    "v_task2_top_movies": "task2_top_movies.csv",
    "v_task2_genre_top_movies": "task2_genre_top_movies.csv",
    "v_task2_user_top_rating_genres": "task2_user_top_rating_genres.csv",
    "v_task2_user_top_watch_genres": "task2_user_top_watch_genres.csv",
    "v_task2_similar_users": "task2_similar_users.csv",
    "v_task3_entropy_metrics": "task3_entropy_metrics.csv",
    "v_task3_feature_importance": "task3_feature_importance.csv",
    "v_task3_joint_metrics": "task3_joint_metrics.csv",
}


def execute_script(conn, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    conn.executescript(sql)
    conn.commit()
    print(f"Executed {path.relative_to(REPO_ROOT)}")


def normalize_blank(value: str) -> str | None:
    value = value.strip()
    return value if value != "" else None


def load_csv(conn, table: str, path: Path, columns: list[str]) -> None:
    if not path.exists():
        raise FileNotFoundError(path)

    placeholders = ", ".join(["?"] * len(columns))
    column_sql = ", ".join(columns)
    sql = f"INSERT INTO {table} ({column_sql}) VALUES ({placeholders})"

    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        next(reader)
        rows = [tuple(normalize_blank(value) for value in row[: len(columns)]) for row in reader]

    conn.executemany(sql, rows)
    conn.commit()
    print(f"Loaded {path.relative_to(REPO_ROOT)} -> {table} ({len(rows)} rows)")


def load_datasets(conn) -> None:
    load_csv(conn, "movies", MOVIELENS_DIR / "movies.csv", ["movieId", "title", "genres"])
    load_csv(conn, "ratings", MOVIELENS_DIR / "ratings.csv", ["userId", "movieId", "rating", "rating_ts"])

    load_csv(
        conn,
        "happiness_raw_2015",
        HAPPINESS_DIR / "2015.csv",
        [
            "country",
            "region",
            "happiness_rank",
            "happiness_score",
            "standard_error",
            "economy_gdp_per_capita",
            "family",
            "health_life_expectancy",
            "freedom",
            "trust_government_corruption",
            "generosity",
            "dystopia_residual",
        ],
    )
    load_csv(
        conn,
        "happiness_raw_2016",
        HAPPINESS_DIR / "2016.csv",
        [
            "country",
            "region",
            "happiness_rank",
            "happiness_score",
            "lower_confidence_interval",
            "upper_confidence_interval",
            "economy_gdp_per_capita",
            "family",
            "health_life_expectancy",
            "freedom",
            "trust_government_corruption",
            "generosity",
            "dystopia_residual",
        ],
    )
    load_csv(
        conn,
        "happiness_raw_2017",
        HAPPINESS_DIR / "2017.csv",
        [
            "country",
            "happiness_rank",
            "happiness_score",
            "whisker_high",
            "whisker_low",
            "economy_gdp_per_capita",
            "family",
            "health_life_expectancy",
            "freedom",
            "generosity",
            "trust_government_corruption",
            "dystopia_residual",
        ],
    )
    for year in (2018, 2019):
        load_csv(
            conn,
            f"happiness_raw_{year}",
            HAPPINESS_DIR / f"{year}.csv",
            [
                "overall_rank",
                "country_or_region",
                "score",
                "gdp_per_capita",
                "social_support",
                "healthy_life_expectancy",
                "freedom_to_make_life_choices",
                "generosity",
                "perceptions_of_corruption",
            ],
        )


def export_view(conn, view_name: str, filename: str) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    rows = conn.execute(f"SELECT * FROM {view_name}").fetchall()
    output_path = RESULTS_DIR / filename

    with output_path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        if rows:
            writer.writerow(rows[0].keys())
            writer.writerows([tuple(row) for row in rows])
        else:
            columns = [item[1] for item in conn.execute(f"PRAGMA table_info({view_name})")]
            writer.writerow(columns)

    print(f"Exported {view_name} -> {output_path.relative_to(REPO_ROOT)} ({len(rows)} rows)")


def export_results(conn) -> None:
    for view_name, filename in EXPORTS.items():
        export_view(conn, view_name, filename)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run DBProj3 with local SQLite.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="SQLite database path.")
    parser.add_argument("--skip-export", action="store_true", help="Run SQL but do not export result CSV files.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = connect_sqlite(str(db_path))
    try:
        execute_script(conn, SQL_DIR / "00_create_database.sql")
        load_datasets(conn)
        execute_script(conn, SQL_DIR / "task1_preprocessing.sql")
        execute_script(conn, SQL_DIR / "task2_movielens_analysis.sql")
        execute_script(conn, SQL_DIR / "task3_happiness_entropy.sql")
        if not args.skip_export:
            export_results(conn)
    finally:
        conn.close()

    print(f"SQLite pipeline finished: {db_path}")


if __name__ == "__main__":
    main()

