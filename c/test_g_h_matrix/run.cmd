@echo off
setlocal

gcc -O2 -std=c11 test_g_h.c -o test_g_h.exe
if errorlevel 1 exit /b 1

if "%~1"=="" (
	.\test_g_h.exe
) else (
	.\test_g_h.exe %1
)

endlocal