$ErrorActionPreference = "Stop"

$baseTaskName = "Marco - Trigger TZ Auto Update"
$taskHourly   = "$baseTaskName (Hourly)"
$taskLogon    = "$baseTaskName (Logon)"

$regPath  = "HKLM:\SOFTWARE\TimeZoneTaskScheduler"

$scriptDir  = "C:\ProgramData\TimeZoneTaskScheduler"
$scriptPath = Join-Path $scriptDir "Run-TZAutoUpdate.ps1"

# Ensure folder exists
New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null

# Write the script both tasks will run
@'
# Suppress errors
$ErrorActionPreference = "SilentlyContinue"

$tzReg = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"

# --- Mimic Settings toggle OFF ---
try { Set-ItemProperty -Path $tzReg -Name Start -Value 4 -Force } catch {}
try { Stop-Service tzautoupdate -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Seconds 2

# --- Mimic Settings toggle ON ---
try { Set-ItemProperty -Path $tzReg -Name Start -Value 3 -Force } catch {}

# Restart pipeline
try { Restart-Service lfsvc -ErrorAction SilentlyContinue } catch {}
try { Start-Service tzautoupdate -ErrorAction SilentlyContinue } catch {}

# Run Windows TZ sync
try {
    Start-Process -FilePath "$env:windir\system32\tzsync.exe" -WindowStyle Hidden -Wait
} catch {}

exit 0
'@ | Set-Content -Path $scriptPath -Encoding UTF8 -Force

# Create/replace Hourly task (SYSTEM)
schtasks /Create /F `
  /TN "$taskHourly" `
  /SC HOURLY `
  /MO 1 `
  /RU "SYSTEM" `
  /RL HIGHEST `
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"" | Out-Null

# Create/replace Logon task (SYSTEM)
schtasks /Create /F `
  /TN "$taskLogon" `
  /SC ONLOGON `
  /RU "SYSTEM" `
  /RL HIGHEST `
  /TR "powershell.exe -NoProfile -WindowStyle Hidden -File `"$scriptPath`"" | Out-Null

# Detection key
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "Installed" -PropertyType DWord -Value 1 -Force | Out-Null

exit 0
