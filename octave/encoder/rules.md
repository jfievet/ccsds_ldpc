# Rules: 
## Environment Rules

### 1. Language
- The implementation must use **MATLAB-compatible syntax for Octave only**
- The code must run in **GNU Octave**
- Do not use MATLAB-only features that are unsupported in Octave

---

### 2. No Toolboxes
- Do **not** use any MATLAB or Octave toolboxes
- Only base language features are allowed
- Allowed:
  - basic matrix operations
  - indexing
  - control structures (`if`, `for`, `while`)
  - built-in core functions (e.g. `zeros`, `ones`, `speye`, `sparse`)

---

### 3. No Object-Oriented Programming
- Do **not** use:
  - `classdef`
  - objects
  - methods
- Only procedural / script-based coding is allowed

---

## Project Structure Rules

### 4. Single Root Folder Constraint
- All work must remain inside the **top-level LDPC main folder**
- Do **not**:
  - create files outside this folder
  - reference external directories
  - depend on system-specific paths

---

### 5. File Restrictions
- Only a **single `.m` file** is allowed for implementation
- No multi-file architecture
- No external helper scripts

---

### 6. No External Dependencies
- Do not import or use:
  - external libraries
  - downloaded code
  - third-party implementations

---

## Implementation Rules

### 7. Script-Based Execution
- The code must run as a **script**, not as a standalone function entry point
---

### 8. Deterministic Behavior
- The script must:
  - always produce the same output for the same inputs
  - not rely on randomness unless explicitly defined (not required here)

---

### 9. Manual Parameter Selection
- Parameters (rate and block size) must be:
  - defined inside the script
  - not passed via CLI, GUI, or external config

---

### 10. Path Safety
- Use only **relative paths** inside the project
- Do not use absolute paths
- Access to the PDF must assume:
  - it is located in a `pdf/` subfolder inside the main folder

---

## Code Quality Rules

### 11. Readability
- Use clear variable names
- Keep structure simple and flat
- Avoid unnecessary abstraction

---

### 12. Comments
- Add comments where logic depends on CCSDS Section 7.4
- Clearly indicate:
  - matrix construction steps
  - parameter selection logic

---

## Forbidden Practices

The following are strictly prohibited:
- Object-oriented code
- Toolboxes
- Multiple `.m` files
- External libraries
- Absolute file paths
- Writing outside the project folder
- Hidden dependencies
- No push on git

---

## Acceptance Criteria

The rules are satisfied if:
- The script runs in **plain GNU Octave**
- No toolbox is required
- Only one `.m` file exists
- All files remain inside the LDPC root folder
- The script executes without path or dependency issues