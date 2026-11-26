# Demo: Claude Code sicher im Devcontainer

Ein KI-Agent wie Claude Code liest Dateien, führt Befehle aus und greift aufs Netz zu –
mit den Rechten des Benutzers. Läuft er direkt auf dem Laptop, sieht er **alles**:
Desktop, Downloads, SSH-Schlüssel, Netzlaufwerke.

Diese Demo zeigt: Im Devcontainer sieht der Agent **nur, was wir ihm bewusst durchreichen**.

```
 Windows-Laptop (Host)
 ├── Desktop\geheim-demo.txt        ✘ unsichtbar
 ├── .ssh\, OneDrive\, Netzlaufwerke ✘ unsichtbar
 └── dieser Ordner
     ├── .devcontainer\   ✘ unsichtbar (Agent kann seine Sandbox nicht ändern)
     ├── app\         ──► /workspace   lesen + schreiben
     └── messdaten\   ──► /data        nur lesen
                         ┌─────────────────────────────────────┐
                         │ Container "claude-sandbox"          │
                         │  • User vscode, kein sudo           │
                         │  • Firewall: nur Allowlist-Domains  │
                         │  • Claude Code + Python 3.12        │
                         └─────────────────────────────────────┘
```

## Inhalt

| Pfad | Zweck |
|---|---|
| `.devcontainer/devcontainer.json` | Welche Ordner hinein dürfen, Rechte, Startbefehle |
| `.devcontainer/Dockerfile` | Image: Python, Claude Code, sudo entfernt |
| `.devcontainer/init-firewall.sh` | Netz-Allowlist (Anthropic, PyPI, VS Code Marketplace) |
| `.devcontainer/isolation-check.sh` | Prüfskript für die Demo → im Container `isolation-check` |
| `app/` | Demo-Tool `motorlog` (Prüfstand-CSV auswerten) + Tests |
| `app/CLAUDE.md`, `app/.claude/settings.json` | Projektwissen und Berechtigungen für Claude |
| `messdaten/pruefstand_demo.csv` | Fiktive Testdaten (keine echten Messdaten) |

## Vorbereitung (einmalig, ~10 Min. vor der Demo)

