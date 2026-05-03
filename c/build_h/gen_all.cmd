gcc -O2 -std=c11 build_h.c -o build_h

.\build_h.exe 1
.\build_h.exe 2
.\build_h.exe 3

.\build_h.exe 4
.\build_h.exe 5
.\build_h.exe 6

.\build_h.exe 7
.\build_h.exe 8
.\build_h.exe 9

python mat2png.py H_1_2_1024.mat -o H_1_2_1024.png --major-step 256 --minor-step 64
python mat2png.py H_1_2_4096.mat -o H_1_2_4096.png --major-step 256 --minor-step 64
python mat2png.py H_1_2_16384.mat -o H_1_2_16384.png --downsample 4 --major-step 1024 --minor-step 256

python mat2png.py H_2_3_1024.mat -o H_2_3_1024.png --major-step 256 --minor-step 64
python mat2png.py H_2_3_4096.mat -o H_2_3_4096.png --major-step 256 --minor-step 64
python mat2png.py H_2_3_16384.mat -o H_2_3_16384.png --downsample 4 --major-step 1024 --minor-step 256

python mat2png.py H_4_5_1024.mat -o H_4_5_1024.png --major-step 256 --minor-step 64
python mat2png.py H_4_5_4096.mat -o H_4_5_4096.png --major-step 256 --minor-step 64
python mat2png.py H_4_5_16384.mat -o H_4_5_16384.png --major-step 256 --minor-step 64
