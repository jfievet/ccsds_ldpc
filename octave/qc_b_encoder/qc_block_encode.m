% CCSDS 131.0-B-5 QC block-based LDPC encoder and validator.
% This script keeps the encoding flow organized around M-bit QC blocks and
% permutation/XOR operators so it stays closer to an FPGA-oriented view
% than a generic bit-dependency-list encoder.

clear;
clc;

fprintf('Select CCSDS LDPC configuration:\n');
fprintf('  1. rate 1/2, block length 1024\n');
fprintf('  2. rate 1/2, block length 4096\n');
fprintf('  3. rate 1/2, block length 16384\n');
fprintf('  4. rate 2/3, block length 1024\n');
fprintf('  5. rate 2/3, block length 4096\n');
fprintf('  6. rate 2/3, block length 16384\n');
fprintf('  7. rate 4/5, block length 1024\n');
fprintf('  8. rate 4/5, block length 4096\n');
fprintf('  9. rate 4/5, block length 16384\n');

selection = input('Enter a number from 1 to 9: ');

% FPGA note:
% The menu and string-based configuration selection are software-only.
% In hardware, the selected configuration would normally be fixed at build
% time or chosen through a small configuration register.
if selection == 1
  rate = '1/2';
  block_length = 1024;
elseif selection == 2
  rate = '1/2';
  block_length = 4096;
elseif selection == 3
  rate = '1/2';
  block_length = 16384;
elseif selection == 4
  rate = '2/3';
  block_length = 1024;
elseif selection == 5
  rate = '2/3';
  block_length = 4096;
elseif selection == 6
  rate = '2/3';
  block_length = 16384;
elseif selection == 7
  rate = '4/5';
  block_length = 1024;
elseif selection == 8
  rate = '4/5';
  block_length = 4096;
elseif selection == 9
  rate = '4/5';
  block_length = 16384;
else
  error('Invalid selection. Choose an integer from 1 to 9.');
end

fprintf('Selected configuration: rate %s, block length %d\n', rate, block_length);

% FPGA note:
% These rate/block-length to M relationships are configuration constants.
% In RTL, they would usually be package constants, generics, or ROM data,
% not runtime-computed values.
if strcmp(rate, '1/2')
  if block_length == 1024
    M = 512;
  elseif block_length == 4096
    M = 2048;
  elseif block_length == 16384
    M = 8192;
  else
    error('Unsupported block length for rate 1/2.');
  end
elseif strcmp(rate, '2/3')
  if block_length == 1024
    M = 256;
  elseif block_length == 4096
    M = 1024;
  elseif block_length == 16384
    M = 4096;
  else
    error('Unsupported block length for rate 2/3.');
  end
elseif strcmp(rate, '4/5')
  if block_length == 1024
    M = 128;
  elseif block_length == 4096
    M = 512;
  elseif block_length == 16384
    M = 2048;
  else
    error('Unsupported block length for rate 4/5.');
  end
else
  error('Unsupported rate.');
end

matrix_suffix = sprintf('%s_%d', strrep(rate, '/', '_'), block_length);
h_filename = sprintf('H_%s.mat', matrix_suffix);
h_search_paths = { ...
  fullfile('..', 'build_h', h_filename), ...
  fullfile('..', 'build_H', h_filename) ...
};

h_path = '';
for path_index = 1:length(h_search_paths)
  if exist(h_search_paths{path_index}, 'file')
    h_path = h_search_paths{path_index};
    break;
  end
end

if isempty(h_path)
  error('Could not find %s in ../build_h or ../build_H.', h_filename);
end

% FPGA note:
% Loading H from disk is software-only and used here for validation.
% In a production encoder, H would usually not be stored in the FPGA.
% If an on-chip checker is required, H or an equivalent syndrome operator
% could be implemented as constants/ROM plus XOR logic.
loaded_h = load(h_path);
if ~isfield(loaded_h, 'H')
  error('The file %s does not contain variable H.', h_path);
end

