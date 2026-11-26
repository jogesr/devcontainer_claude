from pathlib import Path

import pytest

from motorlog.analysis import build_report, load_measurements, stats
from motorlog.cli import main

CSV = """zeitstempel,drehzahl_rpm,strom_a,temperatur_c
2026-11-20T10:00:00,1000,1.0,40.0
2026-11-20T10:01:00,2000,2.0,85.5
2026-11-20T10:02:00,3000,3.0,60.0
"""


@pytest.fixture
def csv_file(tmp_path: Path) -> Path:
    p = tmp_path / "messung.csv"
    p.write_text(CSV, encoding="utf-8")
    return p


def test_load_measurements(csv_file):
    ms = load_measurements(csv_file)
    assert len(ms) == 3
    assert ms[1].temperature_c == 85.5


def test_missing_column(tmp_path):
    p = tmp_path / "kaputt.csv"
    p.write_text("zeitstempel,drehzahl_rpm\n2026-11-20T10:00:00,1000\n", encoding="utf-8")
    with pytest.raises(ValueError, match="strom_a"):
        load_measurements(p)


def test_stats():
    s = stats([1.0, 2.0, 3.0])
    assert (s.minimum, s.maximum, s.average) == (1.0, 3.0, 2.0)


def test_stats_empty():
    with pytest.raises(ValueError):
        stats([])


def test_overheated(csv_file):
    report = build_report(load_measurements(csv_file), max_temp=80.0)
    assert [m.timestamp for m in report.overheated] == ["2026-11-20T10:01:00"]


def test_cli_warns_and_returns_2(csv_file, capsys):
    assert main([str(csv_file)]) == 2
    out = capsys.readouterr().out
    assert "3 Messungen" in out
    assert "WARNUNG: 1 Messung(en)" in out


def test_cli_ok_with_higher_limit(csv_file, capsys):
    assert main([str(csv_file), "--max-temp", "90"]) == 0
    assert "OK: keine Messung" in capsys.readouterr().out


def test_cli_missing_file(tmp_path, capsys):
    assert main([str(tmp_path / "gibtsnicht.csv")]) == 1
    assert "Fehler" in capsys.readouterr().err
