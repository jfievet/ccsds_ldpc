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
vcom -2008 ../src/ldpc_encoder_1k_1_2_a_tables_pkg.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2_b_tables_pkg.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2_parity_tables_pkg.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2_solver_tables_pkg.vhd
vcom -2008 ../src/ldpc_message_buffer.vhd
vcom -2008 ../src/ldpc_output_serializer.vhd
vcom -2008 ../src/ldpc_parity_core.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2.vhd
vcom -2008 ../tb/tb_ldpc_encoder_1k_1_2.vhd

vsim -c -voptargs=+acc work.tb_ldpc_encoder_1k_1_2
do wave.do
run 1 ms