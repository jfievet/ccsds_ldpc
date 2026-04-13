% LDPC encode/decode verification script.
% This script loads a matching CCSDS generator matrix G and parity-check
% matrix H, encodes a deterministic message, and verifies that the syndrome
% is zero under ideal transmission conditions.

clear;
clc;

available_rates = {'1/2', '2/3', '4/5'};
available_block_lengths = [1024, 4096, 16384];
configuration_count = 0;
configuration_rates = cell(9, 1);
configuration_block_lengths = zeros(9, 1);
configuration_g_paths = cell(9, 1);
configuration_h_paths = cell(9, 1);

fprintf('Available CCSDS LDPC configurations:\n');
for rate_index = 1:length(available_rates)
  for length_index = 1:length(available_block_lengths)
    configuration_count = configuration_count + 1;
    current_rate = available_rates{rate_index};
    current_block_length = available_block_lengths(length_index);
    matrix_suffix = sprintf('%s_%d', strrep(current_rate, '/', '_'), current_block_length);
    current_g_path = fullfile('..', 'build_g', sprintf('G_%s.mat', matrix_suffix));
    current_h_path = fullfile('..', 'build_h', sprintf('H_%s.mat', matrix_suffix));

    configuration_rates{configuration_count} = current_rate;
    configuration_block_lengths(configuration_count) = current_block_length;
    configuration_g_paths{configuration_count} = current_g_path;
    configuration_h_paths{configuration_count} = current_h_path;

    if exist(current_g_path, 'file')
      availability_text = 'G available';
    else
      availability_text = 'G missing';
    end

    fprintf('  %d. rate %s, block length %d (%s)\n', ...
            configuration_count, current_rate, current_block_length, availability_text);
  end
end

selection = input('\nEnter a number from 1 to 9: ');

if isempty(selection) || ~isscalar(selection) || selection ~= floor(selection) || ...
   selection < 1 || selection > configuration_count
  error('Invalid selection. Choose an integer from 1 to 9.');
end

selected_rate = configuration_rates{selection};
selected_block_length = configuration_block_lengths(selection);
g_path = configuration_g_paths{selection};
h_path = configuration_h_paths{selection};

fprintf('\nSelected configuration:\n');
fprintf('  rate %s, block length %d\n\n', selected_rate, selected_block_length);

if ~exist(g_path, 'file')
  error('Generator matrix file not found for the selected configuration: %s', g_path);
end

if ~exist(h_path, 'file')
  error('Parity-check matrix file not found for the selected configuration: %s', h_path);
end

loaded_g = load(g_path);
loaded_h = load(h_path);

if ~isfield(loaded_g, 'G')
  error('File %s does not contain variable G.', g_path);
end

if ~isfield(loaded_h, 'H')
  error('File %s does not contain variable H.', h_path);
end

G = mod(double(full(loaded_g.G)), 2);
H = mod(double(full(loaded_h.H)), 2);

[k, n] = size(G);
[m, h_columns] = size(H);

if h_columns ~= n
  error('Matrix size mismatch: G has %d columns but H has %d columns.', n, h_columns);
end

generator_check = mod(H * G', 2);
if any(generator_check(:) ~= 0)
  error('Loaded matrices are not paired correctly: H * G'' is not zero over GF(2).');
end

% Use a deterministic information pattern so repeated runs always produce
% the same encoded word for the same configuration.
message = mod(0:(k - 1), 2);

encoded_word = mod(message * G, 2);
received_word = encoded_word;
##received_word(1) = mod(received_word(1)+1,2);

% For the Section 7.4 generator built in build_g, G is systematic:
% the first k columns are the identity block, so the information bits can
% be read back directly when no error is detected.
decoded_message = received_word(1:k);
syndrome = mod(H * received_word', 2);

fprintf('Loaded G from %s\n', g_path);
fprintf('Loaded H from %s\n', h_path);
fprintf('Message length: %d bits\n', k);
fprintf('Codeword length: %d bits\n', n);
fprintf('Parity equations: %d\n', m);

if any(syndrome(:) ~= 0)
  fprintf('An error occurred: non-zero syndrome detected.\n');
else
  if any(decoded_message ~= message)
    fprintf('An error occurred: decoded message does not match the original message.\n');
  else
    fprintf('No errors were detected.\n');
  end
end

% Save the number of ones per G column to estimate the XOR cost associated
% with each encoded bit, especially the parity columns.
column_weights = sum(G ~= 0, 1);
log_path = 'log.txt';
log_file = fopen(log_path, 'w');

if log_file == -1
  error('Could not open log file for writing: %s', log_path);
end

fprintf(log_file, 'LDPC G column weights\n');
fprintf(log_file, 'rate=%s\n', selected_rate);
fprintf(log_file, 'block_length=%d\n', selected_block_length);
fprintf(log_file, 'message_length=%d\n', k);
fprintf(log_file, 'codeword_length=%d\n', n);
fprintf(log_file, '\n');
fprintf(log_file, 'column_index ones_count xor_count\n');

for column_index = 1:n
  xor_count = column_weights(column_index);
  if xor_count > 0
    xor_count = xor_count - 1;
  end
  fprintf(log_file, '%d %d %d\n', column_index, column_weights(column_index), xor_count);
end

fclose(log_file);
fprintf('Saved G column weights to %s\n', log_path);
