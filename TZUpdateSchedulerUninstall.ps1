$ErrorActionPreference = "SilentlyContinue"

$baseTaskName = "Time Zone Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"
$taskSignIn   = "$baseTaskName (SignIn Event)"

$scriptDir = "C:\ProgramData\TimeZoneTaskScheduler"
$regPath   = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

# Remove scheduled tasks
schtasks /Delete /TN "$taskHourly" /F | Out-Null
schtasks /Delete /TN "$taskLogon"  /F | Out-Null
schtasks /Delete /TN "$taskSignIn" /F | Out-Null

# Remove script folder
if (Test-Path $scriptDir) {
    Remove-Item $scriptDir -Recurse -Force | Out-Null
}

# Remove detection key
if (Test-Path $regPath) {
    Remove-Item $regPath -Recurse -Force | Out-Null
}

exit 0
