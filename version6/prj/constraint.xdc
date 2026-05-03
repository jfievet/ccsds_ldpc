# Clock constraint
create_clock -name clk_250MHz -period 4.000 [get_ports clock_i]

# Optional async reset
set_false_path -from [get_ports reset_i]
