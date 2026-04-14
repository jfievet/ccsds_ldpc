% CCSDS 131.0-B-5 / Section 7.4 constant generation.
% This script reuses the existing build_H artifact and saves reusable
% encoding constants for the selected CCSDS configuration.

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
  error('Could not find %s. Generate it first with octave/build_h/build_H.m.', h_filename);
end

loaded_h = load(h_path);
if ~isfield(loaded_h, 'H')
  error('The file %s does not contain variable H.', h_path);
end

H = mod(full(loaded_h.H), 2) ~= 0;
[parity_equation_count, total_length] = size(H);

if mod(parity_equation_count, 3) ~= 0
  error('Unexpected H size: the number of rows must be 3*M.');
end

M = parity_equation_count / 3;
information_length = total_length - parity_equation_count;
transmitted_length = information_length + 2 * M;
information_block_count = information_length / M;

if mod(information_length, M) ~= 0
  error('Unexpected H size: k must be a multiple of M.');
end

if information_block_count ~= 2 && information_block_count ~= 4 && information_block_count ~= 8
  error('Unsupported Section 7.4 structure for the selected H.');
end

I = speye(M) ~= 0;

info_columns = 1:information_length;
parity_1_columns = (information_length + 1):(information_length + M);
parity_2_columns = (information_length + M + 1):(information_length + 2 * M);
parity_3_columns = (information_length + 2 * M + 1):(information_length + 3 * M);

row_1 = H(1:M, :);
row_2 = H(M + 1:2 * M, :);
row_3 = H(2 * M + 1:3 * M, :);

% CCSDS Section 7.4 parity block layout used by all supported rates:
%   row 1 parity blocks: [I, 0, I+S1]
%   row 2 parity blocks: [0, I, S2]
%   row 3 parity blocks: [0, S4, I]
row_1_parity_1 = row_1(:, parity_1_columns);
row_1_parity_2 = row_1(:, parity_2_columns);
row_2_parity_1 = row_2(:, parity_1_columns);
row_2_parity_2 = row_2(:, parity_2_columns);
row_3_parity_1 = row_3(:, parity_1_columns);
row_3_parity_3 = row_3(:, parity_3_columns);

if any(any(xor(row_1_parity_1, I)))
  error('Unexpected H structure: row-1 parity block 1 must be identity.');
end
if any(row_1_parity_2(:))
  error('Unexpected H structure: row-1 parity block 2 must be zero.');
end
if any(row_2_parity_1(:))
  error('Unexpected H structure: row-2 parity block 1 must be zero.');
end
if any(any(xor(row_2_parity_2, I)))
  error('Unexpected H structure: row-2 parity block 2 must be identity.');
end
if any(row_3_parity_1(:))
  error('Unexpected H structure: row-3 parity block 1 must be zero.');
end
if any(any(xor(row_3_parity_3, I)))
  error('Unexpected H structure: row-3 parity block 3 must be identity.');
end

row_1_info = row_1(:, info_columns);
row_2_info = row_2(:, info_columns);
row_3_info = row_3(:, info_columns);

if any(row_1_info(:))
  error('Unexpected H structure: row-1 information block must be zero for all supported rates.');
end

A = row_2_info;
B = row_3_info;
P1_matrix = row_1(:, parity_3_columns);
S2 = row_2(:, parity_3_columns);
S4 = row_3(:, parity_2_columns);

% Section 7.4 parity solve order:
%   p2 = A*u + S2*p3
%   p3 = B*u + S4*p2
% so (I + S4*S2) * p3 = B*u + S4*(A*u) over GF(2).
T = mod(double(I) + mod(double(S4) * double(S2), 2), 2) ~= 0;

A_dependencies = cell(M, 1);
B_dependencies = cell(M, 1);
P1_dependencies = cell(M, 1);
S2_dependencies = cell(M, 1);
S4_dependencies = cell(M, 1);

fprintf('Building dependency tables...\n');
dependency_total_steps = M;
dependency_last_percent = -1;

for row_index = 1:M
  dependency_percent = floor((100 * row_index) / dependency_total_steps);
  if dependency_percent > dependency_last_percent
    fprintf('Dependency progress: %d%%\n', dependency_percent);
    dependency_last_percent = dependency_percent;
  end

  A_dependencies{row_index} = find(A(row_index, :));
  B_dependencies{row_index} = find(B(row_index, :));
  P1_dependencies{row_index} = find(P1_matrix(row_index, :));
  S2_dependencies{row_index} = find(S2(row_index, :));
  S4_dependencies{row_index} = find(S4(row_index, :));
end

working_T = T;
forward_swap_rows = zeros(M, 1);
forward_target_rows = cell(M, 1);
backward_target_rows = cell(M, 1);

fprintf('Computing GF(2) elimination schedule...\n');
elimination_total_steps = 2 * M;
elimination_last_percent = -1;

for pivot = 1:M
  elimination_percent = floor((100 * pivot) / elimination_total_steps);
  if elimination_percent > elimination_last_percent
    fprintf('Elimination progress: %d%%\n', elimination_percent);
    elimination_last_percent = elimination_percent;
  end

  pivot_offset = find(working_T(pivot:M, pivot), 1);
  if isempty(pivot_offset)
    error('Constant generation failed: singular p3 system.');
  end

  pivot_row = pivot + pivot_offset - 1;
  forward_swap_rows(pivot) = pivot_row;

  if pivot_row ~= pivot
    saved_row = working_T(pivot, :);
    working_T(pivot, :) = working_T(pivot_row, :);
    working_T(pivot_row, :) = saved_row;
  end

  target_rows = find(working_T(pivot + 1:M, pivot)) + pivot;
  forward_target_rows{pivot} = target_rows;
  for target_index = 1:length(target_rows)
    current_row = target_rows(target_index);
    working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), working_T(pivot, pivot:M));
  end
end

for pivot = M:-1:1
  elimination_percent = floor((100 * (2 * M - pivot + 1)) / elimination_total_steps);
  if elimination_percent > elimination_last_percent
    fprintf('Elimination progress: %d%%\n', elimination_percent);
    elimination_last_percent = elimination_percent;
  end

  target_rows = find(working_T(1:pivot - 1, pivot));
  backward_target_rows{pivot} = target_rows;
  for target_index = 1:length(target_rows)
    current_row = target_rows(target_index);
    working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), working_T(pivot, pivot:M));
  end
end

if dependency_last_percent < 100
  fprintf('Dependency progress: 100%%\n');
end

if elimination_last_percent < 100
  fprintf('Elimination progress: 100%%\n');
end

if any(any(xor(working_T, I)))
  error('Constant generation failed: elimination schedule did not reduce T to identity.');
end

save(constants_filename, ...
     'rate', 'block_length', 'information_length', 'transmitted_length', 'total_length', 'M', ...
     'A_dependencies', 'B_dependencies', 'P1_dependencies', 'S2_dependencies', 'S4_dependencies', ...
     'forward_swap_rows', 'forward_target_rows', 'backward_target_rows');

fprintf('Generated constants from %s\n', h_path);
fprintf('rate=%s, block_length=%d, k=%d, transmitted_length=%d, M=%d\n', ...
        rate, block_length, information_length, transmitted_length, M);
fprintf('Saved constants to %s\n', constants_filename);
