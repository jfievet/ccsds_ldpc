quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {tb}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/clock_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/reset_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_en_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_start_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_en_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_start_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_message_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/data_parity_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/observed_index
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/frame_done
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/cycle_counter
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/input_start_cycle
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/first_output_cycle
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/frame_done_cycle

add wave -noupdate -divider {dut io}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/clock_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/reset_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_en_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_start_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_o_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_en_o_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_start_o_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_message_o_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/data_parity_o_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/message_pipe_bit_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/message_pipe_valid_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/message_pipe_start_s

add wave -noupdate -divider {dut control}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/input_bit_count_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/input_row_block_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/input_local_index_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/parity_pending_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/parity_active_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/parity_block_index_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/parity_local_index_s

add wave -noupdate -divider {dut vectors}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/rom_data_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/shift_registers_s
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/parity_blocks_s

add wave -noupdate -divider {rom instances}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/rom_generate(0)/rom_inst/row_block_i
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/rom_generate(0)/rom_inst/data_o
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/rom_generate(7)/rom_inst/data_o

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 320
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns
update