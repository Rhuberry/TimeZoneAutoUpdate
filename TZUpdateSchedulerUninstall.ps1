$ErrorActionPreference = "SilentlyContinue"

$taskName  = "Time Zone Update"
$scriptDir = "C:\ProgramData\TimeZoneTaskScheduler"
$regPath   = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"
$logFile   = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\TimeZoneTaskScheduler-run.log"

# -----------------------------
# Remove scheduled task
# -----------------------------
try { schtasks /Delete /TN "$taskName" /F | Out-Null } catch {}

# -----------------------------
# Remove script directory
# -----------------------------
try { if (Test-Path $scriptDir) { Remove-Item $scriptDir -Recurse -Force | Out-Null } } catch {}

# -----------------------------
# Remove log
# -----------------------------
try { if (Test-Path $logFile) { Remove-Item $logFile -Force | Out-Null } } catch {}

# -----------------------------
# Remove detection key
# -----------------------------
try { if (Test-Path $regPath) { Remove-Item $regPath -Recurse -Force | Out-Null } } catch {}

exit 0
