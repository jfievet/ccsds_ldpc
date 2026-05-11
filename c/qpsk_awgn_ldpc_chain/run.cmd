setlocal
cd /d %~dp0

if not exist build mkdir build

set CFLAGS=-std=c99 -O2 -Wall -Wextra
gcc %CFLAGS% -I. -I..\qc_encoder_all -o build\qpsk_ber.exe main.c qpsk_chain.c ldpc_decoder.c ..\qc_encoder_all\qc_encoder.c -lm
if errorlevel 1 exit /b 1

build\qpsk_ber.exe %*