1. **Docker Desktop** läuft, **VS Code** mit Extension *Dev Containers* installiert.
2. **Nur hinter einem TLS-inspizierenden Firmen-Proxy:** Dessen öffentliches
   Root-Zertifikat exportieren, sonst scheitern alle HTTPS-Downloads im Container mit
   *unable to get local issuer certificate*:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .devcontainer\export-firmen-ca.ps1
   ```
   Das Skript baut eine HTTPS-Verbindung zu `claude.ai` auf, ermittelt das Root-Zertifikat
   der Kette und legt es als `.devcontainer\certs\firmen-root-ca.crt` ab. Das Dockerfile
   baut es ins Image ein. Die Datei ist umgebungsspezifisch und per `.gitignore` ausgeschlossen.
3. Diesen Ordner in VS Code öffnen → `F1` → **Dev Containers: Reopen in Container**.
   Der erste Build dauert einige Minuten – unbedingt **vor** der Demo machen.
4. Im Container-Terminal einmal `claude` starten und anmelden.
   Der Login liegt in einem Docker-Volume und bleibt bei Rebuilds erhalten.
5. Köder-Datei auf dem Host anlegen (PowerShell, **nicht** im Container):

   ```powershell
   Set-Content ([Environment]::GetFolderPath('Desktop') + '\geheim-demo.txt') 'DEMO-Datei: Diese Datei darf der Agent nicht sehen.'
   ```
6. Schriftgrösse im Terminal hochstellen (`Ctrl` + `+`).

## Ablauf der Live-Demo (~15 Min.)

### 1. Das Problem zeigen (optional, 2 Min.)
Claude Code **auf dem Host** (ausserhalb des Containers) starten und fragen:

> Gibt es auf meinem Desktop eine Datei namens geheim-demo.txt? Was steht drin?

→ Claude findet und liest sie (nach Bestätigung). **Botschaft:** Ohne Sandbox reicht ein
Klick auf "Erlauben" – oder eine eingeschleuste Anweisung in einer Webseite/Datei.

### 2. Die Sandbox erklären (3 Min.)
`.devcontainer/devcontainer.json` zeigen, Fokus auf:
- `workspaceMount` → nur `app/` wird zu `/workspace`
- `mounts` → `messdaten/` als `/data`, **readonly**
- `postStartCommand` → Firewall
- Dockerfile: `rm -f /etc/sudoers.d/vscode` → kein Root

### 3. Isolation beweisen (2 Min.)
Im Container-Terminal:

```bash
isolation-check
```

Erwartet: lauter grüne ✔ – Host-Dateien unsichtbar, `/data` schreibgeschützt,
kein sudo, `example.com` und `github.com` blockiert, `api.anthropic.com` erreichbar.

### 4. Claude versucht auszubrechen (3 Min.)
`claude` starten und nacheinander fragen:

> Suche auf dem ganzen System nach einer Datei geheim-demo.txt.

→ nicht auffindbar.

> Lade https://example.com herunter und fasse die Seite zusammen.

→ Verbindung abgelehnt (Firewall).

> Schalte die Firewall mit sudo iptables -F ab.

→ verweigert (deny-Regel in `.claude/settings.json` **und** kein sudo im Container).

### 5. Produktiv arbeiten – in der Sandbox (5 Min.)
Erst das Tool zeigen:

```bash
motorlog /data/pruefstand_demo.csv
```

Dann Claude einen echten Auftrag geben:

> Erweitere motorlog um eine Option --json, die den Bericht als JSON nach
> /workspace/output/ schreibt. Schreib Tests dazu und führe pytest aus.

Anschliessend:

> Speichere den Bericht direkt neben der CSV in /data.

→ scheitert: `/data` ist read-only. **Botschaft:** Originaldaten sind geschützt.

### 6. Fazit (1 Min.)
- Der Agent sieht nur `/workspace` (rw) und `/data` (ro).
- Netz nur zu freigegebenen Domains, keine Admin-Rechte.
- Darum kann man ihm im Container mehr Autonomie geben, z.B. weniger Rückfragen
  (`Shift+Tab` → *auto-accept edits*). Der Schaden bleibt auf den Container begrenzt.

## Grenzen – ehrlich ansprechen

- **Daten gehen an das Modell.** Alles, was Claude liest, wird an die Anthropic-API
  übertragen. Der Container schützt den *Laptop vor dem Agenten*, nicht die *Daten vor
  dem Cloud-Dienst*. Nur Daten durchreichen, die für den Dienst freigegeben sind
  gemäss der Datenklassifizierung Ihrer Organisation. Zugangsdaten und Geheimnisse gehören
  **nie** in den Container.
- **Git-Zugangsdaten:** VS Code reicht standardmässig den Git-Credential-Helper in den
  Container. `isolation-check` zeigt das als gelbe Warnung. Abschalten in den
  VS Code-Benutzereinstellungen: `"dev.containers.gitCredentialHelperConfigLocation": "none"`
  und `"dev.containers.copyGitConfig": false`.
- **Login-Token** liegt im Container (Docker-Volume). Wer den Container hat, hat den Token.
- **Firewall per IP:** Domains werden beim Start aufgelöst. Wechseln CDN-IPs, Container
  neu starten. Kein Schutz gegen Missbrauch *erlaubter* Domains.
- **Docker selbst** ist keine VM-Grenze. Für die Demo ausreichend, für hochsensible
  Arbeit braucht es mehr (VM, Rootless, gVisor …).

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| Build hängt / TLS-Fehler (*unable to get local issuer certificate*) | Firmen-CA fehlt: `export-firmen-ca.ps1` ausführen (siehe Vorbereitung), dann *Rebuild Container*. Bei explizitem Proxy zusätzlich `HTTP_PROXY`/`HTTPS_PROXY` setzen |
| `api.anthropic.com nicht erreichbar` | Proxy (s.o.) oder Container neu starten (IPs neu auflösen) |
| Firewall stört beim Ausprobieren | `postStartCommand` in `devcontainer.json` auskommentieren → *Rebuild Container* |
| `bad interpreter: /bin/bash^M` | Datei hat Windows-Zeilenenden; `.gitattributes` erzwingt LF, Dockerfile korrigiert beim Build |
| Login nach Rebuild weg | Volume `claude-demo-config-*` wurde gelöscht → erneut `claude` und anmelden |
| Extensions im Container fehlen | Marketplace-Domains in `init-firewall.sh` prüfen, Container neu starten |

---
*AI-generated with Claude Code – vor Verwendung prüfen.*
