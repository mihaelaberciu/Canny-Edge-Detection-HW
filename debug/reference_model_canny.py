"""
Author > Berciu Mihaela - Georgiana
Date : April 2025
"""

import numpy as np
from pathlib import Path


def border_reflect_101(arr, pad_height, pad_width):
    """
    border_reflect_101 -with fidelity to the hw implementation
    """
    height, width = arr.shape
    padded = np.zeros((height + 2 * pad_height, width + 2 * pad_width), dtype=np.uint8)

    padded[pad_height:pad_height + height, pad_width:pad_width + width] = arr

    padded[:pad_height, pad_width:pad_width + width] = np.flip(arr[1:pad_height + 1, :], axis=0)

    padded[pad_height + height:, pad_width:pad_width + width] = np.flip(arr[height - pad_height - 1:height - 1, :],
                                                                        axis=0)

    padded[pad_height:pad_height + height, :pad_width] = np.flip(arr[:, 1:pad_width + 1], axis=1)

    padded[pad_height:pad_height + height, pad_width + width:] = np.flip(arr[:, width - pad_width - 1:width - 1],
                                                                         axis=1)

    padded[:pad_height, :pad_width] = np.flip(np.flip(arr[1:pad_height + 1, 1:pad_width + 1], axis=0), axis=1)

    padded[:pad_height, pad_width + width:] = np.flip(
        np.flip(arr[1:pad_height + 1, width - pad_width - 1:width - 1], axis=0), axis=1)

    padded[pad_height + height:, :pad_width] = np.flip(
        np.flip(arr[height - pad_height - 1:height - 1, 1:pad_width + 1], axis=0), axis=1)

    padded[pad_height + height:, pad_width + width:] = np.flip(
        np.flip(arr[height - pad_height - 1:height - 1, width - pad_width - 1:width - 1], axis=0), axis=1)

    return padded


