% CCSDS 131.0-B-5 / Section 7.4 encoder and validation.
% This script loads previously generated constants and encodes messages
% using only XORs, indexing, and saved row-operation schedules.

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

matrix_suffix = sprintf('%s_%d', strrep(rate, '/', '_'), block_length);
constants_filename = sprintf('ldpc_constants_%s.mat', matrix_suffix);
random_test_count = 3;

if ~exist(constants_filename, 'file')
  error('Could not find %s. Run generate_constants.m first for this configuration.', constants_filename);
end

loaded_constants = load(constants_filename);
required_constant_names = { ...
  'rate', 'block_length', 'information_length', 'transmitted_length', 'total_length', 'M', ...
  'A_dependencies', 'B_dependencies', 'P1_dependencies', 'S2_dependencies', 'S4_dependencies', ...
  'forward_swap_rows', 'forward_target_rows', 'backward_target_rows' ...
};

for name_index = 1:length(required_constant_names)
  if ~isfield(loaded_constants, required_constant_names{name_index})
    error('The file %s is missing %s.', constants_filename, required_constant_names{name_index});
  end
end

if ~strcmp(loaded_constants.rate, rate) || loaded_constants.block_length ~= block_length
  error('The constants in %s do not match the selected configuration.', constants_filename);
end

information_length = loaded_constants.information_length;
transmitted_length = loaded_constants.transmitted_length;
total_length = loaded_constants.total_length;
M = loaded_constants.M;
A_dependencies = loaded_constants.A_dependencies;
B_dependencies = loaded_constants.B_dependencies;
P1_dependencies = loaded_constants.P1_dependencies;
S2_dependencies = loaded_constants.S2_dependencies;
S4_dependencies = loaded_constants.S4_dependencies;
forward_swap_rows = loaded_constants.forward_swap_rows;
forward_target_rows = loaded_constants.forward_target_rows;
backward_target_rows = loaded_constants.backward_target_rows;

use_workspace_message = false;
if exist('message_bits', 'var') == 1
  if isvector(message_bits) && numel(message_bits) == information_length
    use_workspace_message = true;
  else
    fprintf(['Ignoring existing workspace variable message_bits because its length does not match ' ...
             'the selected configuration.\n']);
  end
end

if use_workspace_message
  message_bits = reshape(message_bits ~= 0, 1, information_length);
else
  % Deterministic default input when the caller does not preload message_bits.
  message_bits = mod(0:(information_length - 1), 2) ~= 0;
end

A_times_message = false(M, 1);
B_times_message = false(M, 1);

fprintf('Encoding primary message...\n');
primary_total_steps = 4 * M;
primary_last_percent = -1;

for row_index = 1:M
  primary_percent = floor((100 * row_index) / primary_total_steps);
  if primary_percent > primary_last_percent
    fprintf('Primary encoding progress: %d%%\n', primary_percent);
    primary_last_percent = primary_percent;
  end

  A_times_message(row_index) = mod(sum(message_bits(A_dependencies{row_index})), 2) ~= 0;
  B_times_message(row_index) = mod(sum(message_bits(B_dependencies{row_index})), 2) ~= 0;
end

rhs = B_times_message;
for row_index = 1:M
  primary_percent = floor((100 * (M + row_index)) / primary_total_steps);
  if primary_percent > primary_last_percent
    fprintf('Primary encoding progress: %d%%\n', primary_percent);
    primary_last_percent = primary_percent;
  end

  if mod(sum(A_times_message(S4_dependencies{row_index})), 2) ~= 0
    rhs(row_index) = ~rhs(row_index);
  end
end

parity_3 = rhs;
for pivot = 1:M
  primary_percent = floor((100 * (2 * M + pivot)) / primary_total_steps);
  if primary_percent > primary_last_percent
    fprintf('Primary encoding progress: %d%%\n', primary_percent);
    primary_last_percent = primary_percent;
  end

  pivot_row = forward_swap_rows(pivot);
  if pivot_row ~= pivot
    saved_bit = parity_3(pivot);
    parity_3(pivot) = parity_3(pivot_row);
    parity_3(pivot_row) = saved_bit;
  end

  if parity_3(pivot)
    target_rows = forward_target_rows{pivot};
    for target_index = 1:length(target_rows)
      current_row = target_rows(target_index);
      parity_3(current_row) = ~parity_3(current_row);
    end
  end
end

for pivot = M:-1:1
  primary_percent = floor((100 * (3 * M + (M - pivot + 1))) / primary_total_steps);
  if primary_percent > primary_last_percent
    fprintf('Primary encoding progress: %d%%\n', primary_percent);
    primary_last_percent = primary_percent;
  end

  if parity_3(pivot)
    target_rows = backward_target_rows{pivot};
    for target_index = 1:length(target_rows)
      current_row = target_rows(target_index);
      parity_3(current_row) = ~parity_3(current_row);
    end
  end
end

parity_2 = A_times_message;
parity_1 = false(M, 1);

for row_index = 1:M
  if mod(sum(parity_3(S2_dependencies{row_index})), 2) ~= 0
    parity_2(row_index) = ~parity_2(row_index);
  end
  parity_1(row_index) = mod(sum(parity_3(P1_dependencies{row_index})), 2) ~= 0;
end

if primary_last_percent < 100
  fprintf('Primary encoding progress: 100%%\n');
end

transmitted_codeword = [message_bits, parity_1', parity_2'];
punctured_parity = parity_3';
full_codeword = [message_bits, parity_1', parity_2', punctured_parity];

