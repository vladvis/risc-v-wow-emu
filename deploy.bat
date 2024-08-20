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

@COPY "src\risc-v-core.lua" "%ADDON_PATH%"
@COPY "src\risc-v-memory.lua" "%ADDON_PATH%"
@COPY "src\rv32i-base-instructions.lua" "%ADDON_PATH%"
@COPY "src\risc-v-fpu.lua" "%ADDON_PATH%"
@COPY "src\risc-v-float-conversion.lua" "%ADDON_PATH%"
@COPY "Addon.toc" "%ADDON_PATH%\%ADDON_NAME%.toc"

:: TESTS
@MD "%ADDON_PATH%\tests"
for %%f in (tests\lua_bin\*.lua) do (
  @COPY "%%f" "%ADDON_PATH%\tests"
  echo tests\%%~nf.lua >> "%ADDON_PATH%\%ADDON_NAME%.toc"
)

@COPY "tests\testsuite.lua" "%ADDON_PATH%\tests"
echo tests\testsuite.lua >> "%ADDON_PATH%\%ADDON_NAME%.toc"