H = mod(full(loaded_h.H), 2) ~= 0;
[parity_equation_count, total_length] = size(H);
information_length = total_length - parity_equation_count;
information_block_count = information_length / M;

if mod(information_length, M) ~= 0
  error('Unexpected H size: information length is not a multiple of M.');
end

fprintf('Loaded H from %s\n', h_path);
fprintf('H size: %d x %d\n', parity_equation_count, total_length);
fprintf('Derived M = %d, information length = %d, block count = %d\n', ...
        M, information_length, information_block_count);

supported_M = [128, 256, 512, 1024, 2048, 4096, 8192];
tuple_column = find(supported_M == M, 1);
if isempty(tuple_column)
  error('Unsupported submatrix size M.');
end

% FPGA note:
% theta and phi0..phi3 are pure CCSDS construction constants.
% In hardware terms, these belong in ROM/package constants, or they can be
% compiled away into fixed shift/operator tables for each configuration.
theta = [ ...
  3; 0; 1; 2; 2; 3; 0; 1; 0; 1; 2; 0; 2; 3; 0; 1; 2; 0; 1; 2; 0; 1; 2; 1; 2; 3];

phi0 = [ ...
     1,   59,   16,  160,  108,  226, 1148;
    22,   18,  103,  241,  126,  618, 2032;
     0,   52,  105,  185,  238,  404,  249;
    26,   23,    0,  251,  481,   32, 1807;
     0,   11,   50,  209,   96,  912,  485;
    10,    7,   29,  103,   28,  950, 1044;
     5,   22,  115,   90,   59,  534,  717;
    18,   25,   30,  184,  225,   63,  873;
     3,   27,   92,  248,  323,  971,  364;
    22,   30,   78,   12,   28,  304, 1926;
     3,   43,   70,  111,  386,  409, 1241;
     8,   14,   66,   66,  305,  708, 1769;
    25,   46,   39,  173,   34,  719,  532;
    25,   62,   84,   42,  510,  176,  768;
     2,   44,   79,  157,  147,  743, 1138;
    27,   12,   70,  174,  199,  759,  965;
     7,   38,   29,  104,  347,  674,  141;
     7,   47,   32,  144,  391,  958, 1527;
    15,    1,   45,   43,  165,  984,  505;
    10,   52,  113,  181,  414,   11, 1312;
     4,   61,   86,  250,   97,  413, 1840;
    19,   10,    1,  202,  158,  925,  709;
     7,   55,   42,   68,   86,  687, 1427;
     9,    7,  118,  177,  168,  752,  989;
    26,   12,   33,  170,  506,  867, 1925;
    17,    2,  126,   89,  489,  323,  270];

phi1 = [ ...
     0,    0,    0,    0,    0,    0,    0;
    27,   32,   53,  182,  375,  767, 1822;
    30,   21,   74,  249,  436,  227,  203;
    28,   36,   45,   65,  350,  247,  882;
     7,   30,   47,   70,  260,  284, 1989;
     1,   29,    0,  141,   84,  370,  957;
     8,   44,   59,  237,  318,  482, 1705;
    20,   29,  102,   77,  382,  273, 1083;
    26,   39,   25,   55,  169,  886, 1072;
    24,   14,    3,   12,  213,  634,  354;
     4,   22,   88,  227,   67,  762, 1942;
    12,   15,   65,   42,  313,  184,  446;
    23,   48,   62,   52,  242,  696, 1456;
    15,   55,   68,  243,  188,  413, 1940;
    15,   39,   91,  179,    1,  854, 1660;
    22,   11,   70,  250,  306,  544, 1661;
    31,    1,  115,  247,  397,  864,  587;
     3,   50,   31,  164,   80,   82,  708;
    29,   40,  121,   17,   33, 1009, 1466;
    21,   62,   45,   31,    7,  437,  433;
     2,   27,   56,  149,  447,   36, 1345;
     5,   38,   54,  105,  336,  562,  867;
    11,   40,  108,  183,  424,  816, 1551;
    26,   15,   14,  153,  134,  452, 2041;
     9,   11,   30,  177,  152,  290, 1383;
    17,   18,  116,   19,  492,  778, 1790];

