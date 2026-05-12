"""Compatibility wrapper.

The project now uses SQLite instead of MySQL. This wrapper runs the full
SQLite pipeline so older instructions that mention run_all_sql.py still work.
"""

from run_sqlite_pipeline import main


if __name__ == "__main__":
    main()

