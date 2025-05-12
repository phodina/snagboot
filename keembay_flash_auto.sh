#!/usr/bin/env bash
# Script to automatically convert system images to sparse format and flash a Keembay device
# This script combines the functionality of convert_to_sparse.sh and keembay_flash_fixed.sh

set -e

# Check if FIP file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <fip-file> [boot.img] [system.img] [syshash.img] [data.img] [factory.img]"
    echo "Example: $0 fip-ng3396c-fl-r6m5e6-1.15.2.bin boot.img system.img syshash.img data.img"
    exit 1
fi

FIP_FILE=$1
shift

# Check if FIP file exists
if [ ! -f "$FIP_FILE" ]; then
    echo "Error: FIP file '$FIP_FILE' not found"
    exit 1
fi

# Check if image files are provided
if [ $# -eq 0 ]; then
    echo "No image files provided, will only flash FIP"
    FLASH_IMAGES=false
else
    FLASH_IMAGES=true
    IMAGE_FILES=()
    
    # Check if all image files exist
    for img in "$@"; do
        if [ ! -f "$img" ]; then
            echo "Error: Image file '$img' not found"
            exit 1
        fi
        IMAGE_FILES+=("$img")
    done
fi

# Check if img2simg is installed
check_img2simg() {
    if ! command -v img2simg &> /dev/null; then
        echo "Warning: img2simg command not found"
        echo "System images will be flashed without conversion to sparse format"
        echo "For better performance, install the android-tools-fsutils package:"
        echo "  For Debian/Ubuntu: sudo apt-get install android-tools-fsutils"
        echo "  For Fedora: sudo dnf install android-tools"
        echo "  For Arch Linux: sudo pacman -S android-tools"
        return 1
    fi
    return 0
}

# Function to check if a file is already in sparse format
is_sparse_format() {
    local file=$1
    # Check for the Android sparse file magic number (0xED26FF3A)
    local magic=$(hexdump -n 4 -e '1/4 "%x"' "$file")
    if [ "$magic" = "ed26ff3a" ]; then
        return 0  # It's a sparse file
    else
        return 1  # It's not a sparse file
    fi
}

# Process system images - convert to sparse format if needed
process_images() {
    local has_img2simg=$(check_img2simg)
    local temp_files=()
    local processed_files=()
    
    for img in "${IMAGE_FILES[@]}"; do
        img_name=$(basename "$img")
        
        # Only process system.img files that are not already in sparse format
        if [[ "$img_name" == "system.img" ]] && [ "$has_img2simg" -eq 0 ] && ! is_sparse_format "$img"; then
            echo "Converting $img to sparse format..."
            local sparse_img="${img%.img}_sparse.img"
            img2simg "$img" "$sparse_img"
            temp_files+=("$sparse_img")
            processed_files+=("$sparse_img")
            echo "Conversion complete: $sparse_img"
        else
            processed_files+=("$img")
        fi
    done
    
    # Set trap to clean up temporary files on exit
    trap 'rm -f "${temp_files[@]}"' EXIT
    
    IMAGE_FILES=("${processed_files[@]}")
}

echo "=== Keembay Flashing Tool ==="
echo "FIP file: $FIP_FILE"
if [ "$FLASH_IMAGES" = true ]; then
    echo "Image files: ${IMAGE_FILES[*]}"
    
    # Process images before flashing
    process_images
    echo "Processed image files: ${IMAGE_FILES[*]}"
fi
echo

# Step 1: Flash FIP using snagrecover
echo "Step 1: Flashing FIP using snagrecover..."
snagrecover -s keembay -F "{'fip': {'path': '$FIP_FILE'}}"

# Wait for device to reboot into fastboot mode
echo "Waiting for device to reboot into fastboot mode..."
sleep 5

# Step 2: Flash OS images using snagflash if provided
if [ "$FLASH_IMAGES" = true ]; then
    echo "Step 2: Flashing OS images using snagflash..."
    
    # Format the device first
    echo "Formatting device..."
    snagflash -P fastboot -p 8087:da00 -f oem_format
    
    # Flash each image separately to avoid issues with large files
    for img in "${IMAGE_FILES[@]}"; do
        img_name=$(basename "$img")
        
        case "$img_name" in
            boot.img)
                echo "Flashing boot.img to boot_a partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:boot_a
                echo "Flashing boot.img to boot_b partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:boot_b
                ;;
            system.img|system_sparse.img)
                # Use flash_sparse for system.img to handle large file size with increased timeout
                echo "Flashing system image to system_a partition..."
                snagflash -P fastboot -p 8087:da00 -t 120000 -f flash_sparse:"$img":system_a
                echo "Flashing system image to system_b partition..."
                snagflash -P fastboot -p 8087:da00 -t 120000 -f flash_sparse:"$img":system_b
                ;;
            syshash.img)
                echo "Flashing syshash.img to syshash_a partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:syshash_a
                echo "Flashing syshash.img to syshash_b partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:syshash_b
                ;;
            data.img)
                echo "Flashing data.img to data partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:data
                ;;
            factory.img)
                echo "Flashing factory.img to factory partition..."
                snagflash -P fastboot -p 8087:da00 -f download:"$img" -f flash:factory
                ;;
            *)
                echo "Unknown image type: $img_name, skipping"
                ;;
        esac
    done
    
    echo "All images flashed successfully!"
else
    echo "Step 2: Skipping OS image flashing (no images provided)"
fi

echo "=== Flashing completed successfully ==="
echo "Please shutdown the system, set the boot switch to normal and reboot the system"
