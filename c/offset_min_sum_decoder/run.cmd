gcc -Wall -Wextra -O2 test_decoder.c decoder.c ../qc_encoder_all/qc_encoder.c -I../qc_encoder_all -o test_decoder.exe
echo Running all CCSDS code rate/block size combinations...
for %%i in (1 2 3 4 5 6 7 8 9) do (
	echo Testing option %%i
	test_decoder.exe %%i
)