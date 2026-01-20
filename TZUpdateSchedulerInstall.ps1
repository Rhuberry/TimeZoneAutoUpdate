$ErrorActionPreference = "Stop"

# -----------------------------
# Config
# -----------------------------
$taskName = "Time Zone Update"
$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# -----------------------------
# Helper script (runs via task)
# -----------------------------
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

@"
`$ErrorActionPreference = "SilentlyContinue"

`$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\TimeZoneTaskScheduler-run.log"

try { New-Item -Path (Split-Path `$logPath) -ItemType Directory -Force | Out-Null } catch {}

function Write-Log([string]`$msg) {
    "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] `$msg" | Out-File -FilePath `$logPath -Append -Encoding utf8
}

try {
    `$tzBefore = (Get-TimeZone).Id
    Write-Log "Task started | TimeZone (before): `$tzBefore"

    sc.exe config tzautoupdate start= demand | Out-Null
    Write-Log "Set tzautoupdate start=demand | exit=`$LASTEXITCODE"

    sc.exe config lfsvc start= auto | Out-Null
    Write-Log "Set lfsvc start=auto | exit=`$LASTEXITCODE"

    sc.exe start lfsvc | Out-Null
    Write-Log "Start lfsvc | exit=`$LASTEXITCODE"

    Start-Sleep -Seconds 1

    sc.exe start tzautoupdate | Out-Null
    Write-Log "Start tzautoupdate | exit=`$LASTEXITCODE"

    `$tzAfter = (Get-TimeZone).Id
    Write-Log "Task finished | TimeZone (after): `$tzAfter"
} catch {
    Write-Log "ERROR: `$(`$_.Exception.Message)"
}

exit 0
"@ | Set-Content -Path $scriptPath -Encoding UTF8 -Force


# -----------------------------
# Scheduled Task via COM
# -----------------------------
$taskRunArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

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

$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
$root = $service.GetFolder("\")

# Idempotent cleanup
try { $root.DeleteTask($taskName, 0) } catch {}

$task = $service.NewTask(0)

# Metadata
$task.RegistrationInfo.Description = "Ensures tzautoupdate/lfsvc run to keep time zone accurate."

# Principal (SYSTEM, highest)
$task.Principal.UserId = "SYSTEM"
$task.Principal.LogonType = 5
$task.Principal.RunLevel = 1

# Settings
$task.Settings.Enabled = $true
$task.Settings.Hidden = $false
$task.Settings.StartWhenAvailable = $true
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false
$task.Settings.MultipleInstances = 0
$task.Settings.ExecutionTimeLimit = "PT2M"

# Action
$action = $task.Actions.Create(0)
$action.Path = "powershell.exe"
$action.Arguments = $taskRunArgs

# -----------------------------
# Triggers
# -----------------------------
$triggers = $task.Triggers

# At startup
$boot = $triggers.Create(8)
$boot.Enabled = $true

# At logon
$logon = $triggers.Create(9)
$logon.Enabled = $true

# Hourly repetition
$time = $triggers.Create(1)
$time.Enabled = $true
$time.StartBoundary = (Get-Date).AddMinutes(5).ToString("s")
$time.Repetition.Interval = "PT1H"
$time.Repetition.Duration = "P3650D"
$time.Repetition.StopAtDurationEnd = $false

# Event trigger (4624 interactive/RDP)
$evt = $triggers.Create(0)
$evt.Enabled = $true
$evt.Subscription = $eventQuery

# -----------------------------
# Register task
# -----------------------------
$null = $root.RegisterTaskDefinition(
    $taskName,
    $task,
    6,
    "SYSTEM",
    $null,
    5
)

# Verify it exists (important: don't set detection key if register failed silently)
try {
    $null = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
} catch {
    exit 1
}

# Optional: run once immediately (more reliable than COM Run)
try {
    schtasks /Run /TN "$taskName" | Out-Null
} catch {
    # optional: don't fail install just because immediate run failed
}

# -----------------------------
# Win32 detection key
# -----------------------------
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Version" -PropertyType DWord -Value 2 -Force | Out-Null

exit 0
