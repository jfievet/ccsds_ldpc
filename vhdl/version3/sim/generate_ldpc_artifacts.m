%generate_ldpc_artifacts('1/2', 1024, 'ldpc_encoder_1k_1_2', 123)

function generate_ldpc_artifacts(rate_text, block_length, output_prefix, seed)
  if nargin < 1 || isempty(rate_text)
    rate_text = '1/2';
  end

  if nargin < 2 || isempty(block_length)
    block_length = 1024;
  end

  if nargin < 3 || isempty(output_prefix)
    output_prefix = 'ldpc_encoder_1k_1_2';
  end

  if nargin < 4 || isempty(seed)
    seed = 1;
  end

  script_dir = fileparts(mfilename('fullpath'));
  python_script = fullfile(script_dir, 'generate_ldpc_artifacts.py');

  if ~exist(python_script, 'file')
    error('Could not find generator script %s', python_script);
  end

  command_text = sprintf('python "%s" --rate %s --block-length %d --output-prefix %s --seed %d', ...
                         python_script, rate_text, block_length, output_prefix, seed);
  status = system(command_text);
  if status ~= 0
    error('Artifact generation failed with status %d', status);
  end
end