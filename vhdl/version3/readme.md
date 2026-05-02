1- Run python sim/generate_ldpc_artifacts.py --seed 123
2- Run from questa console compile.do
3- Run through vunit run.py

Version 3 update:
RAM and ROMs were updated to a maximum

Results:
2 ms to process a 1k frame

+------------------------------+----------------------------+------------+------------+---------+------+------+--------+--------+------+------------+
|           Instance           |           Module           | Total LUTs | Logic LUTs | LUTRAMs | SRLs |  FFs | RAMB36 | RAMB18 | URAM | DSP Blocks |
+------------------------------+----------------------------+------------+------------+---------+------+------+--------+--------+------+------------+
| ldpc_encoder_1k_1_2          |                      (top) |       6776 |       6776 |       0 |    0 | 1485 |     36 |      7 |    0 |          0 |
|   (ldpc_encoder_1k_1_2)      |                      (top) |          0 |          0 |       0 |    0 |    0 |      0 |      0 |    0 |          0 |
|   bwd_target_values_rom_inst | ldpc_bwd_target_values_rom |        590 |        590 |       0 |    0 |    1 |     18 |      0 |    0 |          0 |
|   fwd_target_values_rom_inst | ldpc_fwd_target_values_rom |        568 |        568 |       0 |    0 |    1 |     18 |      0 |    0 |          0 |
|   parity_core_inst           |           ldpc_parity_core |       5564 |       5564 |       0 |    0 | 1373 |      0 |      5 |    0 |          0 |
+------------------------------+----------------------------+------------+------------+---------+------+------+--------+--------+------+------------+