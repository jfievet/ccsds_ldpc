% CCSDS 131.0-B-5 / Section 7.4.3 LDPC generator matrix builder.
% This script loads a precomputed parity-check matrix H and builds the
% corresponding generator matrix G over GF(2).

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

h_filename = sprintf('H_%s_%d.mat', strrep(rate, '/', '_'), block_length);
h_path_1 = fullfile('..', 'build_h', h_filename);
h_path_2 = fullfile('..', 'build_H', h_filename);
h_path_3 = fullfile('build_h', h_filename);
h_path_4 = fullfile('build_H', h_filename);

if exist(h_path_1, 'file')
  h_path = h_path_1;
elseif exist(h_path_2, 'file')
  h_path = h_path_2;
elseif exist(h_path_3, 'file')
  h_path = h_path_3;
elseif exist(h_path_4, 'file')
  h_path = h_path_4;
else
  error('Could not find %s in build_h/ or build_H/.', h_filename);
end

loaded_data = load(h_path);
if ~isfield(loaded_data, 'H')
  error('The file %s does not contain variable H.', h_path);
end

H = mod(loaded_data.H, 2) ~= 0;
[m, n] = size(H);

if mod(m, 3) ~= 0
  error('Unexpected H size: the number of rows must be 3*M.');
end

M = m / 3;
k = n - m;
k_blocks = k / M;

if mod(k, M) ~= 0
  error('Unexpected H size: k must be a multiple of M.');
end

if k_blocks ~= 2 && k_blocks ~= 4 && k_blocks ~= 8
  error('Unsupported H structure for Section 7.4.3.');
end

I = speye(M);
parity_1_columns = (k + 1):(k + M);
parity_2_columns = (k + M + 1):(k + 2 * M);
parity_3_columns = (k + 2 * M + 1):(k + 3 * M);

row_1_parity_1 = sparse(double(H(1:M, parity_1_columns)));
row_1_parity_2 = sparse(double(H(1:M, parity_2_columns)));
row_1_parity_3 = sparse(double(H(1:M, parity_3_columns)));

row_2_info = sparse(double(H(M + 1:2 * M, 1:k)));
row_2_parity_1 = sparse(double(H(M + 1:2 * M, parity_1_columns)));
row_2_parity_2 = sparse(double(H(M + 1:2 * M, parity_2_columns)));
row_2_parity_3 = sparse(double(H(M + 1:2 * M, parity_3_columns)));

row_3_info = sparse(double(H(2 * M + 1:3 * M, 1:k)));
row_3_parity_1 = sparse(double(H(2 * M + 1:3 * M, parity_1_columns)));
row_3_parity_2 = sparse(double(H(2 * M + 1:3 * M, parity_2_columns)));
row_3_parity_3 = sparse(double(H(2 * M + 1:3 * M, parity_3_columns)));

if nnz(row_1_parity_1 - I) ~= 0
  error('Unexpected Section 7.4.3 structure: row-1 parity block 1 must be identity.');
end
if nnz(row_1_parity_2) ~= 0
  error('Unexpected Section 7.4.3 structure: row-1 parity block 2 must be zero.');
end
if nnz(row_2_parity_1) ~= 0
  error('Unexpected Section 7.4.3 structure: row-2 parity block 1 must be zero.');
end
if nnz(row_2_parity_2 - I) ~= 0
  error('Unexpected Section 7.4.3 structure: row-2 parity block 2 must be identity.');
end
if nnz(row_3_parity_1) ~= 0
  error('Unexpected Section 7.4.3 structure: row-3 parity block 1 must be zero.');
end
if nnz(row_3_parity_3 - I) ~= 0
  error('Unexpected Section 7.4.3 structure: row-3 parity block 3 must be identity.');
end

S1 = mod(row_1_parity_3 + I, 2);
S2 = row_2_parity_3;
S4 = row_3_parity_2;