fprintf('Configuration: rate %s, block length %d\n', rate, block_length);
fprintf('k = %d, transmitted length = %d, internal full length = %d, M = %d\n', ...
        information_length, transmitted_length, total_length, M);
fprintf('Encoded one message into systematic form [m p1 p2].\n');
fprintf('Stored punctured parity block length: %d\n', length(punctured_parity));

h_filename = sprintf('H_%s.mat', matrix_suffix);
h_search_paths = { ...
  fullfile('..', 'build_h', h_filename), ...
  fullfile('..', 'build_H', h_filename), ...
  fullfile('build_h', h_filename), ...
  fullfile('build_H', h_filename), ...
  fullfile('octave', 'build_h', h_filename), ...
  fullfile('octave', 'build_H', h_filename) ...
};

h_path = '';
for path_index = 1:length(h_search_paths)
  if exist(h_search_paths{path_index}, 'file')
    h_path = h_search_paths{path_index};
    break;
  end
end

if isempty(h_path)
  error('Could not find %s for validation.', h_filename);
end

loaded_h = load(h_path);
if ~isfield(loaded_h, 'H')
  error('The file %s does not contain variable H.', h_path);
end

H = mod(full(loaded_h.H), 2) ~= 0;
syndrome = mod(double(H) * double(full_codeword'), 2);
fprintf('Primary-message syndrome weight: %d\n', nnz(syndrome));
if any(syndrome)
  error('Primary encoded codeword does not satisfy H * c'' = 0 over GF(2).');
end

rand('seed', 7);
all_tests_passed = true;

fprintf('Running random-message validation...\n');

for test_index = 1:random_test_count
  test_message_bits = rand(1, information_length) >= 0.5;
  test_A_times_message = false(M, 1);
  test_B_times_message = false(M, 1);
  test_total_steps = 4 * M;
  test_last_percent = -1;

  for row_index = 1:M
    test_percent = floor((100 * row_index) / test_total_steps);
    if test_percent > test_last_percent
      fprintf('Random test %d/%d progress: %d%%\n', test_index, random_test_count, test_percent);
      test_last_percent = test_percent;
    end

    test_A_times_message(row_index) = mod(sum(test_message_bits(A_dependencies{row_index})), 2) ~= 0;
    test_B_times_message(row_index) = mod(sum(test_message_bits(B_dependencies{row_index})), 2) ~= 0;
  end

  test_rhs = test_B_times_message;
  for row_index = 1:M
    test_percent = floor((100 * (M + row_index)) / test_total_steps);
    if test_percent > test_last_percent
      fprintf('Random test %d/%d progress: %d%%\n', test_index, random_test_count, test_percent);
      test_last_percent = test_percent;
    end

    if mod(sum(test_A_times_message(S4_dependencies{row_index})), 2) ~= 0
      test_rhs(row_index) = ~test_rhs(row_index);
    end
  end

  test_parity_3 = test_rhs;
  for pivot = 1:M
    test_percent = floor((100 * (2 * M + pivot)) / test_total_steps);
    if test_percent > test_last_percent
      fprintf('Random test %d/%d progress: %d%%\n', test_index, random_test_count, test_percent);
      test_last_percent = test_percent;
    end

    pivot_row = forward_swap_rows(pivot);
    if pivot_row ~= pivot
      saved_bit = test_parity_3(pivot);
      test_parity_3(pivot) = test_parity_3(pivot_row);
      test_parity_3(pivot_row) = saved_bit;
    end

    if test_parity_3(pivot)
      target_rows = forward_target_rows{pivot};
      for target_index = 1:length(target_rows)
        current_row = target_rows(target_index);
        test_parity_3(current_row) = ~test_parity_3(current_row);
      end
    end
  end

  for pivot = M:-1:1
    test_percent = floor((100 * (3 * M + (M - pivot + 1))) / test_total_steps);
    if test_percent > test_last_percent
      fprintf('Random test %d/%d progress: %d%%\n', test_index, random_test_count, test_percent);
      test_last_percent = test_percent;
    end

    if test_parity_3(pivot)
      target_rows = backward_target_rows{pivot};
      for target_index = 1:length(target_rows)
        current_row = target_rows(target_index);
        test_parity_3(current_row) = ~test_parity_3(current_row);
      end
    end
  end

  test_parity_2 = test_A_times_message;
  test_parity_1 = false(M, 1);

  for row_index = 1:M
    if mod(sum(test_parity_3(S2_dependencies{row_index})), 2) ~= 0
      test_parity_2(row_index) = ~test_parity_2(row_index);
    end
    test_parity_1(row_index) = mod(sum(test_parity_3(P1_dependencies{row_index})), 2) ~= 0;
  end

  if test_last_percent < 100
    fprintf('Random test %d/%d progress: 100%%\n', test_index, random_test_count);
  end

  test_full_codeword = [test_message_bits, test_parity_1', test_parity_2', test_parity_3'];
  test_syndrome = mod(double(H) * double(test_full_codeword'), 2);
  test_passed = ~any(test_syndrome);
  all_tests_passed = all_tests_passed && test_passed;

  if test_passed
    fprintf('Random test %d/%d: PASS\n', test_index, random_test_count);
  else
    fprintf('Random test %d/%d: FAIL\n', test_index, random_test_count);
  end
end

if all_tests_passed
  fprintf('All validation tests passed.\n');
else
  error('At least one validation test failed.');
end
