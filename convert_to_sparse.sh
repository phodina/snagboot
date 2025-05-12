#!/usr/bin/env bash
# Script to convert a raw ext4 image to Android sparse format

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_image> <output_sparse_image>"
    echo "Example: $0 system.img system_sparse.img"
    exit 1
fi

INPUT_IMG=$1
OUTPUT_IMG=$2

if [ ! -f "$INPUT_IMG" ]; then
    echo "Error: Input file '$INPUT_IMG' not found"
    exit 1
fi

# Check if img2simg is installed
if ! command -v img2simg &> /dev/null; then
    echo "Error: img2simg command not found"
    echo "Please install the android-tools-fsutils package:"
    echo "  For Debian/Ubuntu: sudo apt-get install android-tools-fsutils"
    echo "  For Fedora: sudo dnf install android-tools"
    echo "  For Arch Linux: sudo pacman -S android-tools"
    exit 1
fi

echo "Converting $INPUT_IMG to sparse format..."
img2simg "$INPUT_IMG" "$OUTPUT_IMG"

echo "Conversion complete: $OUTPUT_IMG"
echo "Use this sparse image with the keembay_flash_fixed.sh script"
