add wave -noupdate -divider {tb_offset_min_sum_decoder}
add wave -position insertpoint sim:/tb_offset_min_sum_decoder/*
add wave -noupdate -divider {u_dut}
add wave -position insertpoint sim:/tb_offset_min_sum_decoder/u_dut/*
add wave -noupdate -divider {u_ram0}
add wave -position insertpoint sim:/tb_offset_min_sum_decoder/u_dut/u_ram0/*
add wave -noupdate -divider {u_cn}
add wave -position insertpoint sim:/tb_offset_min_sum_decoder/u_dut/u_cn/*