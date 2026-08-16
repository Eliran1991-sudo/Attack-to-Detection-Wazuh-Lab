$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isHighIntegrity = [bool](whoami /groups | Select-String 'S-1-16-12288')

@(
    "USER=$(whoami)"
    "ADMIN_GROUP=$isAdministrator"
    "HIGH_INTEGRITY=$isHighIntegrity"
    "OS=$((Get-CimInstance Win32_OperatingSystem).Caption)"
) | Set-Content -LiteralPath 'C:\Users\Public\lab-access-check.txt'
