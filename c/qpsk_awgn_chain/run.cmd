setlocal
cd /d %~dp0

if not exist build mkdir build

set CFLAGS=-std=c99 -O2 -Wall -Wextra
gcc %CFLAGS% -I. -o build\qpsk_ber.exe main.c qpsk_chain.c -lm
if errorlevel 1 exit /b 1

build\qpsk_ber.exe %*

