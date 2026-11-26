# motorlog

Kleines Python-CLI, das Prüfstand-Messdaten (CSV) auswertet: Min/Max/Mittel für
Drehzahl, Strom und Temperatur sowie Warnungen bei Übertemperatur.

- Code: `motorlog/analysis.py` (Logik), `motorlog/cli.py` (Ausgabe, Argumente)
- Tests: `pytest` (in `tests/`), vor jedem Abschluss ausführen
- Messdaten liegen read-only unter `/data` – dort nichts schreiben.
- Ergebnisse/Exporte nach `/workspace/output/` schreiben.
- Ausgaben und Meldungen auf Deutsch (Schweizer Schreibweise, "ss" statt "ß").
- Exit-Codes: 0 = ok, 1 = Fehler, 2 = Übertemperatur gefunden.
