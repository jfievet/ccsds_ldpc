onerror {quit -code 1 -f}

if {[catch {exec python generate_ldpc_artifacts.py} result]} {
  puts $result
  quit -code 1 -f
}

if {![file exists work]} {
  vlib work
}
vmap work work

vcom -2008 ../src/ldpc_encoder_1k_1_2_constants_pkg.vhd
vcom -2008 ../src/ldpc_message_buffer.vhd
vcom -2008 ../src/ldpc_parity_core.vhd
vcom -2008 ../src/ldpc_output_serializer.vhd
vcom -2008 ../src/ldpc_encoder_1k_1_2.vhd
vcom -2008 ../tb/tb_ldpc_encoder_1k_1_2.vhd

vsim work.tb_ldpc_encoder_1k_1_2
run -all
#quit -f