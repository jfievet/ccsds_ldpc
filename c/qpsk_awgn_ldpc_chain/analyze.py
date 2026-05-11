import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import LogLocator, LogFormatterMathtext

# ============================================================
# Configuration
# ============================================================

FILES = [
    "ber_result_12_1k.txt",
    "ber_result_12_4k.txt",
    "ber_result_12_16k.txt",
    "ber_result_23_1k.txt",
    "ber_result_23_4k.txt",
    "ber_result_23_16k.txt",
    "ber_result_45_1k.txt",
    "ber_result_45_4k.txt",
    "ber_result_45_16k.txt",
]

LABELS = [
    "LDPC CFG 12 1k",
    "LDPC CFG 12 4k",
    "LDPC CFG 12 16K",
    "LDPC CFG 23 1k",
    "LDPC CFG 23 4k",
    "LDPC CFG 23 16K",
    "LDPC CFG 45 1k",
    "LDPC CFG 45 4k",
    "LDPC CFG 45 16K",
]

# ============================================================
# Parser
# ============================================================

def parse_ber_file(filename):
    ebn0 = []
    ber = []

    with open(filename, "r") as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()

        # Skip headers
        if (
            not line
            or "Eb/N0" in line
            or "--------" in line
        ):
            continue

        parts = line.split()

        if len(parts) < 6:
            continue

        try:
            ebn0_value = float(parts[0])
            ber_value = float(parts[3])

            # Avoid log(0)
            if ber_value <= 0:
                ber_value = 1e-12

            ebn0.append(ebn0_value)
            ber.append(ber_value)

        except ValueError:
            continue

    return np.array(ebn0), np.array(ber)

# ============================================================
# Plot
# ============================================================

fig, ax = plt.subplots(figsize=(11, 7))

for filename, label in zip(FILES, LABELS):

    try:
        ebn0, ber = parse_ber_file(filename)

        ax.semilogy(
            ebn0,
            ber,
            marker='o',
            linewidth=2,
            markersize=5,
            label=label
        )

    except FileNotFoundError:
        print(f"[WARNING] File not found: {filename}")

# ============================================================
# Y-axis precision
# ============================================================

ax.set_yscale('log')

# Major ticks every decade
ax.yaxis.set_major_locator(LogLocator(base=10.0))

# Minor ticks between decades
ax.yaxis.set_minor_locator(
    LogLocator(
        base=10.0,
        subs=np.arange(1, 10) * 0.1,
        numticks=100
    )
)

# Scientific notation formatting
ax.yaxis.set_major_formatter(LogFormatterMathtext())

# ============================================================
# Labels / Grid
# ============================================================

ax.set_xlabel("Eb/N0 (dB)")
ax.set_ylabel("BER")
ax.set_title("LDPC BER Performance")

# Dense logarithmic grid on Y
ax.grid(True, which='major', axis='y', linestyle='--', linewidth=0.8)
ax.grid(True, which='minor', axis='y', linestyle=':', linewidth=0.5)

# X-axis grid
ax.grid(True, which='major', axis='x', linestyle='--', linewidth=0.8)

# Optional limits
ax.set_ylim(1e-12, 1)

ax.legend()

plt.tight_layout()

# ============================================================
# Save / Show
# ============================================================

plt.savefig("ber_plot.png", dpi=300)

plt.show()