@echo off

for /f "tokens=1,2 delims==" %%a in (deploy.conf.sample) do (
set %%a=%%b
)

for /f "tokens=1,2 delims==" %%a in (deploy.conf) do (
set %%a=%%b
)

set ADDON_PATH=%WOW_ADDONS_PATH%\%ADDON_NAME%
echo "Addon path: %ADDON_PATH%"

@RD /S /Q "%ADDON_PATH%"

@MD "%ADDON_PATH%"

@COPY "risk-v-core.lua" "%ADDON_PATH%\risk-v-core.lua"