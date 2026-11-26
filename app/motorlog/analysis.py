"""Auswertung von Prüfstand-Messdaten (CSV)."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from statistics import mean

COLUMNS = ("zeitstempel", "drehzahl_rpm", "strom_a", "temperatur_c")


@dataclass(frozen=True)
class Measurement:
    timestamp: str
    speed_rpm: float
    current_a: float
    temperature_c: float


@dataclass(frozen=True)
class Stats:
    minimum: float
    maximum: float
    average: float


@dataclass(frozen=True)
class Report:
    count: int
    speed: Stats
    current: Stats
    temperature: Stats
    overheated: list[Measurement]
    max_temp: float


def load_measurements(path: str | Path) -> list[Measurement]:
    """Liest eine CSV-Datei mit den Spalten aus COLUMNS."""
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        missing = set(COLUMNS) - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Fehlende Spalten: {', '.join(sorted(missing))}")
        return [
            Measurement(
                timestamp=row["zeitstempel"],
                speed_rpm=float(row["drehzahl_rpm"]),
                current_a=float(row["strom_a"]),
                temperature_c=float(row["temperatur_c"]),
            )
            for row in reader
        ]


def stats(values: list[float]) -> Stats:
    if not values:
        raise ValueError("Keine Messwerte vorhanden")
    return Stats(minimum=min(values), maximum=max(values), average=mean(values))


def build_report(measurements: list[Measurement], max_temp: float = 80.0) -> Report:
    return Report(
        count=len(measurements),
        speed=stats([m.speed_rpm for m in measurements]),
        current=stats([m.current_a for m in measurements]),
        temperature=stats([m.temperature_c for m in measurements]),
        overheated=[m for m in measurements if m.temperature_c > max_temp],
        max_temp=max_temp,
    )
