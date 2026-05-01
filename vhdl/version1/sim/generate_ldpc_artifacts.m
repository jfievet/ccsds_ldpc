function generate_ldpc_artifacts()
  clc;

  fprintf('Available configuration:\n');
  fprintf('  1. rate 1/2, block length 1024\n');

  selection = input('Enter a number from the menu: ');
  if selection ~= 1
    error('This version is intentionally restricted to the 1k 1/2 case.');
  end

  script_dir = fileparts(mfilename('fullpath'));
  root_dir = fileparts(script_dir);
  workspace_dir = fileparts(fileparts(root_dir));
  h_path = fullfile(workspace_dir, 'octave', 'build_h', 'H_1_2_1024.mat');

  if exist(h_path, 'file') ~= 2
    error('Could not find %s.', h_path);
  end

  H = read_octave_sparse_matrix(h_path);
  constants = build_constants_from_h(H);
  message_bits = deterministic_message(constants.k);
  encoded_frame = encode_message(message_bits, constants);

  write_vhdl_package(constants, fullfile(root_dir, 'src', 'ldpc_encoder_1k_1_2_constants_pkg.vhd'));
  write_bit_file(fullfile(script_dir, 'message_1k_1_2.txt'), message_bits);
  write_bit_file(fullfile(script_dir, 'encoded_frame_1k_1_2.txt'), encoded_frame);

  fprintf('Generated VHDL constants package and deterministic reference vectors.\n');
  fprintf('k = %d, M = %d, N = %d\n', constants.k, constants.m, constants.n);
end

function H = read_octave_sparse_matrix(path)
  file_text = fileread(path);
  lines = regexp(file_text, '\r?\n', 'split');
  rows = 0;
  columns = 0;
  triplets = zeros(0, 3);

  for line_index = 1:length(lines)
    line = strtrim(lines{line_index});
    if isempty(line)
      continue;
    end

    if strncmp(line, '# rows:', 7)
      rows = sscanf(line, '# rows: %d');
      continue;
    end

    if strncmp(line, '# columns:', 10)
      columns = sscanf(line, '# columns: %d');
      continue;
    end

    if line(1) == '#'
      continue;
    end

    values = sscanf(line, '%d %d %d');
    if numel(values) == 3
      triplets(end + 1, :) = values'; %#ok<AGROW>
    end
  end

  if rows == 0 || columns == 0
    error('Failed to parse matrix dimensions from %s.', path);
  end

  H = false(rows, columns);
  for entry_index = 1:size(triplets, 1)
    H(triplets(entry_index, 1), triplets(entry_index, 2)) = mod(triplets(entry_index, 3), 2) ~= 0;
  end
end

function constants = build_constants_from_h(H)
  [parity_equation_count, total_length] = size(H);
  M = parity_equation_count / 3;
  k = total_length - parity_equation_count;
  n = k + 2 * M;

  if M ~= 512 || k ~= 1024 || n ~= 2048
    error('Expected the 1k 1/2 configuration.');
  end

  I = eye(M) ~= 0;
  row_1 = H(1:M, :);
  row_2 = H(M + 1:2 * M, :);
  row_3 = H(2 * M + 1:3 * M, :);

  info_columns = 1:k;
  parity_1_columns = (k + 1):(k + M);
  parity_2_columns = (k + M + 1):(k + 2 * M);
  parity_3_columns = (k + 2 * M + 1):(k + 3 * M);

  if any(row_1(:, info_columns)(:))
    error('Unexpected H structure for row_1 information block.');
  end
  if any(any(xor(row_1(:, parity_1_columns), I)))
    error('Unexpected H structure for row_1 parity_1 block.');
  end
  if any(row_1(:, parity_2_columns)(:))
    error('Unexpected H structure for row_1 parity_2 block.');
  end
  if any(row_2(:, parity_1_columns)(:))
    error('Unexpected H structure for row_2 parity_1 block.');
  end
  if any(any(xor(row_2(:, parity_2_columns), I)))
    error('Unexpected H structure for row_2 parity_2 block.');
  end
  if any(row_3(:, parity_1_columns)(:))
    error('Unexpected H structure for row_3 parity_1 block.');
  end
  if any(any(xor(row_3(:, parity_3_columns), I)))
    error('Unexpected H structure for row_3 parity_3 block.');
  end

  A = row_2(:, info_columns);
  B = row_3(:, info_columns);
  P1 = row_1(:, parity_3_columns);
  S2 = row_2(:, parity_3_columns);
  S4 = row_3(:, parity_2_columns);
  T = mod(double(I) + mod(double(S4) * double(S2), 2), 2) ~= 0;

  constants = struct();
  constants.k = k;
  constants.m = M;
  constants.n = n;
  constants.total_length = total_length;
  constants.a_dependencies = build_dependency_list(A);
  constants.b_dependencies = build_dependency_list(B);
  constants.p1_dependencies = build_dependency_list(P1);
  constants.s2_dependencies = build_dependency_list(S2);
  constants.s4_dependencies = build_dependency_list(S4);
  [constants.forward_swap_rows, constants.forward_target_rows, constants.backward_target_rows] = build_elimination_schedule(T);