def canny_hw_reference(input_file='image_pixels.txt',
                       output_dir='.',
                       high_thresh=100,
                       low_thresh=50,
                       width=50,
                       height=50):
    """
    Parameters:
    - input_file: txt file with input pixels
    - output_dir: output dir
    - high_thresh, low_thresh: thresholds for double thresholding stage
    - width, height: dimensions
    """
    # Output files
    output_path = Path(output_dir)
    canny_output_file = output_path / 'canny_reference.txt'
    debug_output_file = output_path / 'reference_debug.txt'

    img = np.zeros((height, width, 3), dtype=np.uint8)

    with open(input_file, 'r') as f:
        for y, line in enumerate(f):
            if y >= height:
                break
            values = line.strip().split()
            for x, hex_val in enumerate(values):
                if x >= width:
                    break
                # hex -> RGB
                r = int(hex_val[0:2], 16)
                g = int(hex_val[2:4], 16)
                b = int(hex_val[4:6], 16)
                img[y, x] = [r, g, b]

    # results for each stage
    gray = np.zeros((height, width), dtype=np.uint8)
    blurred = np.zeros((height, width), dtype=np.uint8)
    magnitude = np.zeros((height, width), dtype=np.uint8)
    direction = np.zeros((height, width), dtype=np.uint8)
    nms = np.zeros((height, width), dtype=np.uint8)
    strong_edges = np.zeros((height, width), dtype=np.uint8)
    weak_edges = np.zeros((height, width), dtype=np.uint8)
    final_edges = np.zeros((height, width), dtype=np.uint8)

    # ------------------------------------------------
    # 1. RGB TO GRAYSCALE
    # ------------------------------------------------
    for y in range(height):
        for x in range(width):
            r, g, b = img[y, x]
            weighted_red = (r << 9) + (r << 6) + (r << 5) + (r << 2) + r
            weighted_green = (g << 10) + (g << 7) + (g << 5) + (g << 4) + (g << 1) + g
            weighted_blue = (b << 7) + (b << 6) + (b << 5) + (b << 3) + (b << 1)

            weighted_sum = weighted_red + weighted_green + weighted_blue
            gray[y, x] = (weighted_sum >> 11) & 0xFF

    # ------------------------------------------------
    # 2. Gaussian blur
    # ------------------------------------------------
    # Padding
    padded = border_reflect_101(gray, 1, 1)

    # Gaussian kernel [1,2,1; 2,4,2; 1,2,1]/16
    for y in range(height):
        for x in range(width):
            window_sum = (
                    padded[y, x] + (padded[y, x + 1] << 1) + padded[y, x + 2] +
                    (padded[y + 1, x] << 1) + (padded[y + 1, x + 1] << 2) + (padded[y + 1, x + 2] << 1) +
                    padded[y + 2, x] + (padded[y + 2, x + 1] << 1) + padded[y + 2, x + 2]
            )
            blurred[y, x] = (window_sum + 8) >> 4

    # ------------------------------------------------
    # 3. Sobel Edge Detection
    # ------------------------------------------------
    # Padding
    padded = border_reflect_101(blurred, 1, 1)

    for y in range(height):
        for x in range(width):
            gx = (
                    (padded[y, x + 2]) - (padded[y, x]) +
                    ((padded[y + 1, x + 2] << 1) - (padded[y + 1, x] << 1)) +
                    (padded[y + 2, x + 2]) - (padded[y + 2, x])
            )
            gy = (
                    (padded[y + 2, x]) + (padded[y + 2, x + 1] << 1) + (padded[y + 2, x + 2]) -
                    (padded[y, x]) - (padded[y, x + 1] << 1) - (padded[y, x + 2])
            )

            abs_gx = abs(gx)
            abs_gy = abs(gy)

            mag = (abs_gx + abs_gy) >> 1
            magnitude[y, x] = min(mag, 255)

            if abs_gx == 0 and abs_gy == 0:
                angle = 0  # no
            elif abs_gy > abs_gx:
                angle = 2  # 90°
            elif abs_gy < (abs_gx - (abs_gx >> 2)):  # aprox 3/8 * abs_gx
                angle = 0  # 0°
            else:
                # 45° / 135°
                if (gx >= 0 and gy >= 0) or (gx < 0 and gy < 0):
                    angle = 1  # 45°
                else:
                    angle = 3  # 135°

            direction[y, x] = angle

    # ------------------------------------------------
    # 4. Non-Maximum Suppression
    # ------------------------------------------------
    # Padding
    padded_mag = border_reflect_101(magnitude, 1, 1)
    padded_dir = border_reflect_101(direction, 1, 1)

    for y in range(height):
        for x in range(width):
            if y == 0 or y == height - 1 or x == 0 or x == width - 1:
                nms[y, x] = 0
                continue

            dir_val = padded_dir[y + 1, x + 1]

            if dir_val == 0:
                neighbor1 = padded_mag[y + 1, x + 2]
                neighbor2 = padded_mag[y + 1, x]
            elif dir_val == 2:
                neighbor1 = padded_mag[y + 2, x + 1]
                neighbor2 = padded_mag[y, x + 1]
            elif dir_val == 1:
                neighbor1 = padded_mag[y + 2, x + 2]
                neighbor2 = padded_mag[y, x]
            else:  # 135°
                neighbor1 = padded_mag[y + 2, x]
                neighbor2 = padded_mag[y, x + 2]

            if padded_mag[y + 1, x + 1] >= neighbor1 and padded_mag[y + 1, x + 1] >= neighbor2:
                nms[y, x] = padded_mag[y + 1, x + 1]
            else:
                nms[y, x] = 0

    # ------------------------------------------------
    # 5. Double Threshold
    # ------------------------------------------------
    for y in range(height):
        for x in range(width):
            if nms[y, x] >= high_thresh:
                strong_edges[y, x] = 255
            elif nms[y, x] >= low_thresh and nms[y, x] < high_thresh:
                weak_edges[y, x] = 128

    # ------------------------------------------------
    # 6. Hysteresis Threshold
    # ------------------------------------------------
    # Padding
    padded_strong = border_reflect_101(strong_edges, 1, 1)
    padded_weak = border_reflect_101(weak_edges, 1, 1)

    for y in range(height):
        for x in range(width):
            if padded_strong[y + 1, x + 1] == 255:
                final_edges[y, x] = 255
            elif padded_weak[y + 1, x + 1] == 128:
                strong_count = 0
                for dy in range(-1, 2):
                    for dx in range(-1, 2):
                        if padded_strong[y + 1 + dy, x + 1 + dx] == 255:
                            strong_count += 1

                if strong_count >= 2:
                    final_edges[y, x] = 255

    # ------------------------------------------------
    # Final results are saved in canny_reference.txt
    # ------------------------------------------------
    with open(canny_output_file, 'w') as f:
        f.write(f"// Canny Edge Detection Reference Model Output\n")
        f.write(f"// Resolution: {width}x{height}\n")
        f.write(f"// Thresholds: High={high_thresh}, Low={low_thresh}\n\n")

        for y in range(height):
            for x in range(width):
                f.write(f"{final_edges[y, x]:3d} ")
            f.write("\n")

    # ------------------------------------------------
    # Intermediary results to reference_debug.txt
    # ------------------------------------------------
    with open(debug_output_file, 'w') as f:
        f.write("=== All Processing Stages ===\n\n")

        f.write("=== Grayscale Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{gray[y, x]:3d} ")
            f.write("\n")

        f.write("\n=== Gaussian Blur Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{blurred[y, x]:3d} ")
            f.write("\n")

        f.write("\n=== Sobel Magnitude Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{magnitude[y, x]:3d} ")
            f.write("\n")

        f.write("\n=== Sobel Direction Output ===\n")
        for y in range(height):
            for x in range(width):
                dir_val = direction[y, x]
                if dir_val == 0:
                    f.write("  0° ")
                elif dir_val == 1:
                    f.write(" 45° ")
                elif dir_val == 2:
                    f.write(" 90° ")
                else:
                    f.write("135° ")
            f.write("\n")

        f.write("\n=== Non-Maximum Suppression Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{nms[y, x]:3d} ")
            f.write("\n")

        f.write("\n=== Strong Edges Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{strong_edges[y, x]:3d} ")
            f.write("\n")

        f.write("\n=== Weak Edges Output ===\n")
        for y in range(height):
            for x in range(width):
                f.write(f"{weak_edges[y, x]:3d} ")
            f.write("\n")

    print(f"\nReference model processing complete!")
    print(f"Final edges saved to: {canny_output_file}")
    print(f"Debug data saved to: {debug_output_file}")

    # Statistics
    strong_count = np.sum(strong_edges > 0)
    weak_count = np.sum(weak_edges > 0)
    final_count = np.sum(final_edges > 0)

    print("\n=== Edge Detection Statistics ===")
    print(f"Strong edges detected: {strong_count} pixels ({100.0 * strong_count / (width * height):.2f}%)")
    print(f"Weak edges detected: {weak_count} pixels ({100.0 * weak_count / (width * height):.2f}%)")
    print(f"Final edges after hysteresis: {final_count} pixels ({100.0 * final_count / (width * height):.2f}%)")

    return final_edges


