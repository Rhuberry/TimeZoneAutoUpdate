$ErrorActionPreference = "Stop"

$baseTaskName = "Time Zone Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"

$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Write the script both tasks will run
@'
$ErrorActionPreference = "SilentlyContinue"

# Force startup type to Manual (normal default)
sc.exe config tzautoupdate start= demand | Out-Null

# Make sure Location Framework Service is running
sc.exe config lfsvc start= auto | Out-Null
sc.exe start lfsvc | Out-Null

Start-Sleep -Seconds 1

# Try starting tzautoupdate again
sc.exe start tzautoupdate | Out-Null

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
  /DELAY 0000:02 `
  /RU "SYSTEM" `
  /RL HIGHEST `
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"" | Out-Null

# Detection key
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
