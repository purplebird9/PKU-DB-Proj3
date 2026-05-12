"""Export result views from the local SQLite database into results/*.csv."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from sqlite_utils import connect_sqlite


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = REPO_ROOT / "data" / "dbproj3.sqlite"
RESULTS_DIR = REPO_ROOT / "results"

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


def export_view(conn, view_name: str, filename: str) -> None:
    rows = conn.execute(f"SELECT * FROM {view_name}").fetchall()
    output_path = RESULTS_DIR / filename
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        if rows:
            writer.writerow(rows[0].keys())
            writer.writerows([tuple(row) for row in rows])
        else:
            columns = [item[1] for item in conn.execute(f"PRAGMA table_info({view_name})")]
            writer.writerow(columns)

    print(f"Exported {view_name} -> {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export DBProj3 SQLite views into CSV files.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="SQLite database path.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    conn = connect_sqlite(args.db)
    try:
        for view_name, filename in EXPORTS.items():
            export_view(conn, view_name, filename)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

