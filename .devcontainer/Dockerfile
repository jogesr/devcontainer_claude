FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# Fehler in Pipes (z.B. "curl | bash") sollen den Build abbrechen
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# TLS-inspizierender Firmen-Proxy -> dessen öffentlichem Root-Zertifikat vertrauen.
# Leer lassen, wenn kein Proxy: certs/ enthält dann keine *.crt.
COPY certs/ /usr/local/share/ca-certificates/firmen/
RUN update-ca-certificates
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Werkzeuge für die Netzwerk-Firewall
# (Yarn-Paketquelle des Basis-Images hat einen ungültigen Schlüssel und wird nicht gebraucht)
RUN rm -f /etc/apt/sources.list.d/yarn.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends iptables ipset dnsutils iproute2 curl \
 && rm -rf /var/lib/apt/lists/*

# Skripte gehören root -> der Agent kann sie nicht verändern.
# sed entfernt Windows-Zeilenenden, falls die Dateien mit CRLF ausgecheckt wurden.
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY isolation-check.sh /usr/local/bin/isolation-check
RUN sed -i 's/\r$//' /usr/local/bin/init-firewall.sh /usr/local/bin/isolation-check \
 && chmod 755 /usr/local/bin/init-firewall.sh /usr/local/bin/isolation-check \
 # Das Basis-Image gibt "vscode" volles sudo ohne Passwort -> entfernen.
 # Erlaubt bleibt nur das Firewall-Skript.
 && rm -f /etc/sudoers.d/vscode \
 && echo "vscode ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/vscode-firewall \
 && chmod 0440 /etc/sudoers.d/vscode-firewall

USER vscode
# Verzeichnis vorab anlegen, damit das Docker-Volume dem User "vscode" gehört
RUN mkdir -p /home/vscode/.claude \
 && curl -fsSL https://claude.ai/install.sh | bash \
 && /home/vscode/.local/bin/claude --version
ENV PATH="/home/vscode/.local/bin:${PATH}"
