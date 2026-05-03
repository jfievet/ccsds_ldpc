@echo off
setlocal

gcc -O2 -std=c11 build_g.c -o build_g.exe
if errorlevel 1 exit /b 1

.\build_g.exe 1
.\build_g.exe 2
.\build_g.exe 3

.\build_g.exe 4
.\build_g.exe 5
.\build_g.exe 6

.\build_g.exe 7
.\build_g.exe 8
.\build_g.exe 9

python mat2png.py G_1_2_1024.mat -o G_1_2_1024.png --major-step 256 --minor-step 64
python mat2png.py G_1_2_4096.mat -o G_1_2_4096.png --major-step 256 --minor-step 64
python mat2png.py G_1_2_16384.mat -o G_1_2_16384.png --downsample 2 --major-step 1024 --minor-step 256

python mat2png.py G_2_3_1024.mat -o G_2_3_1024.png --major-step 256 --minor-step 64
python mat2png.py G_2_3_4096.mat -o G_2_3_4096.png --major-step 256 --minor-step 64
python mat2png.py G_2_3_16384.mat -o G_2_3_16384.png --downsample 2 --major-step 1024 --minor-step 256

python mat2png.py G_4_5_1024.mat -o G_4_5_1024.png --major-step 256 --minor-step 64
python mat2png.py G_4_5_4096.mat -o G_4_5_4096.png --major-step 256 --minor-step 64
python mat2png.py G_4_5_16384.mat -o G_4_5_16384.png --downsample 2 --major-step 1024 --minor-step 256