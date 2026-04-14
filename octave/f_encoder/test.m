% Test ldpc_encoding by checking the output codeword against the corresponding H matrix.

clear all;
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
constants_path = fullfile('..', 'encoder', constants_filename);
h_filename = sprintf('H_%s.mat', matrix_suffix);
h_path_candidates = { ...
  fullfile('..', 'build_h', h_filename), ...
  fullfile('..', 'build_H', h_filename) ...
};

fprintf('Selected configuration: rate %s, block length %d\n', rate, block_length);
fprintf('Checking constants file: %s\n', constants_path);

if ~exist(constants_path, 'file')
  error('Could not find %s. Generate the matching constants in ../encoder first.', constants_path);
end

loaded_constants = load(constants_path);
if ~isfield(loaded_constants, 'information_length')
  error('The file %s does not contain information_length.', constants_path);
end

information_length = loaded_constants.information_length;

rand('seed', 7);
message = rand(1, information_length) >= 0.5;

fprintf('Generated random message with %d bits.\n', information_length);
fprintf('Calling ldpc_encoding...\n');
encoder_codeword = ldpc_encoding(message, rate, block_length);

fprintf('Looking for parity-check matrix %s\n', h_filename);
h_path = '';
for path_index = 1:length(h_path_candidates)
  if exist(h_path_candidates{path_index}, 'file')
    h_path = h_path_candidates{path_index};
    break;
  end
end

if isempty(h_path)
  error('Could not find %s in ../build_h or ../build_H.', h_filename);
end

loaded_h = load(h_path);
if ~isfield(loaded_h, 'H')
  error('The file %s does not contain variable H.', h_path);
end

H = mod(double(full(loaded_h.H)), 2);
fprintf('Loaded parity-check matrix from %s\n', h_path);

if columns(H) ~= length(encoder_codeword)
  error('H column count %d does not match codeword length %d.', columns(H), length(encoder_codeword));
end

syndrome = mod(H * double(encoder_codeword(:)), 2);

fprintf('Codeword length: %d bits\n', length(encoder_codeword));
fprintf('Syndrome weight: %d\n', nnz(syndrome));

if any(syndrome)
  fprintf('Parity-check result: FAIL\n');
  fprintf('The encoded codeword does not satisfy H * c'' = 0 mod 2.\n');
else
  fprintf('Parity-check result: PASS\n');
  fprintf('The encoded codeword satisfies H * c'' = 0 mod 2.\n');
end
