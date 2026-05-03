#Needed
# pip install matplotlib numpy pillow
# pip install scipy

#Launch
#python mat2png.py H_1_2_1024.mat
#python mat2png.py H_1_2_1024.mat -o H_1_2_1024.png --major-step 256 --minor-step 64
#python mat2png.py H_1_2_16384.mat --downsample 4



#!/usr/bin/env python3
import argparse
import math
import os
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from PIL import Image


def parse_octave_sparse_text_mat(path):
    rows = None
    cols = None
    entries = []

    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith("#"):
                if line.startswith("# rows:"):
                    rows = int(line.split(":", 1)[1].strip())
                elif line.startswith("# columns:"):
                    cols = int(line.split(":", 1)[1].strip())
                continue

            parts = line.split()
            if len(parts) != 3:
                raise ValueError(f"Unexpected data line: {line}")

            row_1based = int(parts[0])
            col_1based = int(parts[1])
            value = float(parts[2])

            if value != 0.0:
                entries.append((row_1based - 1, col_1based - 1))

    if rows is None or cols is None:
        raise ValueError("Could not find # rows: or # columns: header in file")

    return rows, cols, entries


def load_any_mat(path, variable_name="H"):
    try:
        return parse_octave_sparse_text_mat(path)
    except Exception as text_error:
        try:
            import scipy.io
            import scipy.sparse
        except ImportError as import_error:
            raise RuntimeError(
                "File is not in Octave sparse-text format, and scipy is not installed "
                "for reading binary MATLAB .mat files."
            ) from import_error

        mat = scipy.io.loadmat(path)
        if variable_name not in mat:
            raise KeyError(f"Variable {variable_name!r} not found in MAT file") from text_error

        obj = mat[variable_name]
        if scipy.sparse.issparse(obj):
            coo = obj.tocoo()
            rows = int(coo.shape[0])
            cols = int(coo.shape[1])
            entries = list(zip(coo.row.tolist(), coo.col.tolist()))
            return rows, cols, entries

        dense = np.asarray(obj)
        if dense.ndim != 2:
            raise ValueError(f"Variable {variable_name!r} is not 2D")

        row_idx, col_idx = np.nonzero(dense)
        rows = int(dense.shape[0])
        cols = int(dense.shape[1])
        entries = list(zip(row_idx.tolist(), col_idx.tolist()))
        return rows, cols, entries


def choose_step(length, target_ticks=10):
    if length <= 0:
        return 1

    raw = max(1.0, length / max(1, target_ticks))
    exponent = int(math.floor(math.log10(raw)))
    base = 10 ** exponent

    candidates = [1, 2, 5, 10]
    best = candidates[-1] * base
    best_score = float("inf")

    for multiplier in candidates:
        step = multiplier * base
        score = abs((length / step) - target_ticks)
        if score < best_score:
            best_score = score
            best = step

    return max(1, int(best))


def build_sparse_image(rows, cols, entries, downsample):
    out_rows = (rows + downsample - 1) // downsample
    out_cols = (cols + downsample - 1) // downsample

    image = Image.new("1", (out_cols, out_rows), 1)
    pixels = image.load()

    for row, col in entries:
        y = row // downsample
        x = col // downsample
        pixels[x, y] = 0

    return image, out_rows, out_cols


def render_png(
    input_path,
    output_path,
    rows,
    cols,
    image,
    out_rows,
    out_cols,
    downsample,
    dpi,
    major_step=None,
    minor_step=None,
):
    left_px = 110
    right_px = 30
    top_px = 40
    bottom_px = 90

    fig_w_px = left_px + out_cols + right_px
    fig_h_px = top_px + out_rows + bottom_px

    total_pixels = fig_w_px * fig_h_px
    if total_pixels > 200_000_000:
        raise RuntimeError(
            "Requested output is too large for a practical annotated PNG. "
            "Use --downsample 2 or higher."
        )

    if major_step is None:
        major_step = choose_step(max(rows, cols), target_ticks=10)
    if minor_step is None:
        minor_step = max(1, major_step // 5)

    fig = plt.figure(figsize=(fig_w_px / dpi, fig_h_px / dpi), dpi=dpi, facecolor="white")
    ax = fig.add_axes(
        [
            left_px / fig_w_px,
            bottom_px / fig_h_px,
            out_cols / fig_w_px,
            out_rows / fig_h_px,
        ]
    )

    raster = np.asarray(image.convert("L"))
    ax.imshow(
        raster,
        cmap="gray",
        vmin=0,
        vmax=255,
        origin="upper",
        interpolation="nearest",
        extent=[0, cols, rows, 0],
        aspect="auto",
    )

    ax.set_xlim(0, cols)
    ax.set_ylim(rows, 0)

    x_major = list(range(0, cols + 1, major_step))
    y_major = list(range(0, rows + 1, major_step))
    x_minor = list(range(0, cols + 1, minor_step))
    y_minor = list(range(0, rows + 1, minor_step))

    ax.set_xticks(x_major)
    ax.set_yticks(y_major)
    ax.set_xticks(x_minor, minor=True)
    ax.set_yticks(y_minor, minor=True)

    ax.grid(which="major", color="#2b6cb0", alpha=0.45, linewidth=0.7)
    ax.grid(which="minor", color="#94a3b8", alpha=0.25, linewidth=0.4)

    title = Path(input_path).name
    if downsample == 1:
        subtitle = f"{rows} x {cols}, 1 pixel per matrix cell"
    else:
        subtitle = f"{rows} x {cols}, downsample {downsample}x"

    ax.set_title(f"{title}\n{subtitle}", fontsize=11)
    ax.set_xlabel("Column index")
    ax.set_ylabel("Row index")
    ax.tick_params(axis="x", labelrotation=45)

    fig.savefig(output_path, dpi=dpi, facecolor="white")
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(
        description="Render a CCSDS LDPC sparse-text .mat file to a high-resolution PNG."
    )
    parser.add_argument("matfile", help="Input .mat file")
    parser.add_argument(
        "-o",
        "--output",
        help="Output PNG file. Default: same basename as input with .png",
    )
    parser.add_argument(
        "--variable",
        default="H",
        help="Variable name for binary MATLAB .mat files. Default: H",
    )
    parser.add_argument(
        "--downsample",
        type=int,
        default=1,
        help="Merge NxN matrix cells into one output pixel. Default: 1",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=100,
        help="Figure DPI used for the annotated PNG. Default: 100",
    )
    parser.add_argument(
        "--major-step",
        type=int,
        default=None,
        help="Major grid/tick spacing in matrix coordinates",
    )
    parser.add_argument(
        "--minor-step",
        type=int,
        default=None,
        help="Minor grid/tick spacing in matrix coordinates",
    )

    args = parser.parse_args()

    if args.downsample < 1:
        raise SystemExit("--downsample must be >= 1")

    input_path = args.matfile
    output_path = args.output
    if output_path is None:
        output_path = str(Path(input_path).with_suffix(".png"))

    rows, cols, entries = load_any_mat(input_path, variable_name=args.variable)
    image, out_rows, out_cols = build_sparse_image(rows, cols, entries, args.downsample)

    render_png(
        input_path=input_path,
        output_path=output_path,
        rows=rows,
        cols=cols,
        image=image,
        out_rows=out_rows,
        out_cols=out_cols,
        downsample=args.downsample,
        dpi=args.dpi,
        major_step=args.major_step,
        minor_step=args.minor_step,
    )

    print(f"Loaded matrix: {rows} x {cols}")
    print(f"Nonzero entries: {len(entries)}")
    print(f"Saved PNG: {output_path}")


if __name__ == "__main__":
    main()