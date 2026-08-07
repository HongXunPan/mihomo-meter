@echo off
setlocal
set "MIHOMO_METER_W0_CONSOLE=1"
start "" /wait "%~dp0MihomoMeter.Windows.App.exe"
exit /b %ERRORLEVEL%
