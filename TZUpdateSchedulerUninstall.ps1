$ErrorActionPreference = "SilentlyContinue"

$taskName  = "Time Zone Update"
$scriptDir = "C:\Program Files\TimeZoneTaskScheduler"
$regPath   = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"
$logFile   = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\TimeZoneTaskScheduler-run.log"

# -----------------------------
# Remove scheduled task
# -----------------------------
schtasks /Delete /TN "$taskName" /F 2>$null | Out-Null

# -----------------------------
# Remove script directory
# -----------------------------
Remove-Item $scriptDir -Recurse -Force -ErrorAction SilentlyContinue

# -----------------------------
# Remove log
# -----------------------------
Remove-Item $logFile -Force -ErrorAction SilentlyContinue

# -----------------------------
# Remove detection key
# -----------------------------
Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue

exit 0
