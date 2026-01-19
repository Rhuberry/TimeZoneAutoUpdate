$ErrorActionPreference = "Stop"

$baseTaskName = "Marco - Trigger TZ Auto Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"

$regPath  = "HKLM:\SOFTWARE\Marco\TZAutoUpdateTrigger"

$scriptDir  = "C:\ProgramData\Marco\TZAutoUpdateSchedule"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Write the script both tasks will run
@'
$ErrorActionPreference = "SilentlyContinue"

try {
    $tz = Get-Service tzautoupdate -ErrorAction Stop
    if ($tz.Status -ne "Running") {
        Start-Service tzautoupdate -ErrorAction SilentlyContinue
    }
} catch {}

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
