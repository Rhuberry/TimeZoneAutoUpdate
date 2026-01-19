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

# ---- Task components (modern) ----

# --- Principal / Action / Settings (modern) ---
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Keep this permissive to avoid “why didn’t it run?” situations
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# --- Triggers (safe XML) ---

# Hourly forever pattern: Daily at 00:00, repeat every 1 hour for 1 day
# This effectively runs every hour indefinitely.
$triggerHourly = New-ScheduledTaskTrigger -Daily -At "00:00"
$triggerHourly.Repetition.Interval = "PT1H"
$triggerHourly.Repetition.Duration = "P1D"

# Logon trigger with 2-minute delay
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerLogon.Delay = "PT2M"

# --- Register tasks (modern Windows 10+ compatibility) ---
$taskDefHourly = New-ScheduledTask -Action $action -Trigger $triggerHourly -Principal $principal -Settings $settings
$taskDefLogon  = New-ScheduledTask -Action $action -Trigger $triggerLogon  -Principal $principal -Settings $settings

Register-ScheduledTask -TaskName $taskHourly -InputObject $taskDefHourly -Force | Out-Null
Register-ScheduledTask -TaskName $taskLogon  -InputObject $taskDefLogon  -Force | Out-Null

# Optional: kick the hourly task once immediately so you don’t wait for the next interval
try { Start-ScheduledTask -TaskName $taskHourly | Out-Null } catch {}

# --- Detection key (Win32 app) ---
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
