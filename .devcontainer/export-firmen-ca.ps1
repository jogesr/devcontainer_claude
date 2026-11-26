# Exportiert das öffentliche Root-Zertifikat, mit dem HTTPS-Verbindungen auf diesem
# Rechner signiert werden, nach .devcontainer\certs\. Hinter einem TLS-inspizierenden
# Firmen-Proxy ist das dessen Root-CA; der Container vertraut ihr dann ebenfalls.
# Exportiert wird nur das öffentliche Zertifikat, kein privater Schlüssel.
param([string]$TestHost = "claude.ai")

$tcp = [Net.Sockets.TcpClient]::new($TestHost, 443)
try {
    $ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false)
    $ssl.AuthenticateAsClient($TestHost)   # normale Prüfung gegen den Windows-Zertifikatspeicher
    $leaf = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
} finally {
    $tcp.Dispose()
}

$chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
$null = $chain.Build($leaf)
$root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate

$dir = Join-Path $PSScriptRoot "certs"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$pem = "-----BEGIN CERTIFICATE-----`n" +
       [Convert]::ToBase64String($root.RawData, 'InsertLineBreaks').Replace("`r`n", "`n") +
       "`n-----END CERTIFICATE-----`n"
$file = Join-Path $dir "firmen-root-ca.crt"
[IO.File]::WriteAllText($file, $pem)
Write-Host "Root-Zertifikat: $($root.Subject)"
Write-Host "Gültig bis:      $($root.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host "Gespeichert:     $file"
