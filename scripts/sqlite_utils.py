"""Shared SQLite helpers for DBProj3.

Everything here uses Python's standard library only.
"""

from __future__ import annotations

import math
import re
import sqlite3
from datetime import date


def regexp(pattern: str | None, value: object) -> int:
    if pattern is None or value is None:
        return 0
    return 1 if re.search(pattern, str(value)) else 0


def regexp_replace(value: object, pattern: str, repl: str) -> str:
    if value is None:
        return ""
    return re.sub(pattern, repl, str(value))


def regexp_substr(value: object, pattern: str, occurrence: int = 1) -> str | None:
    if value is None:
        return None
    matches = re.findall(pattern, str(value))
    index = int(occurrence) - 1
    if 0 <= index < len(matches):
        match = matches[index]
        if isinstance(match, tuple):
            return match[0]
        return match
    return None


def safe_date(year: object, month: object, day: object) -> str | None:
    try:
        parsed = date(int(year), int(month), int(day))
    except (TypeError, ValueError):
        return None
    return parsed.isoformat()


def ln(value: object) -> float | None:
    try:
        value_float = float(value)
    except (TypeError, ValueError):
        return None
    if value_float <= 0:
        return None
    return math.log(value_float)


def power(value: object, exponent: object) -> float | None:
    try:
        return float(value) ** float(exponent)
    except (TypeError, ValueError):
        return None


class StddevSamp:
    def __init__(self) -> None:
        self.values: list[float] = []

    def step(self, value: object) -> None:
        if value is None:
            return
        self.values.append(float(value))

    def finalize(self) -> float | None:
        n = len(self.values)
        if n < 2:
            return None
        mean = sum(self.values) / n
        variance = sum((value - mean) ** 2 for value in self.values) / (n - 1)
        return math.sqrt(variance)


def connect_sqlite(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.create_function("REGEXP", 2, regexp)
    conn.create_function("REGEXP_REPLACE", 3, regexp_replace)
    conn.create_function("REGEXP_SUBSTR", 3, regexp_substr)
    conn.create_function("SAFE_DATE", 3, safe_date)
    conn.create_function("LN", 1, ln)
    conn.create_function("POWER", 2, power)
    conn.create_aggregate("STDDEV_SAMP", 1, StddevSamp)
    return conn