end

function dependencies = build_dependency_list(matrix)
  row_count = size(matrix, 1);
  dependencies = cell(row_count, 1);
  for row_index = 1:row_count
    dependencies{row_index} = find(matrix(row_index, :)) - 1;
  end
end

function [forward_swap_rows, forward_target_rows, backward_target_rows] = build_elimination_schedule(T)
  M = size(T, 1);
  working_T = T;
  forward_swap_rows = zeros(M, 1);
  forward_target_rows = cell(M, 1);
  backward_target_rows = cell(M, 1);

  for pivot = 1:M
    pivot_offset = find(working_T(pivot:M, pivot), 1);
    if isempty(pivot_offset)
      error('Singular p3 solve matrix.');
    end
    pivot_row = pivot + pivot_offset - 1;
    forward_swap_rows(pivot) = pivot_row - 1;

    if pivot_row ~= pivot
      saved_row = working_T(pivot, :);
      working_T(pivot, :) = working_T(pivot_row, :);
      working_T(pivot_row, :) = saved_row;
    end

    target_rows = find(working_T(pivot + 1:M, pivot)) + pivot;
    forward_target_rows{pivot} = target_rows - 1;
    for target_index = 1:length(target_rows)
      current_row = target_rows(target_index);
      working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), working_T(pivot, pivot:M));
    end
  end

  for pivot = M:-1:1
    target_rows = find(working_T(1:pivot - 1, pivot));
    backward_target_rows{pivot} = target_rows - 1;
    for target_index = 1:length(target_rows)
      current_row = target_rows(target_index);
      working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), working_T(pivot, pivot:M));
    end
  end

  if any(any(xor(working_T, eye(M) ~= 0)))
    error('Elimination schedule did not reduce T to identity.');
  end
end

function message_bits = deterministic_message(bit_count)
  message_bits = false(1, bit_count);
  for index = 0:(bit_count - 1)
    message_bits(index + 1) = bitand(bitxor(bitxor(index * 7 + 3, bitshift(index, -1)), bitshift(index, -3)), 1) ~= 0;
  end
end

function codeword = encode_message(message_bits, constants)
  M = constants.m;
  A_times_message = false(M, 1);
  B_times_message = false(M, 1);

  for row_index = 1:M
    A_times_message(row_index) = xor_reduce(message_bits, constants.a_dependencies{row_index});
    B_times_message(row_index) = xor_reduce(message_bits, constants.b_dependencies{row_index});
  end

  rhs = B_times_message;
  for row_index = 1:M
    rhs(row_index) = xor(rhs(row_index), xor_reduce(A_times_message, constants.s4_dependencies{row_index}));
  end

  parity_3 = rhs;
  for pivot = 1:M
    pivot_row = constants.forward_swap_rows(pivot) + 1;
    if pivot_row ~= pivot
      saved_bit = parity_3(pivot);
      parity_3(pivot) = parity_3(pivot_row);
      parity_3(pivot_row) = saved_bit;
    end
    if parity_3(pivot)
      target_rows = constants.forward_target_rows{pivot} + 1;
      for target_index = 1:length(target_rows)
        parity_3(target_rows(target_index)) = ~parity_3(target_rows(target_index));
      end
    end
  end

  for pivot = M:-1:1
    if parity_3(pivot)
      target_rows = constants.backward_target_rows{pivot} + 1;
      for target_index = 1:length(target_rows)
        parity_3(target_rows(target_index)) = ~parity_3(target_rows(target_index));
      end
    end
  end

  parity_2 = A_times_message;
  parity_1 = false(M, 1);
  for row_index = 1:M
    parity_2(row_index) = xor(parity_2(row_index), xor_reduce(parity_3, constants.s2_dependencies{row_index}));
    parity_1(row_index) = xor_reduce(parity_3, constants.p1_dependencies{row_index});
  end

  codeword = [message_bits, parity_1', parity_2'];
end