phi2 = [ ...
     0,    0,    0,    0,    0,    0,    0;
    12,   46,    8,   35,  219,  254,  318;
    30,   45,  119,  167,   16,  790,  494;
    18,   27,   89,  214,  263,  642, 1467;
    10,   48,   31,   84,  415,  248,  757;
    16,   37,  122,  206,  403,  899, 1085;
    13,   41,    1,  122,  184,  328, 1630;
     9,   13,   69,   67,  279,  518,   64;
     7,    9,   92,  147,  198,  477,  689;
    15,   49,   47,   54,  307,  404, 1300;
    16,   36,   11,   23,  432,  698,  148;
    18,   10,   31,   93,  240,  160,  777;
     4,   11,   19,   20,  454,  497, 1431;
    23,   18,   66,  197,  294,  100,  659;
     5,   54,   49,   46,  479,  518,  352;
     3,   40,   81,  162,  289,   92, 1177;
    29,   27,   96,  101,  373,  464,  836;
    11,   35,   38,   76,  104,  592, 1572;
     4,   25,   83,   78,  141,  198,  348;
     8,   46,   42,  253,  270,  856, 1040;
     2,   24,   58,  124,  439,  235,  779;
    11,   33,   24,  143,  333,  134,  476;
    11,   18,   25,   63,  399,  542,  191;
     3,   37,   92,   41,   14,  545, 1393;
    15,   35,   38,  214,  277,  777, 1752;
    13,   21,  120,   70,  412,  483, 1627];

phi3 = [ ...
     0,    0,    0,    0,    0,    0,    0;
    13,   44,   35,  162,  312,  285, 1189;
    19,   51,   97,    7,  503,  554,  458;
    14,   12,  112,   31,  388,  809,  460;
    15,   15,   64,  164,   48,  185, 1039;
    20,   12,   93,   11,    7,   49, 1000;
    17,    4,   99,  237,  185,  101, 1265;
     4,    7,   94,  125,  328,   82, 1223;
     4,    2,  103,  133,  254,  898,  874;
    11,   30,   91,   99,  202,  627, 1292;
    17,   53,    3,  105,  285,  154, 1491;
    20,   23,    6,   17,   11,   65,  631;
     8,   29,   39,   97,  168,   81,  464;
    22,   37,  113,   91,  127,  823,  461;
    19,   42,   92,  211,    8,   50,  844;
    15,   48,  119,  128,  437,  413,  392;
     5,    4,   74,   82,  475,  462,  922;
    21,   10,   73,  115,   85,  175,  256;
    17,   18,  116,  248,  419,  715, 1986;
     9,   56,   31,   62,  459,  537,   19;
    20,    9,  127,   26,  468,  722,  266;
    18,   11,   98,  140,  209,   37,  471;
    31,   23,   23,  121,  311,  488, 1166;
    13,    8,   38,   12,  211,  179, 1300;
     2,    7,   18,   41,  510,  430, 1033;
    18,   24,   62,  249,  320,  264, 1606];

quarter_M = M / 4;
pi_maps = cell(26, 1);

% FPGA note:
% pi_maps are configuration-derived constants. They describe the QC
% permutation action and can be viewed as ROM contents or, better yet, as
% fixed rotate/rewire patterns in RTL.
fprintf('Building QC permutation maps...\n');
for permutation_index = 1:26
  phi_values = [phi0(permutation_index, tuple_column), ...
                phi1(permutation_index, tuple_column), ...
                phi2(permutation_index, tuple_column), ...
                phi3(permutation_index, tuple_column)];
  current_map = zeros(1, M);
  for bit_index = 0:(M - 1)
    quarter_index = floor((4 * bit_index) / M);
    mapped_bit = quarter_M * mod(theta(permutation_index) + quarter_index, 4) + ...
                 mod(phi_values(quarter_index + 1) + bit_index, quarter_M);
    current_map(bit_index + 1) = mapped_bit + 1;
  end
  pi_maps{permutation_index} = current_map;
