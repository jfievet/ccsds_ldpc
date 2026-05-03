@echo off
setlocal

python .\generate_constants.py
if errorlevel 1 exit /b 1

gcc -O2 -std=c11 qc_encoder.c test_qc_encoder.c -o test_qc_encoder.exe
if errorlevel 1 exit /b 1

if "%~1"=="" (
	.\test_qc_encoder.exe
) else if "%~2"=="" (
	.\test_qc_encoder.exe %1
) else (
	.\test_qc_encoder.exe %1 %2
)

endlocal