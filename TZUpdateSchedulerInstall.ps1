$ErrorActionPreference = "Stop"

$baseTaskName = "Marco - Trigger TZ Auto Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"

$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Write the script both tasks will run
@'
# Suppresses errors
$ErrorActionPreference = "SilentlyContinue"

# Points at the tzautoupdate service registry key
$tzReg = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"

# Ensure auto TZ is enabled
try { Set-ItemProperty -Path $tzReg -Name Start -Value 3 -Force } catch {}

# Start required services if not running
try {
    $lf = Get-Service lfsvc -ErrorAction SilentlyContinue
    if ($lf -and $lf.Status -ne "Running") { Start-Service lfsvc -ErrorAction SilentlyContinue }
} catch {}

try {
    $tz = Get-Service tzautoupdate -ErrorAction SilentlyContinue
    if ($tz -and $tz.Status -ne "Running") { Start-Service tzautoupdate -ErrorAction SilentlyContinue }
} catch {}

# Runs Windows’ built-in time zone sync executable
try { & "$env:windir\system32\tzsync.exe" | Out-Null } catch {}

exit 0
'@ | Set-Content -Path $scriptPath -Encoding UTF8 -Force


# Create/replace Hourly task (SYSTEM)
schtasks /Create /F `
  /TN "$taskHourly" `
  /SC HOURLY `
  /MO 1 `
  /RU "SYSTEM" `
  /RL HIGHEST `
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"" | Out-Null

# Create/replace Logon task (SYSTEM)
schtasks /Create /F `
  /TN "$taskLogon" `
  /SC ONLOGON `
  /RU "SYSTEM" `
  /RL HIGHEST `
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"" | Out-Null

# Detection key
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
