#!/usr/bin/env bash
# Allowlist-Firewall: ausgehend ist nur erlaubt, was unten steht. Alles andere wird abgewiesen.
set -euo pipefail

ALLOWED_DOMAINS=(
  # Claude Code: API und Login
  api.anthropic.com
  claude.ai
  console.anthropic.com
  platform.claude.com
  # Python-Pakete
  pypi.org
  files.pythonhosted.org
  # VS Code Extensions im Container
  marketplace.visualstudio.com
  vscode.blob.core.windows.net
  update.code.visualstudio.com
)

echo "[firewall] Regeln zurücksetzen"
iptables -F
iptables -X
ipset destroy allowed-domains 2>/dev/null || true

# DNS und localhost
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT  -p tcp --sport 53 -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

echo "[firewall] Erlaubte Domains auflösen"
ipset create allowed-domains hash:net
for domain in "${ALLOWED_DOMAINS[@]}"; do
  ips=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)
  if [ -z "$ips" ]; then
    echo "[firewall] WARNUNG: $domain nicht auflösbar"
    continue
  fi
  for ip in $ips; do
    ipset add allowed-domains "$ip" -exist
  done
  echo "[firewall]   $domain"
done

# Docker-Host-Netz (Kommunikation mit VS Code / Port-Forwarding)
HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
if [ -n "$HOST_IP" ]; then
  HOST_NET="${HOST_IP%.*}.0/24"
  iptables -A INPUT  -s "$HOST_NET" -j ACCEPT
  iptables -A OUTPUT -d "$HOST_NET" -j ACCEPT
fi

# Standard: alles verbieten
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6 komplett sperren (falls aktiv)
ip6tables -P INPUT DROP   2>/dev/null || true
ip6tables -P OUTPUT DROP  2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true

echo "[firewall] Prüfen"
if curl -s -o /dev/null --connect-timeout 5 https://example.com; then
  echo "[firewall] FEHLER: example.com ist erreichbar – Firewall greift nicht!"
  exit 1
fi
echo "[firewall] OK: example.com blockiert"
if curl -s -o /dev/null --connect-timeout 5 https://api.anthropic.com; then
  echo "[firewall] OK: api.anthropic.com erreichbar"
else
  echo "[firewall] WARNUNG: api.anthropic.com nicht erreichbar (Proxy? siehe README)"
fi
