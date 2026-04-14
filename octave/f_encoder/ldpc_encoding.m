function codeword = ldpc_encoding(message, code_rate, block_size)
% LDPC encoder based on precomputed constants from the neighboring encoder folder.
% The returned codeword is the full systematic codeword [m p1 p2 p3].

  if nargin ~= 3
    error('Usage: codeword = ldpc_encoding(message, code_rate, block_size)');
  end

  if ischar(code_rate)
    normalized_rate = code_rate;
  elseif isstring(code_rate) && isscalar(code_rate)
    normalized_rate = char(code_rate);
  else
    error('code_rate must be a character vector or scalar string, for example ''1/2''.');
  end

  if ~isscalar(block_size) || block_size ~= floor(block_size)
    error('block_size must be an integer scalar.');
  end

  matrix_suffix = sprintf('%s_%d', strrep(normalized_rate, '/', '_'), block_size);
  constants_filename = sprintf('ldpc_constants_%s.mat', matrix_suffix);
  constants_path = fullfile('..', 'encoder', constants_filename);

  fprintf('LDPC encoding started.\n');
  fprintf('Requested configuration: rate %s, block length %d\n', normalized_rate, block_size);
  fprintf('Loading constants from %s\n', constants_path);

  if ~exist(constants_path, 'file')
    error('Could not find %s.', constants_path);
  end

  loaded_constants = load(constants_path);
  required_constant_names = { ...
    'rate', 'block_length', 'information_length', 'transmitted_length', 'total_length', 'M', ...
    'A_dependencies', 'B_dependencies', 'P1_dependencies', 'S2_dependencies', 'S4_dependencies', ...
    'forward_swap_rows', 'forward_target_rows', 'backward_target_rows' ...
  };

  for name_index = 1:length(required_constant_names)
    if ~isfield(loaded_constants, required_constant_names{name_index})
      error('The file %s is missing %s.', constants_path, required_constant_names{name_index});
    end
  end

  if ~strcmp(loaded_constants.rate, normalized_rate) || loaded_constants.block_length ~= block_size
    error('The constants in %s do not match the requested configuration.', constants_path);
  end

  information_length = loaded_constants.information_length;
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

  if ~isvector(message) || numel(message) ~= information_length
    error('message must contain exactly %d binary values for rate %s, block length %d.', ...
          information_length, normalized_rate, block_size);
  end

  message_bits = reshape(message ~= 0, 1, information_length);
  fprintf('Message length: %d bits\n', information_length);

  A_times_message = false(M, 1);
  B_times_message = false(M, 1);

  for row_index = 1:M
    A_times_message(row_index) = mod(sum(message_bits(A_dependencies{row_index})), 2) ~= 0;
    B_times_message(row_index) = mod(sum(message_bits(B_dependencies{row_index})), 2) ~= 0;
  end

  rhs = B_times_message;
  for row_index = 1:M
    if mod(sum(A_times_message(S4_dependencies{row_index})), 2) ~= 0
      rhs(row_index) = ~rhs(row_index);
    end
  end

  parity_3 = rhs;
  for pivot = 1:M
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

  codeword = [message_bits, parity_1', parity_2', parity_3'];

  fprintf('Codeword length: %d bits\n', length(codeword));
  fprintf('LDPC encoding completed.\n');
end
