onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}

if {[catch {exec python generate_ldpc_artifacts.py} result]} {
  puts $result
  quit -code 1 -f
}

if {[file exists work]} {
  vdel -lib work -all
}

vlib work
vmap work work

vcom -2008 ../src/ldpc_encoder_1k_1_2_config_pkg.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2_qc_rom_pkg.vhd
vcom -2008 ../src/ldpc_circulant_row_rom.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2.vhd
vcom -2008 ../tb/tb_ldpc_encoder_1k_1_2.vhd

vsim -voptargs=+acc work.tb_ldpc_encoder_1k_1_2
do wave.do
run 2300 us
quit -f