"""Kommandozeile: motorlog <datei.csv> [--max-temp 80]"""

from __future__ import annotations

import argparse
import sys

from motorlog.analysis import Report, build_report, load_measurements


def format_report(path: str, report: Report) -> str:
    lines = [
        f"Messdatei: {path} ({report.count} Messungen)",
        "",
        f"{'Kenngrösse':<18}{'Min':>10}{'Max':>10}{'Mittel':>10}",
    ]
    for label, s in (
        ("Drehzahl [rpm]", report.speed),
        ("Strom [A]", report.current),
        ("Temperatur [°C]", report.temperature),
    ):
        lines.append(f"{label:<18}{s.minimum:>10.1f}{s.maximum:>10.1f}{s.average:>10.1f}")

    lines.append("")
    if report.overheated:
        lines.append(f"WARNUNG: {len(report.overheated)} Messung(en) über {report.max_temp:.1f} °C")
        for m in report.overheated:
            lines.append(f"  {m.timestamp}  {m.temperature_c:.1f} °C")
    else:
        lines.append(f"OK: keine Messung über {report.max_temp:.1f} °C")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="motorlog", description="Prüfstand-Messdaten auswerten")
    parser.add_argument("datei", help="CSV-Datei mit Messdaten")
    parser.add_argument("--max-temp", type=float, default=80.0, help="Grenztemperatur in °C (Standard: 80)")
    args = parser.parse_args(argv)

    try:
        report = build_report(load_measurements(args.datei), max_temp=args.max_temp)
    except (OSError, ValueError) as e:
        print(f"Fehler: {e}", file=sys.stderr)
        return 1

    print(format_report(args.datei, report))
    return 2 if report.overheated else 0


if __name__ == "__main__":
    raise SystemExit(main())
