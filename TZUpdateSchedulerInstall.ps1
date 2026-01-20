$ErrorActionPreference = "SilentlyContinue"

$taskName = "Time Zone Update"

$scriptDir = "C:\ProgramData\TimeZoneTaskScheduler"
$regPath   = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

# New log location (IME logs folder)
$imeLogDir  = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$imeLogFile = Join-Path $imeLogDir "TimeZoneTaskScheduler-run.log"

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

# --- Remove custom log file from IME logs folder ---
try {
    if (Test-Path $imeLogFile) {
        Remove-Item $imeLogFile -Force | Out-Null
    }
} catch {}

# Optional: remove any rotated variants if you ever add them later
# try {
#     Get-ChildItem -Path $imeLogDir -Filter "TimeZoneTaskScheduler-run*.log" -ErrorAction SilentlyContinue |
#         Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
# } catch {}

# --- Remove detection key ---
try {
    if (Test-Path $regPath) {
        Remove-Item $regPath -Recurse -Force | Out-Null
    }
} catch {}

exit 0