function result = xor_reduce(bits, zero_based_indices)
  result = false;
  for index = 1:length(zero_based_indices)
    result = xor(result, bits(zero_based_indices(index) + 1));
  end
end

function write_bit_file(path, bits)
  file_id = fopen(path, 'w');
  if file_id < 0
    error('Could not open %s for writing.', path);
  end

  cleanup = onCleanup(@() fclose(file_id));
  for index = 1:length(bits)
    fprintf(file_id, '%d\n', bits(index) ~= 0);
  end
end

function write_vhdl_package(constants, path)
  file_id = fopen(path, 'w');
  if file_id < 0
    error('Could not open %s for writing.', path);
  end

  cleanup = onCleanup(@() fclose(file_id));
  fprintf(file_id, 'library ieee;\n');
  fprintf(file_id, 'use ieee.std_logic_1164.all;\n\n');
  fprintf(file_id, 'package ldpc_encoder_1k_1_2_constants_pkg is\n');
  fprintf(file_id, '  type natural_vector_t is array (natural range <>) of natural;\n\n');
  fprintf(file_id, '  constant LDPC_RATE_NUMERATOR : natural := 1;\n');
  fprintf(file_id, '  constant LDPC_RATE_DENOMINATOR : natural := 2;\n');
  fprintf(file_id, '  constant LDPC_BLOCK_SIZE : natural := 1024;\n');
  fprintf(file_id, '  constant LDPC_K : natural := %d;\n', constants.k);
  fprintf(file_id, '  constant LDPC_M : natural := %d;\n', constants.m);
  fprintf(file_id, '  constant LDPC_N : natural := %d;\n', constants.n);
  fprintf(file_id, '  constant LDPC_TOTAL_LENGTH : natural := %d;\n\n', constants.total_length);

  write_vector_constant(file_id, 'A_DEP_OFFSETS', flatten_offsets(constants.a_dependencies));
  write_vector_constant(file_id, 'A_DEP_VALUES', flatten_values(constants.a_dependencies));
  write_vector_constant(file_id, 'B_DEP_OFFSETS', flatten_offsets(constants.b_dependencies));
  write_vector_constant(file_id, 'B_DEP_VALUES', flatten_values(constants.b_dependencies));
  write_vector_constant(file_id, 'P1_DEP_OFFSETS', flatten_offsets(constants.p1_dependencies));
  write_vector_constant(file_id, 'P1_DEP_VALUES', flatten_values(constants.p1_dependencies));
  write_vector_constant(file_id, 'S2_DEP_OFFSETS', flatten_offsets(constants.s2_dependencies));
  write_vector_constant(file_id, 'S2_DEP_VALUES', flatten_values(constants.s2_dependencies));
  write_vector_constant(file_id, 'S4_DEP_OFFSETS', flatten_offsets(constants.s4_dependencies));
  write_vector_constant(file_id, 'S4_DEP_VALUES', flatten_values(constants.s4_dependencies));
  write_vector_constant(file_id, 'FWD_SWAP_ROWS', constants.forward_swap_rows');
  write_vector_constant(file_id, 'FWD_TARGET_OFFSETS', flatten_offsets(constants.forward_target_rows));
  write_vector_constant(file_id, 'FWD_TARGET_VALUES', flatten_values(constants.forward_target_rows));
  write_vector_constant(file_id, 'BWD_TARGET_OFFSETS', flatten_offsets(constants.backward_target_rows));
  write_vector_constant(file_id, 'BWD_TARGET_VALUES', flatten_values(constants.backward_target_rows));

  fprintf(file_id, 'end package ldpc_encoder_1k_1_2_constants_pkg;\n');
end

function offsets = flatten_offsets(nested)
  offsets = zeros(1, length(nested) + 1);
  total_count = 0;
  for index = 1:length(nested)
    offsets(index) = total_count;
    total_count = total_count + length(nested{index});
  end
  offsets(end) = total_count;
end

function values = flatten_values(nested)
  values = zeros(1, 0);
  for index = 1:length(nested)
    values = [values, nested{index}]; %#ok<AGROW>
  end
end

function write_vector_constant(file_id, name, values)
  fprintf(file_id, '  constant %s : natural_vector_t(0 to %d) := (\n', name, length(values) - 1);
  for index = 1:length(values)
    if index == length(values)
      fprintf(file_id, '    %d => %d\n', index - 1, values(index));
    else
      fprintf(file_id, '    %d => %d,\n', index - 1, values(index));
    end
  end
  fprintf(file_id, '  );\n\n');
end