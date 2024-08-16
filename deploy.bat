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

@COPY "risc-v-core.lua" "%ADDON_PATH%"
@COPY "risc-v-memory.lua" "%ADDON_PATH%"
@COPY "risc-v-program.lua" "%ADDON_PATH%"
@COPY "rv32i-base-instructions.lua" "%ADDON_PATH%"
@COPY "Addon.toc" "%ADDON_PATH%\%ADDON_NAME%.toc"