% Section 7.4.3 solves the third parity block first:
%   p2 = A*u + S2*p3
%   p3 = B*u + S4*p2
% so (I + S4*S2) * p3 = (B + S4*A) * u over GF(2).
A_coeff = row_2_info;
B_coeff = row_3_info;
p3_rhs = xor(mod(double(S4) * double(A_coeff), 2) ~= 0, B_coeff ~= 0);

T = mod(I + mod(S4 * S2, 2), 2);
Aug = [full(T) ~= 0, p3_rhs ~= 0];
augmented_columns = columns(Aug);

fprintf('Solving Section 7.4.3 GF(2) system of size %d x %d...\n', rows(T), columns(T));

progress_total_steps = 2 * M;
last_reported_percent = -1;

for pivot = 1:M
  current_percent = floor((100 * pivot) / progress_total_steps);
  if current_percent > last_reported_percent
    fprintf('Progress: %d%%\n', current_percent);
    last_reported_percent = current_percent;
  end

  pivot_offset = find(Aug(pivot:M, pivot), 1);
  if isempty(pivot_offset)
    error('Generator construction failed: singular parity block matrix.');
  end

  pivot_row = pivot + pivot_offset - 1;
  if pivot_row ~= pivot
    temporary_row = Aug(pivot, :);
    Aug(pivot, :) = Aug(pivot_row, :);
    Aug(pivot_row, :) = temporary_row;
  end

  if pivot < M
    rows_below = find(Aug(pivot + 1:M, pivot)) + pivot;
    for row_index = 1:length(rows_below)
      current_row = rows_below(row_index);
      Aug(current_row, pivot:augmented_columns) = xor(Aug(current_row, pivot:augmented_columns), ...
                                                       Aug(pivot, pivot:augmented_columns));
    end
  end
end

for pivot = M:-1:1
  current_percent = floor((100 * (2 * M - pivot + 1)) / progress_total_steps);
  if current_percent > last_reported_percent
    fprintf('Progress: %d%%\n', current_percent);
    last_reported_percent = current_percent;
  end

  if pivot > 1
    rows_above = find(Aug(1:pivot - 1, pivot));
    for row_index = 1:length(rows_above)
      current_row = rows_above(row_index);
      Aug(current_row, pivot:augmented_columns) = xor(Aug(current_row, pivot:augmented_columns), ...
                                                       Aug(pivot, pivot:augmented_columns));
    end
  end
end

if last_reported_percent < 100
  fprintf('Progress: 100%%\n');
end

p3_coeff = Aug(:, M + 1:augmented_columns);
p2_coeff = xor(A_coeff ~= 0, mod(double(S2) * double(p3_coeff), 2) ~= 0);
p1_coeff = mod(double(mod(I + S1, 2)) * double(p3_coeff), 2) ~= 0;

G_identity = false(k, k);
G_identity(1:k + 1:k * k) = true;
G = [G_identity, p1_coeff', p2_coeff', p3_coeff'];

syndrome = mod(double(H) * double(G'), 2);
if any(syndrome(:))
  error('Generator verification failed: H * G'' is not zero over GF(2).');
end

image_filename = sprintf('G_%s_%d.png', strrep(rate, '/', '_'), block_length);
figure('visible', 'off');
spy(G, 4);
title(sprintf('CCSDS LDPC G, rate %s, block length %d', rate, block_length));
xlabel('Column');
ylabel('Row');
print(image_filename, '-dpng');
close(gcf);

mat_filename = sprintf('G_%s_%d.mat', strrep(rate, '/', '_'), block_length);
save(mat_filename, 'G', 'rate', 'block_length', 'M');

fprintf('Built CCSDS LDPC G for rate %s, block length %d.\n', rate, block_length);
fprintf('G size: %d x %d\n', rows(G), columns(G));
fprintf('Loaded H from %s\n', h_path);
fprintf('Saved G plot to %s\n', image_filename);
fprintf('Saved G matrix to %s\n', mat_filename);
