$ErrorActionPreference = "SilentlyContinue"

$taskName = "Time Zone Update"

$scriptDir = "C:\ProgramData\TimeZoneTaskScheduler"
$regPath   = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

# --- Remove scheduled task (COM) ---
try {
    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()
    $root = $service.GetFolder("\")
    $root.DeleteTask($taskName, 0) | Out-Null
} catch {}

# --- Remove script folder ---
try {
    if (Test-Path $scriptDir) {
        Remove-Item $scriptDir -Recurse -Force | Out-Null
    }
} catch {}

# --- Remove detection key ---
try {
    if (Test-Path $regPath) {
        Remove-Item $regPath -Recurse -Force | Out-Null
    }
} catch {}

exit 0
