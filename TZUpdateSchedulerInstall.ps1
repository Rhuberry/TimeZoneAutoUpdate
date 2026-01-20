$ErrorActionPreference = "Stop"

$baseTaskName = "Time Zone Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"
$taskSignIn   = "$baseTaskName (SignIn Event)"

$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Scipt that actually works to restart time zone
@'
$ErrorActionPreference = "SilentlyContinue"

sc.exe config tzautoupdate start= demand | Out-Null

sc.exe config lfsvc start= auto | Out-Null
sc.exe start lfsvc | Out-Null

Start-Sleep -Seconds 1

sc.exe start tzautoupdate | Out-Null

exit 0
'@ | Set-Content -Path $scriptPath -Encoding UTF8 -Force

# Task run command (keep it short)
$taskRun = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Event filter: 4624 + interactive console (2) or RDP (10)
$filter4624Interactive = "*[System[EventID=4624]] and *[EventData[Data[@Name='LogonType']='2' or Data[@Name='LogonType']='10']]"

# ---- Create/replace ONE task (SYSTEM) ----
# Create the base task as ONEVENT (SignIn) first
& schtasks.exe /Create /F /TN $taskSignIn /SC ONEVENT /EC Security /MO "$filter4624Interactive" /RU "SYSTEM" /RL HIGHEST /TR $taskRun | Out-Null

# ---- Refetch and add more triggers to SAME task ----
try {
    $t = Get-ScheduledTask -TaskName $taskSignIn -ErrorAction Stop

    # Keep existing triggers (includes the ONEVENT trigger we just created)
    $triggers = @($t.Triggers)

    # Add ONLOGON trigger (2 minutes after logon)
    $trLogon = New-ScheduledTaskTrigger -AtLogOn -Delay (New-TimeSpan -Minutes 2)
    $triggers += $trLogon

    # Add "hourly" trigger by using a repeating trigger (runs every hour indefinitely-ish)
    # Note: repetition needs a base trigger; we use a "Once" trigger starting 5 minutes from now.
    $trHourly = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date).AddMinutes(5) `
        -RepetitionInterval (New-TimeSpan -Hours 1) `
        -RepetitionDuration (New-TimeSpan -Days 3650)
    $triggers += $trHourly

    # Apply triggers back onto the same task
    Set-ScheduledTask -TaskName $taskSignIn -Trigger $triggers | Out-Null

    # Apply your settings to the same task
    $t2 = Get-ScheduledTask -TaskName $taskSignIn -ErrorAction Stop
    $settings = $t2.Settings

    # Power conditions
    $settings.DisallowStartIfOnBatteries = $false
    $settings.StopIfGoingOnBatteries     = $false

    # Start when available when schedule is missed
    $settings.StartWhenAvailable = $true

    Set-ScheduledTask -TaskName $taskSignIn -Settings $settings | Out-Null

} catch {

} # swallow; your outer install should still succeed

# Optional: kick once now
try { & schtasks.exe /Run /TN $taskSignIn | Out-Null } catch {}

# Detection key (Win32 app)
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
