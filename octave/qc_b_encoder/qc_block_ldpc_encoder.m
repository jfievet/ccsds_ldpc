function qc_block_ldpc_encoder()
  % QC block-based CCSDS LDPC encoder.
  % This function keeps the implementation FPGA-oriented by:
  %   1) deriving and caching ROM-like constants once per configuration
  %   2) encoding with block dependencies and GF(2) XOR operations only
  %   3) validating the produced codeword against the CCSDS parity matrix H
  %
  % FPGA partitioning used in this model:
  %   ROM / static configuration storage in FPGA:
  %     - selected code configuration metadata (rate, block length, k, M)
  %     - dependency tables A_dependencies, B_dependencies
  %     - dependency tables P1_dependencies, S2_dependencies, S4_dependencies
  %     - elimination schedule forward_swap_rows
  %     - elimination schedule forward_target_rows, backward_target_rows
  %   Not ROM / computed or streamed at run time in FPGA:
  %     - information_bits input payload
  %     - intermediate vectors A_times_message, B_times_message, rhs
  %     - parity vectors parity_1, parity_2, parity_3
  %     - transmitted_codeword and full_codeword
  %     - syndrome used here for software validation

  clc;

  script_dir = fileparts(mfilename('fullpath'));
  configuration_list = discover_configurations(script_dir);

  if isempty(configuration_list)
    error(['No CCSDS H_*.mat files were found. Expected them in sibling build_h/build_H ' ...
           'folders next to qc_b_encoder.']);
  end

  fprintf('Available CCSDS QC-LDPC configurations:\n');
  for configuration_index = 1:length(configuration_list)
    configuration = configuration_list(configuration_index);
    fprintf('  %d. rate %s, block length %d\n', ...
            configuration_index, configuration.rate, configuration.block_length);
  end

  selection = input(sprintf('Enter a number from 1 to %d: ', length(configuration_list)));
  if ~isscalar(selection) || selection ~= floor(selection) || ...
     selection < 1 || selection > length(configuration_list)
    error('Invalid selection.');
  end

  selected_configuration = configuration_list(selection);
  fprintf('\nSelected configuration: rate %s, block length %d\n', ...
          selected_configuration.rate, selected_configuration.block_length);
  fprintf('Using H file: %s\n', selected_configuration.h_path);

  constants_path = fullfile(script_dir, ...
                            sprintf('qc_ldpc_constants_%s_%d.mat', ...
                                    strrep(selected_configuration.rate, '/', '_'), ...
                                    selected_configuration.block_length));

  if exist(constants_path, 'file')
    fprintf('Loading cached ROM-equivalent constants: %s\n', constants_path);
    loaded_constants = load(constants_path);
    constants = normalize_constants_struct(loaded_constants);
  else
    fprintf('Cached ROM-equivalent constants not found. Deriving them from H...\n');
    loaded_h = load(selected_configuration.h_path);
    if ~isfield(loaded_h, 'H')
      error('The file %s does not contain variable H.', selected_configuration.h_path);
    end

    H = mod(full(loaded_h.H), 2) ~= 0;
    constants = build_constants_from_h(H, selected_configuration.rate, ...
                                       selected_configuration.block_length);

    % FPGA ROM content: precomputed dependency tables and elimination schedule.
    save(constants_path, '-struct', 'constants');
    fprintf('Saved derived ROM-equivalent constants to %s\n', constants_path);
  end

  loaded_h = load(selected_configuration.h_path);
  H = mod(full(loaded_h.H), 2) ~= 0;

  if constants.block_length ~= selected_configuration.block_length || ...
     ~strcmp(constants.rate, selected_configuration.rate)
    error('Cached constants do not match the selected configuration.');
  end

  fprintf('k = %d, transmitted length = %d, full internal length = %d, M = %d\n', ...
          constants.information_length, constants.transmitted_length, ...
          constants.total_length, constants.M);

  use_workspace_message = false;
  if evalin('base', 'exist(''message_bits'', ''var'')') == 1
    workspace_message = evalin('base', 'message_bits');
    if isvector(workspace_message) && numel(workspace_message) == constants.information_length
      use_workspace_message = true;
    else
      fprintf(['Ignoring workspace variable message_bits because its length does not match ' ...
               'the selected configuration.\n']);
    end
  end

  if use_workspace_message
    information_bits = reshape(workspace_message ~= 0, 1, constants.information_length);
    fprintf('Using caller-provided message_bits from base workspace as run-time FPGA input.\n');
  else
    % Not ROM: example run-time FPGA input when no external payload is preloaded.
    information_bits = mod(0:(constants.information_length - 1), 2) ~= 0;
    fprintf('Using deterministic default information bits.\n');
  end

  % Not ROM: actual encoding datapath execution using the precomputed constants.
  fprintf('Encoding with QC block schedule...\n');
  [transmitted_codeword, full_codeword, parity_1, parity_2, parity_3] = ...
    encode_qc_blocks(information_bits, constants);

  fprintf('Encoding completed.\n');
  fprintf('Parity block sizes: p1=%d, p2=%d, p3=%d\n', ...
          length(parity_1), length(parity_2), length(parity_3));
  fprintf('Transmitted systematic codeword length [m p1 p2]: %d\n', ...
          length(transmitted_codeword));
  fprintf('Full internal codeword length [m p1 p2 p3]: %d\n', length(full_codeword));

  fprintf('Validating H * c'' = 0 mod 2...\n');
  syndrome = mod(double(H) * double(full_codeword'), 2);
  syndrome_weight = nnz(syndrome);

  fprintf('Validation syndrome weight: %d\n', syndrome_weight);
  if syndrome_weight ~= 0
    error('Validation failed: the generated codeword does not satisfy H * c'' = 0 mod 2.');
  end

  fprintf('Validation PASSED.\n');
end

function configuration_list = discover_configurations(script_dir)
  search_directories = { ...
    fullfile(script_dir, '..', 'build_h'), ...
    fullfile(script_dir, '..', 'build_H') ...
  };

  configuration_list = struct('rate', {}, 'block_length', {}, 'h_path', {});

  for directory_index = 1:length(search_directories)
    current_directory = search_directories{directory_index};
    if ~exist(current_directory, 'dir')
      continue;
    end

    mat_files = dir(fullfile(current_directory, 'H_*.mat'));
    for file_index = 1:length(mat_files)
      file_name = mat_files(file_index).name;
      tokens = regexp(file_name, '^H_(\d+)_(\d+)_(\d+)\.mat$', 'tokens');
      if isempty(tokens)
        continue;
      end

      token_values = tokens{1};
      rate = sprintf('%s/%s', token_values{1}, token_values{2});
      block_length = str2double(token_values{3});
      file_path = fullfile(current_directory, file_name);

      already_present = false;
      for existing_index = 1:length(configuration_list)
        if strcmp(configuration_list(existing_index).rate, rate) && ...
           configuration_list(existing_index).block_length == block_length
          already_present = true;
          break;
        end
      end

      if ~already_present
        configuration_list(end + 1) = struct('rate', rate, ... %#ok<AGROW>
                                             'block_length', block_length, ...
                                             'h_path', file_path);
      end
    end
  end

  if isempty(configuration_list)
    return;
  end

  sort_keys = zeros(length(configuration_list), 2);
  for index = 1:length(configuration_list)
    sort_keys(index, 1) = rate_sort_key(configuration_list(index).rate);
    sort_keys(index, 2) = configuration_list(index).block_length;
  end

  [~, order] = sortrows(sort_keys, [1 2]);
  configuration_list = configuration_list(order);
end

function key = rate_sort_key(rate)
  if strcmp(rate, '1/2')
    key = 1;
  elseif strcmp(rate, '2/3')
    key = 2;
  elseif strcmp(rate, '4/5')
    key = 3;
  else
    key = 99;
  end
end

function constants = build_constants_from_h(H, rate, block_length)
  % This function computes the static data that would live in FPGA ROMs or
  % initialization memories for one CCSDS configuration.

  [parity_equation_count, total_length] = size(H);

  if mod(parity_equation_count, 3) ~= 0
    error('Unexpected H size: number of rows must be 3*M.');
  end

  M = parity_equation_count / 3;
  information_length = total_length - parity_equation_count;
  transmitted_length = information_length + 2 * M;

  if mod(information_length, M) ~= 0
    error('Unexpected H size: k must be a multiple of M.');
  end

  I = speye(M) ~= 0;

  info_columns = 1:information_length;
  parity_1_columns = (information_length + 1):(information_length + M);
  parity_2_columns = (information_length + M + 1):(information_length + 2 * M);
  parity_3_columns = (information_length + 2 * M + 1):(information_length + 3 * M);

  row_1 = H(1:M, :);
  row_2 = H(M + 1:2 * M, :);
  row_3 = H(2 * M + 1:3 * M, :);

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
    error('Unexpected H structure: row-1 information block must be zero.');
  end

  A = row_2_info;
  B = row_3_info;
  P1_matrix = row_1(:, parity_3_columns);
  S2 = row_2(:, parity_3_columns);
  S4 = row_3(:, parity_2_columns);

  T = mod(double(I) + mod(double(S4) * double(S2), 2), 2) ~= 0;

  % ROM content: per-row dependency tables that drive XOR-reduction networks.
  A_dependencies = cell(M, 1);
  B_dependencies = cell(M, 1);
  P1_dependencies = cell(M, 1);
  S2_dependencies = cell(M, 1);
  S4_dependencies = cell(M, 1);

  fprintf('Building block dependency tables...\n');
  dependency_total_steps = M;
  dependency_last_percent = -1;
  for row_index = 1:M
    dependency_percent = floor((100 * row_index) / dependency_total_steps);
    if dependency_percent > dependency_last_percent
      fprintf('Dependency table progress: %d%%\n', dependency_percent);
      dependency_last_percent = dependency_percent;
    end

    A_dependencies{row_index} = find(A(row_index, :));
    B_dependencies{row_index} = find(B(row_index, :));
    P1_dependencies{row_index} = find(P1_matrix(row_index, :));
    S2_dependencies{row_index} = find(S2(row_index, :));
    S4_dependencies{row_index} = find(S4(row_index, :));
  end

  working_T = T;

  % ROM content: precomputed solve schedule for the p3 linear system.
  % In hardware this would normally be stored as control words, not recomputed.
  forward_swap_rows = zeros(M, 1);
  forward_target_rows = cell(M, 1);
  backward_target_rows = cell(M, 1);

  fprintf('Building GF(2) elimination schedule...\n');
  elimination_total_steps = 2 * M;
  elimination_last_percent = -1;
  for pivot = 1:M
    elimination_percent = floor((100 * pivot) / elimination_total_steps);
    if elimination_percent > elimination_last_percent
      fprintf('Elimination schedule progress: %d%%\n', elimination_percent);
      elimination_last_percent = elimination_percent;
    end

    pivot_offset = find(working_T(pivot:M, pivot), 1);
    if isempty(pivot_offset)
      error('Constant generation failed: singular p3 solve matrix.');
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
      working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), ...
                                            working_T(pivot, pivot:M));
    end
  end

  for pivot = M:-1:1
    elimination_percent = floor((100 * (2 * M - pivot + 1)) / elimination_total_steps);
    if elimination_percent > elimination_last_percent
      fprintf('Elimination schedule progress: %d%%\n', elimination_percent);
      elimination_last_percent = elimination_percent;
    end

    target_rows = find(working_T(1:pivot - 1, pivot));
    backward_target_rows{pivot} = target_rows;
    for target_index = 1:length(target_rows)
      current_row = target_rows(target_index);
      working_T(current_row, pivot:M) = xor(working_T(current_row, pivot:M), ...
                                            working_T(pivot, pivot:M));
    end
  end

  if dependency_last_percent < 100
    fprintf('Dependency table progress: 100%%\n');
  end
  if elimination_last_percent < 100
    fprintf('Elimination schedule progress: 100%%\n');
  end

  if any(any(xor(working_T, I)))
    error('Constant generation failed: elimination schedule did not reduce the solve matrix to identity.');
  end

  constants = struct( ...
    'rate', rate, ...
    'block_length', block_length, ...
    'information_length', information_length, ...
    'transmitted_length', transmitted_length, ...
    'total_length', total_length, ...
    'M', M, ...
    'A_dependencies', {A_dependencies}, ...
    'B_dependencies', {B_dependencies}, ...
    'P1_dependencies', {P1_dependencies}, ...
    'S2_dependencies', {S2_dependencies}, ...
    'S4_dependencies', {S4_dependencies}, ...
    'forward_swap_rows', forward_swap_rows, ...
    'forward_target_rows', {forward_target_rows}, ...
    'backward_target_rows', {backward_target_rows});
