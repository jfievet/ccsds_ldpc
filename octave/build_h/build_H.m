% CCSDS 131.0-B-5 / Section 7.4 LDPC parity-check matrix builder.
% This script builds the full parity-check matrix H, including the last
% punctured M columns defined by Section 7.4.2.5.

% Manual parameter selection.
rate = '1/2';
block_length = 16384;

% Section 7.4 supports:
%   rates: 1/2, 2/3, 4/5
%   information block lengths: 1024, 4096, 16384

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
  error('Unsupported rate. Use 1/2, 2/3, or 4/5.');
end

supported_M = [128, 256, 512, 1024, 2048, 4096, 8192];
tuple_column = find(supported_M == M, 1);
if isempty(tuple_column)
  error('Unsupported submatrix size M.');
end

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

if mod(M, 4) ~= 0
  error('Section 7.4 requires M divisible by 4.');
end

I = speye(M);
Z = sparse(M, M);
quarter_M = M / 4;

Pi = cell(26, 1);
for k = 1:26
  phi_values = [phi0(k, tuple_column), phi1(k, tuple_column), ...
                phi2(k, tuple_column), phi3(k, tuple_column)];
  row_index = zeros(M, 1);
  column_index = zeros(M, 1);
  for i = 0:(M - 1)
    j = floor((4 * i) / M);
    pi_value = quarter_M * mod(theta(k) + j, 4) + mod(phi_values(j + 1) + i, quarter_M);
    row_index(i + 1) = i + 1;
    column_index(i + 1) = pi_value + 1;
  end
  Pi{k} = sparse(row_index, column_index, 1, M, M);
end

% The non-identity CCSDS blocks are modulo-2 sums of permutation matrices.
S1  = Pi{1};
S2  = mod(Pi{2}  + Pi{3}  + Pi{4},  2);
S3  = mod(Pi{5}  + Pi{6},          2);
S4  = mod(Pi{7}  + Pi{8},          2);
S5  = mod(Pi{9}  + Pi{10} + Pi{11}, 2);
S6  = mod(Pi{12} + Pi{13} + Pi{14}, 2);
S7  = mod(Pi{15} + Pi{16} + Pi{17}, 2);
S8  = mod(Pi{18} + Pi{19} + Pi{20}, 2);
S9  = mod(Pi{21} + Pi{22} + Pi{23}, 2);
S10 = mod(Pi{24} + Pi{25} + Pi{26}, 2);

% Section 7.4.2.2: rate-1/2 parity-check matrix.
H_half = [Z,  Z,  I,  Z,      mod(I + S1, 2);
          I,  I,  Z,  I,      S2;
          I,  S3, Z,  S4,     I];

if strcmp(rate, '1/2')
  H = sparse(mod(H_half, 2));
elseif strcmp(rate, '2/3')
  % Section 7.4.2.3: rate-2/3 parity-check matrix.
  H = [Z,  Z,  Z,  Z,  I,  Z,      mod(I + S1, 2);
       S5, I,  I,  I,  Z,  I,      S2;
       I,  S6, I,  S3, Z,  S4,     I];
  H = sparse(mod(H, 2));
elseif strcmp(rate, '4/5')
  % Section 7.4.2.3: rate-4/5 parity-check matrix, expressed as a 6-column
  % extension prepended to the rate-1/2 structure.
  H = [Z,   Z,   Z,   Z,   Z,   Z,   Z,  Z,  I,  Z,      mod(I + S1, 2);
       S9,  S7,  S5,  S6,  I,   I,   I,  I,  Z,  I,      S2;
       S10, S8,  Z,   Z,   I,   I,   I,  S3, Z,  S4,     I];
  H = sparse(mod(H, 2));
else
  error('Unsupported rate.');
end

fprintf('Built CCSDS LDPC H for rate %s, block length %d.\n', rate, block_length);
fprintf('H size: %d x %d\n', rows(H), columns(H));
fprintf('Submatrix size M: %d\n', M);
fprintf('Last %d columns are the punctured columns defined by Section 7.4.2.5.\n', M);

% Save a PNG showing the sparsity pattern of H in the current folder.
image_filename = sprintf('H_%s_%d.png', strrep(rate, '/', '_'), block_length);
figure('visible', 'off');
spy(H, 4);
title(sprintf('CCSDS LDPC H, rate %s, block length %d', rate, block_length));
xlabel('Column');
ylabel('Row');
print(image_filename, '-dpng');
close(gcf);

fprintf('Saved H plot to %s\n', image_filename);
