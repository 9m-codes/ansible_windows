# bootstrap-winrm.ps1
# Purpose: Bootstrap clean Windows server for Ansible
# Sets: Static IP, hostname, WinRM (HTTP), service account
# Run as: Local Administrator
# Idempotent: Safe to re-run

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ========================================
# 🔧 CONFIGURATION (Edit these values)
# ========================================
$ServerIP       = "10.9.2.10"
$ServerNetMask  = "255.255.0.0"  # /16
$ServerGateway  = "10.9.9.1"
$ServerDNS      = "10.9.9.1"     # Can be array: "10.9.9.1", "10.9.9.2"
$NewHostname    = "ad-01"
$DomainName     = "i.jeeex.org"
$Username       = "ansible_svc_01"
$Password       = "TempPass123!"  # Will be rotated by Ansible later
# ========================================

$CurrentHostname = $env:COMPUTERNAME
$CurrentIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" -ErrorAction SilentlyContinue).IPAddress

#---------------------------------------------------
# 1. Set Static IP (if not already set)
#---------------------------------------------------
$Interface = Get-NetAdapter -InterfaceAlias "Ethernet*" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Up"}
if (-not $Interface) {
    Write-Warning "No active Ethernet adapter found."
    exit 1
}

if ($CurrentIP -ne $ServerIP) {
    Write-Host "Setting IP address to $ServerIP..." -ForegroundColor Cyan
    New-NetIPAddress -InterfaceIndex $Interface.InterfaceIndex `
                     -IPAddress $ServerIP `
                     -PrefixLength ($ServerNetMask -split '\.' | ForEach-Object { [Convert]::ToString([byte]($_), 2) } | ForEach-Object { ($_ -replace '0', '').Length } | Measure-Object -Sum).Sum `
                     -DefaultGateway $ServerGateway `
                     -ErrorAction SilentlyContinue `
                     -Confirm:$false

    Set-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -ServerAddresses $ServerDNS
    Write-Host "IP configured: $ServerIP" -ForegroundColor Green
} else {
    Write-Host "IP $ServerIP already set." -ForegroundColor Green
}

#---------------------------------------------------
# 2. Change hostname if needed
#---------------------------------------------------
if ($CurrentHostname -ne $NewHostname) {
    Write-Host "Changing hostname from $CurrentHostname to $NewHostname..." -ForegroundColor Cyan
    Rename-Computer -NewName $NewHostname -Force
}

#---------------------------------------------------
# 3. Enable WinRM (HTTP) for Ansible bootstrap
#---------------------------------------------------
Write-Host "Enabling WinRM over HTTP (temporary)..." -ForegroundColor Cyan
Enable-PSRemoting -Force -SkipNetworkProfileCheck
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'

#---------------------------------------------------
# 4. Create Ansible service account
#---------------------------------------------------
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

try {
    $User = Get-LocalUser -Name $Username -ErrorAction Stop
    Write-Host "User '$Username' already exists." -ForegroundColor Yellow
} catch {
    New-LocalUser -Name $Username -Password $SecurePassword -FullName "Ansible Service Account" -Description "Managed by Ansible" -PasswordNeverExpires -UserMayNotChangePassword -AccountNeverExpires
    Write-Host "User '$Username' created." -ForegroundColor Green
}

# Add to required groups
Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue
Add-LocalGroupMember -Group "Remote Management Users" -Member $Username -ErrorAction SilentlyContinue

#---------------------------------------------------
# 5. Firewall: Allow WinRM HTTP
#---------------------------------------------------
$RuleName = "WinRM HTTP"
if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
    Write-Host "Firewall: Opened port 5985" -ForegroundColor Green
}

#---------------------------------------------------
# 6. Ensure WinRM service is running
#---------------------------------------------------
$Service = Get-Service WinRM
if ($Service.StartType -ne "Automatic") { Set-Service WinRM -StartupType Automatic }
if ($Service.Status -ne "Running") { Start-Service WinRM }

#---------------------------------------------------
# 7. Final status
#---------------------------------------------------
Write-Host "`n✅ Bootstrap complete. Server will reboot." -ForegroundColor Green
Write-Host "👉 Ansible can now connect via HTTP on $ServerIP:5985" -ForegroundColor Cyan
Write-Host "   Hostname: $NewHostname.$DomainName" -ForegroundColor Cyan
Write-Host "   User: $Username" -ForegroundColor Cyan
Write-Host "   Password: $Password (temporary)" -ForegroundColor Yellow

Restart-Computer -Force