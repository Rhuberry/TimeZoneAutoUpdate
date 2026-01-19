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

# Run as SYSTEM, highest privileges
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Action (explicit bypass helps in managed environments)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Settings: remove common blockers, allow battery, retry on failure
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# Triggers
$triggerHourly = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)

$triggerLogon  = New-ScheduledTaskTrigger -AtLogOn
# Add a 2-minute delay to logon trigger (property exists even though the cmdlet doesn’t expose it)
$triggerLogon.Delay = "PT2M"   # ISO-8601 duration (PT2M = 2 minutes)

# Build task definitions
$taskDefHourly = New-ScheduledTask -Action $action -Trigger $triggerHourly -Principal $principal -Settings $settings
$taskDefLogon  = New-ScheduledTask -Action $action -Trigger $triggerLogon  -Principal $principal -Settings $settings

# Register / replace tasks
Register-ScheduledTask -TaskName $taskHourly -InputObject $taskDefHourly -Force | Out-Null
Register-ScheduledTask -TaskName $taskLogon  -InputObject $taskDefLogon  -Force | Out-Null

# Detection key (Win32 app)
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
