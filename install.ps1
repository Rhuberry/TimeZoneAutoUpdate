Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 3 -Force

Start-Service -Name tzautoupdate -ErrorAction SilentlyContinue