end

% FPGA note:
% operator_term_lists and row*_operator_ids are structural constants.
% They define which QC operators are applied in each parity equation.
% These are ROM/package-constant candidates in FPGA.
operator_term_lists = cell(10, 1);
operator_term_lists{1} = [1];
operator_term_lists{2} = [2, 3, 4];
operator_term_lists{3} = [5, 6];
operator_term_lists{4} = [7, 8];
operator_term_lists{5} = [9, 10, 11];
operator_term_lists{6} = [12, 13, 14];
operator_term_lists{7} = [15, 16, 17];
operator_term_lists{8} = [18, 19, 20];
operator_term_lists{9} = [21, 22, 23];
operator_term_lists{10} = [24, 25, 26];

if strcmp(rate, '1/2')
  row2_operator_ids = [-1, -1];
  row3_operator_ids = [-1, 3];
elseif strcmp(rate, '2/3')
  row2_operator_ids = [5, -1, -1, -1];
  row3_operator_ids = [-1, 6, -1, 3];
elseif strcmp(rate, '4/5')
  row2_operator_ids = [9, 7, 5, 6, -1, -1, -1, -1];
  row3_operator_ids = [10, 8, 0, 0, -1, -1, -1, 3];
else
  error('Unsupported rate.');
end

% FPGA note:
% The random message generation is software-only test behavior.
% In hardware, message_bits is runtime input data.
rand('seed', 7);
message_bits = rand(1, information_length) >= 0.5;
message_blocks = reshape(message_bits, M, information_block_count)';

fprintf('Generated random message with %d bits.\n', information_length);
fprintf('Running QC block-based encoding...\n');

% FPGA note:
% A_block and B_block are real-time datapath values derived from the input
% message. These belong in registers/wires, not ROM.
A_block = false(1, M);
B_block = false(1, M);

for block_index = 1:information_block_count
  % FPGA note:
  % message_blocks is runtime data. Applying operator_id means performing
  % the QC block processing in real time: fixed shifts/permutations and
  % XORs over the current input block.
  input_block = message_blocks(block_index, :);

  operator_id = row2_operator_ids(block_index);
  current_output = false(1, M);
  if operator_id == -1
    current_output = input_block;
  elseif operator_id > 0
    term_indices = operator_term_lists{operator_id};
    for term_index = 1:length(term_indices)
      current_output = xor(current_output, input_block(pi_maps{term_indices(term_index)}));
    end
  end
  A_block = xor(A_block, current_output);

  operator_id = row3_operator_ids(block_index);
  current_output = false(1, M);
  if operator_id == -1
    current_output = input_block;
  elseif operator_id > 0
    term_indices = operator_term_lists{operator_id};
    for term_index = 1:length(term_indices)
      current_output = xor(current_output, input_block(pi_maps{term_indices(term_index)}));
    end
  end
  B_block = xor(B_block, current_output);
end

% FPGA note:
% S4_A_block and rhs_block are pure runtime processing results. In RTL,
% this is combinational/sequential datapath work using fixed QC operators.
S4_A_block = false(1, M);
term_indices = operator_term_lists{4};
for term_index = 1:length(term_indices)
  S4_A_block = xor(S4_A_block, A_block(pi_maps{term_indices(term_index)}));
end

rhs_block = xor(B_block, S4_A_block);

fprintf('Building block-level solve matrix T = I + S4*S2...\n');
% FPGA note:
% T is configuration-dependent and does not depend on the message.
% In an FPGA-oriented implementation, T should be treated as constant
% structure or precomputed offline, not rebuilt every time at runtime.
T = sparse(1:M, 1:M, 1, M, M);
s2_terms = operator_term_lists{2};
s4_terms = operator_term_lists{4};
for s4_index = 1:length(s4_terms)
  for s2_index = 1:length(s2_terms)
    composed_map = pi_maps{s2_terms(s2_index)}(pi_maps{s4_terms(s4_index)});
    T = mod(T + sparse(1:M, composed_map, 1, M, M), 2);
  end
end
T = sparse(mod(T, 2));

