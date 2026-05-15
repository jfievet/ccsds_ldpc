Requirements:

The objective of this module is to implement an LDPC Offset Min-Sum decoder.

The c\offset_min_sum_decoder directory contains the C implementation of the decoder.
The c\qpsk_awgn_ldpc_chain directory contains the implementation of a QPSK LDPC chain with noise.
The c\build_h directory contains the generation of the H matrices.

Here are the main implementation constraints:

Only support 1k rate 1/2.
The incoming codeword is stored in 3 true dual-port RAMs. These three RAMs allow reading 6 VNs in a single clock cycle.
A C program must extract the rows from the H matrix and store the column indices where the value is 1.
The module must store this information in 3 true dual-port ROMs. Each address represents the row number. If there is no index with value 1 for a given row, leave zero to indicate it. Column indices must always start at 1.
Create a complete pipeline that behaves like the decoder implemented in C:
Allocate the iteration
Read the ROM
Read the corresponding VNs
Compute min1 and min2
XOR the signs
Etc.
Rewrite the VNs into the 3 true dual-port RAMs (consider whether an intermediate RAM is needed for the old VN values).
Perform all this for a fixed number of iterations; syndrome verification is not implemented. The decoder must run with a fixed iteration count.
The code must be implementable on AMD FPGA devices.
Use VHDL 2008.

Ports:

clk_i
rst_i
data_i (6-bit width LLR)
data_valid_i
data_start_i
iter_cfg_i
data_o (1 bit)
data_valid_o
data_start_o

Verification:

Use the code in c\qpsk_awgn_ldpc_chain to create a noisy vector generator.
6-bit LLRs must be generated.
Simulation must run on ModelSim, using a single compile.do script (handling both compilation and simulation).

Below is an extract of the true dual-port RAM from an AMD FPGA. You need to make it parameterizable:

-- Correct Modelization with a Shared Variable
-- File: rams_tdp_rf_rf.vhd

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity rams_tdp_rf_rf is
port(
clka : in std_logic;
clkb : in std_logic;
ena : in std_logic;
enb : in std_logic;
wea : in std_logic;
web : in std_logic;
addra : in std_logic_vector(9 downto 0);
addrb : in std_logic_vector(9 downto 0);
dia : in std_logic_vector(15 downto 0);
dib : in std_logic_vector(15 downto 0);
doa : out std_logic_vector(15 downto 0);
dob : out std_logic_vector(15 downto 0)
);
end rams_tdp_rf_rf;

architecture syn of rams_tdp_rf_rf is
type ram_type is array (1023 downto 0) of std_logic_vector(15 downto 0);
shared variable RAM : ram_type;
begin
process(CLKA)
begin
if CLKA’event and CLKA = ‘1’ then
if ENA = ‘1’ then
DOA <= RAM(to_integer(unsigned(ADDRA)));
if WEA = ‘1’ then
RAM(to_integer(unsigned(ADDRA))) := DIA;
end if;
end if;
end if;
end process;

process(CLKB)
begin
if CLKB’event and CLKB = ‘1’ then
if ENB = ‘1’ then
DOB <= RAM(to_integer(unsigned(ADDRB)));
if WEB = ‘1’ then
RAM(to_integer(unsigned(ADDRB))) := DIB;
end if;
end if;
end if;
end process;

end syn;
