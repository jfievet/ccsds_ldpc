@echo off
setlocal

python generate_constants.py
if errorlevel 1 goto :fail

gcc -O2 -std=c11 qc_encoder.c test_qc_encoder.c -o test_qc_encoder.exe
if errorlevel 1 goto :fail

for %%I in (1 2 4 5 7 8) do (
	echo Running configuration %%I...
	test_qc_encoder.exe %%I
	if errorlevel 1 goto :fail
)

echo Supported configurations passed: 1 2 4 5 7 8.
exit /b 0

:fail
echo run.cmd failed.
exit /b 1