end

function constants = normalize_constants_struct(loaded_constants)
  required_names = { ...
    'rate', 'block_length', 'information_length', 'transmitted_length', 'total_length', 'M', ...
    'A_dependencies', 'B_dependencies', 'P1_dependencies', 'S2_dependencies', 'S4_dependencies', ...
    'forward_swap_rows', 'forward_target_rows', 'backward_target_rows' ...
  };

  for name_index = 1:length(required_names)
    current_name = required_names{name_index};
    if ~isfield(loaded_constants, current_name)
      error('Cached constants are missing %s.', current_name);
    end
  end

  constants = loaded_constants;
end

function [transmitted_codeword, full_codeword, parity_1, parity_2, parity_3] = ...
    encode_qc_blocks(information_bits, constants)
  M = constants.M;

  % ROM inputs used by the datapath:
  %   constants.A_dependencies
  %   constants.B_dependencies
  %   constants.P1_dependencies
  %   constants.S2_dependencies
  %   constants.S4_dependencies
  %   constants.forward_swap_rows
  %   constants.forward_target_rows
  %   constants.backward_target_rows
  %
  % Not ROM: all vectors below are generated for each encoded frame.
  % FPGA real-time datapath: block-wise XOR accumulation from message to A*u and B*u.
  A_times_message = false(M, 1);
  B_times_message = false(M, 1);

  for row_index = 1:M
    A_times_message(row_index) = mod(sum(information_bits(constants.A_dependencies{row_index})), 2) ~= 0;
    B_times_message(row_index) = mod(sum(information_bits(constants.B_dependencies{row_index})), 2) ~= 0;
  end

  rhs = B_times_message;
  for row_index = 1:M
    % Not ROM: rhs is updated per frame from the current message/parity state.
    if mod(sum(A_times_message(constants.S4_dependencies{row_index})), 2) ~= 0
      rhs(row_index) = ~rhs(row_index);
    end
  end

  parity_3 = rhs;

  for pivot = 1:M
    % ROM drives the solve order; parity_3 itself is run-time state.
    pivot_row = constants.forward_swap_rows(pivot);
    if pivot_row ~= pivot
      saved_bit = parity_3(pivot);
      parity_3(pivot) = parity_3(pivot_row);
      parity_3(pivot_row) = saved_bit;
    end

    if parity_3(pivot)
      target_rows = constants.forward_target_rows{pivot};
      for target_index = 1:length(target_rows)
        current_row = target_rows(target_index);
        parity_3(current_row) = ~parity_3(current_row);
      end
    end
  end

  for pivot = M:-1:1
    if parity_3(pivot)
      target_rows = constants.backward_target_rows{pivot};
      for target_index = 1:length(target_rows)
        current_row = target_rows(target_index);
        parity_3(current_row) = ~parity_3(current_row);
      end
    end
  end

  parity_2 = A_times_message;
  parity_1 = false(M, 1);

  for row_index = 1:M
    % Not ROM: final parity blocks are computed for the current frame only.
    if mod(sum(parity_3(constants.S2_dependencies{row_index})), 2) ~= 0
      parity_2(row_index) = ~parity_2(row_index);
    end
    parity_1(row_index) = mod(sum(parity_3(constants.P1_dependencies{row_index})), 2) ~= 0;
  end

  % Not ROM: output buffers for the current encoded frame.
  transmitted_codeword = [information_bits, parity_1', parity_2'];
  full_codeword = [information_bits, parity_1', parity_2', parity_3'];
end
