$ErrorActionPreference = "Stop"

$baseTaskName = "Time Zone Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskSignIn   = "$baseTaskName (SignIn Event)"

$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Helper script (the actual fix)
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

# ---- Create/replace tasks (SYSTEM) ----

# Hourly backstop (every 1 hour)
& schtasks.exe /Create /F /TN $taskHourly /SC HOURLY /MO 1 /RU "SYSTEM" /RL HIGHEST /TR $taskRun | Out-Null

# Sign-in event trigger (4624 interactive) - immediate
& schtasks.exe /Create /F /TN $taskSignIn /SC ONEVENT /EC Security /MO $filter4624Interactive /RU "SYSTEM" /RL HIGHEST /TR $taskRun | Out-Null

# Optional: kick once now
try { & schtasks.exe /Run /TN $taskHourly | Out-Null } catch {}

# Detection key (Win32 app)
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
