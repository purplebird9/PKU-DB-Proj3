"""Compatibility note.

Raw data loading is now part of scripts/run_sqlite_pipeline.py because SQLite
uses a local file database and Python's built-in csv module.
"""

from run_sqlite_pipeline import main


if __name__ == "__main__":
    main()

