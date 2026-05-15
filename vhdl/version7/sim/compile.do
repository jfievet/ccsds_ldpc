quit -sim

transcript on
#onerror {quit -code 1}

set ROOT [file normalize [pwd]/..]

cd $ROOT

file mkdir tb/vectors

puts "== Build generators =="
set GCC "C:/MinGW/bin/gcc.exe"
exec $GCC -O2 -std=c11 -Wall -Wextra tools/gen_h_rows.c -o tools/gen_h_rows.exe
#exec $GCC -O2 -std=c11 -Wall -Wextra tools/gen_vectors.c -o tools/gen_vectors.exe -I ../c/qpsk_awgn_ldpc_chain -I ../c/qc_encoder_all ../c/qpsk_awgn_ldpc_chain/qpsk_chain.c ../c/qpsk_awgn_ldpc_chain/ldpc_decoder.c ../c/qc_encoder_all/qc_encoder.c -lm

puts "== Generate ROM package =="
exec tools/gen_h_rows.exe

puts "== Generate vectors =="
#exec tools/gen_vectors.exe --pattern prbs31 --ebn0_db 3.0
exec tools/gen_vectors.exe --pattern x83 --ebn0_db 10.0 --llr hard --invert 0

puts "== Compile VHDL =="
cd sim
if {[file isdirectory work]} { catch {file delete -force work} }
vlib work
vmap work work

vcom -2008 -work work +acc=rn ../src/h_row_rom_pkg.vhd
vcom -2008 -work work +acc=rn ../src/tdp_ram_rf_rf.vhd
vcom -2008 -work work +acc=rn ../src/sp_ram_rf.vhd
vcom -2008 -work work +acc=rn ../src/h_row_rom.vhd
vcom -2008 -work work +acc=rn ../src/offset_min_sum_decoder.vhd
vcom -2008 -work work +acc=rn ../tb/tb_offset_min_sum_decoder.vhd

puts "== Simulate =="
vsim -c work.tb_offset_min_sum_decoder
do wave.do
run 1200 us
#quit -code 0
