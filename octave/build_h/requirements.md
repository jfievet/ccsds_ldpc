# Requirements: CCSDS LDPC H Matrix Build

## Objective
Create a build artifact that generates the LDPC parity-check matrix `H` from the CCSDS 131.0-B-5 specification.

The implementation must:
- open and use the document `CCSDS 131.0-B-5` located in the `pdf` folder
- use all relevant information from **Section 7.4**
- generate the LDPC parity-check matrix `H`
- support selectable code rate and block length
- be implemented as **one single Octave `.m` file**
- not be split into multiple files
- not be implemented as a callable function API unless only used internally inside the same file
- produce the `H` matrix directly when the script is run

---

## Source Reference
Input reference document:
- `pdf/CCSDS 131.0-B-5.pdf`

Required section:
- **Section 7.4**

The implementation must follow the definitions, tables, structure, circulant sizes, offsets, and construction rules given in Section 7.4.

---

## Scope
The single Octave file must support the following LDPC configurations:

### Supported rates
- `1/2`
- `2/3`
- `4/5`

### Supported block lengths
- `1024` (`1k`)
- `4096` (`4k`)
- `16384` (`16k`)

This creates support for all combinations of:
- `1/2, 1024`
- `1/2, 4096`
- `1/2, 16384`
- `2/3, 1024`
- `2/3, 4096`
- `2/3, 16384`
- `4/5, 1024`
- `4/5, 4096`
- `4/5, 16384`

---

## File Requirement
Deliver exactly one Octave file, for example:
- `build_H.m`

This file must:
- contain the full logic needed to generate `H`
- contain parameter selection inside the file
- run as a script
- create `H` in the workspace when executed

The file must not depend on any additional project `.m` files.

---

## Parameter Selection
The script must provide a simple way to select:
- code rate
- block length

Example script parameters near the top of the file:
```matlab
rate = '1/2';
block_length = 1024;