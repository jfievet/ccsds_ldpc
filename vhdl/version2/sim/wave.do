add wave -noupdate -divider {tb_ldpc_encoder_1k_1_2}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/*

add wave -noupdate -divider {dut}
add wave -position insertpoint sim:/tb_ldpc_encoder_1k_1_2/dut/*

config wave -signalnamewidth 1