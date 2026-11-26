#!/usr/bin/env bash
# Zeigt live, was ein Agent in diesem Container sieht – und was nicht.
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
title() { printf '\n\033[1m%s\033[0m\n' "$*"; }

title "1) Wer bin ich?"
echo "  Benutzer: $(whoami)   Rechner: $(hostname)"

title "2) Vom Host durchgereichte Ordner"
grep -E ' /(workspace|data) ' /proc/mounts | awk '{ split($4,o,","); printf "  %-11s %s\n", $2, (o[1]=="ro" ? "nur lesen" : "lesen + schreiben") }'

title "3) Sind Host-Dateien sichtbar?"
for p in /mnt/c /c /Users "$HOME/.ssh" /workspace/.devcontainer; do
  if [ -e "$p" ]; then bad "$p ist sichtbar"; else ok "$p nicht vorhanden"; fi
done
found=$(find / \( -path /proc -o -path /sys \) -prune -o -iname 'geheim-demo*' -print 2>/dev/null | head -n 1)
if [ -z "$found" ]; then ok "geheim-demo.txt vom Host-Desktop nicht auffindbar"; else bad "gefunden: $found"; fi

title "4) Schreibschutz der Eingabedaten"
if touch /data/.schreibtest 2>/dev/null; then rm -f /data/.schreibtest; bad "/data ist beschreibbar"
else ok "/data ist schreibgeschützt"; fi

title "5) Rechte und Zugangsdaten"
if sudo -n true 2>/dev/null; then bad "volle sudo-Rechte"; else ok "keine sudo-Rechte (nur Firewall-Skript)"; fi
if [ -n "${SSH_AUTH_SOCK:-}" ]; then bad "SSH-Agent vom Host durchgereicht"; else ok "kein SSH-Agent vom Host"; fi
if git config --global --get credential.helper >/dev/null 2>&1; then
  warn "VS Code reicht Git-Zugangsdaten durch (siehe README > Grenzen)"
else
  ok "keine Git-Zugangsdaten vom Host"
fi

title "6) Netzwerk (Allowlist)"
reach() { curl -s -o /dev/null --connect-timeout 5 "$1"; }
if reach https://example.com; then bad "example.com erreichbar"; else ok "example.com blockiert"; fi
if reach https://github.com;  then bad "github.com erreichbar";  else ok "github.com blockiert"; fi
if reach https://api.anthropic.com; then ok "api.anthropic.com erreichbar (für Claude nötig)"
else bad "api.anthropic.com nicht erreichbar"; fi
echo