fprintf('Solving p3 block over GF(2)...\n');
% FPGA note:
% Aug and the elimination process are runtime processing in this script
% because they solve p3 for the current rhs_block.
% For RTL, this could be implemented as:
%   1. a sequential solve engine using precomputed schedules, or
%   2. a fully precomputed constant transform from rhs to p3.
Aug = [full(T) ~= 0, rhs_block' ~= 0];
augmented_column_count = columns(Aug);
solve_total_steps = 2 * M;
solve_last_percent = -1;

for pivot = 1:M
  solve_percent = floor((100 * pivot) / solve_total_steps);
  if solve_percent > solve_last_percent
    fprintf('Solve progress: %d%%\n', solve_percent);
    solve_last_percent = solve_percent;
  end

  pivot_offset = find(Aug(pivot:M, pivot), 1);
  if isempty(pivot_offset)
    error('QC block solve failed: singular T matrix.');
  end

  pivot_row = pivot + pivot_offset - 1;
  if pivot_row ~= pivot
    saved_row = Aug(pivot, :);
    Aug(pivot, :) = Aug(pivot_row, :);
    Aug(pivot_row, :) = saved_row;
  end

  if pivot < M
    rows_below = find(Aug(pivot + 1:M, pivot)) + pivot;
    for row_index = 1:length(rows_below)
      current_row = rows_below(row_index);
      Aug(current_row, pivot:augmented_column_count) = xor( ...
        Aug(current_row, pivot:augmented_column_count), ...
        Aug(pivot, pivot:augmented_column_count));
    end
  end
end

for pivot = M:-1:1
  solve_percent = floor((100 * (2 * M - pivot + 1)) / solve_total_steps);
  if solve_percent > solve_last_percent
    fprintf('Solve progress: %d%%\n', solve_percent);
    solve_last_percent = solve_percent;
  end

  if pivot > 1
    rows_above = find(Aug(1:pivot - 1, pivot));
    for row_index = 1:length(rows_above)
      current_row = rows_above(row_index);
      Aug(current_row, pivot:augmented_column_count) = xor( ...
        Aug(current_row, pivot:augmented_column_count), ...
        Aug(pivot, pivot:augmented_column_count));
    end
  end
end

if solve_last_percent < 100
  fprintf('Solve progress: 100%%\n');
end

% FPGA note:
% parity_3_block, parity_2_block, and parity_1_block are runtime parity
% results. They are the main encoder datapath outputs.
parity_3_block = Aug(:, augmented_column_count)' ~= 0;

S2_p3_block = false(1, M);
term_indices = operator_term_lists{2};
for term_index = 1:length(term_indices)
  S2_p3_block = xor(S2_p3_block, parity_3_block(pi_maps{term_indices(term_index)}));
end

P1_p3_block = xor(parity_3_block, parity_3_block(pi_maps{1}));
parity_2_block = xor(A_block, S2_p3_block);
parity_1_block = P1_p3_block;

% FPGA note:
% Output packing is runtime datapath assembly. In RTL this is typically
% just output concatenation or register formatting.
full_codeword = [message_bits, parity_1_block, parity_2_block, parity_3_block];
transmitted_codeword = [message_bits, parity_1_block, parity_2_block];

fprintf('Internal full codeword length: %d bits\n', length(full_codeword));
fprintf('Transmitted codeword length after puncturing: %d bits\n', length(transmitted_codeword));

% FPGA note:
% Syndrome validation against H is software/testbench style checking here.
% In a final FPGA encoder, this is optional debug/verification logic rather
% than core encoding datapath.
syndrome = mod(double(H) * double(full_codeword'), 2);
fprintf('Validation syndrome weight: %d\n', nnz(syndrome));

if any(syndrome)
  fprintf('Validation result: FAIL\n');
  fprintf('The QC block-based codeword does not satisfy H * c'' = 0 mod 2.\n');
else
  fprintf('Validation result: PASS\n');
  fprintf('The QC block-based codeword satisfies H * c'' = 0 mod 2.\n');
end