def compare_results(hw_file='canny_output.txt', ref_file='canny_reference.txt', output_file='comparison_report.txt',
                    height=50, width=50):
    """
    Comparing block
    """
    hw_edges = np.zeros((height, width), dtype=np.uint8)
    with open(hw_file, 'r') as f:
        lines = [line for line in f.readlines() if not line.startswith('//')]
        for y, line in enumerate(lines[:height]):
            values = line.strip().split()
            for x, val in enumerate(values[:width]):
                hw_edges[y, x] = int(val)

    ref_edges = np.zeros((height, width), dtype=np.uint8)
    with open(ref_file, 'r') as f:
        lines = [line for line in f.readlines() if not line.startswith('//')]
        for y, line in enumerate(lines[:height]):
            values = line.strip().split()
            for x, val in enumerate(values[:width]):
                ref_edges[y, x] = int(val)

    match_pixels = np.sum(hw_edges == ref_edges)
    total_pixels = height * width
    match_percentage = match_pixels / total_pixels * 100

    hw_edge_count = np.sum(hw_edges > 0)
    ref_edge_count = np.sum(ref_edges > 0)

    false_positives = np.sum((ref_edges == 0) & (hw_edges > 0))
    false_negatives = np.sum((ref_edges > 0) & (hw_edges == 0))

    # Print
    print("\n=== Comparison Results ===")
    print(f"Pixel match: {match_pixels}/{total_pixels} ({match_percentage:.2f}%)")
    print(f"Hardware edges: {hw_edge_count} pixels ({hw_edge_count / total_pixels * 100:.2f}%)")
    print(f"Reference edges: {ref_edge_count} pixels ({ref_edge_count / total_pixels * 100:.2f}%)")
    print(f"False positives: {false_positives} pixels ({false_positives / total_pixels * 100:.2f}%)")
    print(f"False negatives: {false_negatives} pixels ({false_negatives / total_pixels * 100:.2f}%)")

    with open(output_file, 'w') as f:
        f.write("=== Canny Edge Detection Implementation Comparison ===\n\n")
        f.write(f"Pixel match: {match_pixels}/{total_pixels} ({match_percentage:.2f}%)\n")
        f.write(f"Hardware edges: {hw_edge_count} pixels ({hw_edge_count / total_pixels * 100:.2f}%)\n")
        f.write(f"Reference edges: {ref_edge_count} pixels ({ref_edge_count / total_pixels * 100:.2f}%)\n")
        f.write(f"False positives: {false_positives} pixels ({false_positives / total_pixels * 100:.2f}%)\n")
        f.write(f"False negatives: {false_negatives} pixels ({false_negatives / total_pixels * 100:.2f}%)\n")

    print(f"Comparison report saved to: {output_file}")

    return match_percentage, hw_edge_count, ref_edge_count, false_positives, false_negatives


if __name__ == "__main__":
    try:
        print("Canny Edge Detection Hardware Reference Model")
        print("---------------------------------------------")

        canny_hw_reference()

        if Path('canny_output.txt').exists():
            print("\nDetected hardware simulation output. Comparing results...")
            compare_results()
        else:
            print("\nNo hardware simulation output found. Run the SystemVerilog testbench to generate canny_output.txt")

    except Exception as e:
        print(f"Error: {str(e)}")
