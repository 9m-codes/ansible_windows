# Enable WinRM service
Enable-PSRemoting -Force

# Configure WinRM for HTTPS (Production Recommended)
# Create self-signed certificate (replace with proper CA cert in production)
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# Configure WinRM settings for production
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Basic="true";Kerberos="true";Negotiate="true";Certificate="true"}'
winrm set winrm/config/service '@{MaxConcurrentOperationsPerUser="100"}'
winrm set winrm/config/service '@{MaxConnections="300"}'
winrm set winrm/config/service '@{MaxPacketRetrievalTimeSeconds="120"}'

# Set memory limits (adjust based on your needs)
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
winrm set winrm/config/winrs '@{MaxProcessesPerShell="100"}'
winrm set winrm/config/winrs '@{MaxShellsPerUser="30"}'

# Configure firewall
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow

# Restart WinRM service
Restart-Service WinRM

# Verify configuration
winrm enumerate winrm/config/listener