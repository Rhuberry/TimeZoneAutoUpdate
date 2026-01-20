$ErrorActionPreference = "Stop"

# -----------------------------
# Config
# -----------------------------
$taskName = "Time Zone Update"
$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# -----------------------------
# Helper script (the actual fix) - NO DELAY
# -----------------------------
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

@'
$ErrorActionPreference = "SilentlyContinue"

sc.exe config tzautoupdate start= demand | Out-Null

sc.exe config lfsvc start= auto | Out-Null
sc.exe start lfsvc | Out-Null

Start-Sleep -Seconds 1

sc.exe start tzautoupdate | Out-Null

exit 0
'@ | Set-Content -Path $scriptPath -Encoding UTF8 -Force

# Task action
$taskRunArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# 4624 event trigger query (interactive console 2 or RDP 10)
$eventQuery = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">
      *[System[(EventID=4624)]]
      and
      *[EventData[Data[@Name='LogonType']='2' or Data[@Name='LogonType']='10']]
    </Select>
  </Query>
</QueryList>
"@

# -----------------------------
# Create/replace ONE task with multiple triggers using COM
# -----------------------------
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

$root = $service.GetFolder("\")

# Delete existing task if present (idempotent)
try { $root.DeleteTask($taskName, 0) } catch {}

$task = $service.NewTask(0)

# ---- Registration info (optional) ----
$task.RegistrationInfo.Description = "Ensures tzautoupdate/lfsvc are started to keep time zone updating correctly."

# ---- Principal (SYSTEM, highest) ----
# TASK_LOGON_SERVICE_ACCOUNT = 5
$task.Principal.UserId = "SYSTEM"
$task.Principal.LogonType = 5
# TASK_RUNLEVEL_HIGHEST = 1
$task.Principal.RunLevel = 1

# ---- Settings ----
$task.Settings.Enabled = $true
$task.Settings.Hidden  = $false
$task.Settings.StartWhenAvailable = $true

# Battery behavior
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries     = $false

# Don’t pile up instances
# TASK_INSTANCES_IGNORE_NEW = 2
$task.Settings.MultipleInstances = 2

# Execution time limit (PT2M)
$task.Settings.ExecutionTimeLimit = "PT2M"

# ---- Action: powershell.exe ... ----
# TASK_ACTION_EXEC = 0
$action = $task.Actions.Create(0)
$action.Path = "powershell.exe"
$action.Arguments = $taskRunArgs

# -----------------------------
# Triggers
# -----------------------------
$triggers = $task.Triggers

# 1) At Startup
# TASK_TRIGGER_BOOT = 8
$boot = $triggers.Create(8)
$boot.Enabled = $true

# 2) At Logon (any user)
# TASK_TRIGGER_LOGON = 9
$logon = $triggers.Create(9)
$logon.Enabled = $true

# 3) Hourly repetition (Time trigger + repetition)
# TASK_TRIGGER_TIME = 1
$time = $triggers.Create(1)
$time.Enabled = $true
$time.StartBoundary = (Get-Date).AddMinutes(5).ToString("s")
$time.Repetition.Interval = "PT1H"
$time.Repetition.Duration = "P3650D"
$time.Repetition.StopAtDurationEnd = $false

# 4) Event trigger (Security 4624 interactive/RDP)
# TASK_TRIGGER_EVENT = 0
$evt = $triggers.Create(0)
$evt.Enabled = $true
$evt.Subscription = $eventQuery

# -----------------------------
# Register the task
# -----------------------------
# TASK_CREATE_OR_UPDATE = 6
# TASK_LOGON_SERVICE_ACCOUNT = 5
$null = $root.RegisterTaskDefinition(
    $taskName,
    $task,
    6,
    "SYSTEM",
    $null,
    5
)

# Optional: run once now
try {
    $root.GetTask($taskName).Run($null) | Out-Null
} catch {}

# -----------------------------
# Win32 detection key
# -----------------------------
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
