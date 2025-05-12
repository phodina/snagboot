#!/usr/bin/env bash
# Script to flash a Keembay device using snagrecover and snagflash
# Modified to handle large system.img files

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

echo "=== Keembay Flashing Tool ==="
echo "FIP file: $FIP_FILE"
if [ "$FLASH_IMAGES" = true ]; then
    echo "Image files: ${IMAGE_FILES[*]}"
fi
echo

# Step 1: Flash FIP using snagrecover
echo "Step 1: Flashing FIP using snagrecover..."
snagrecover -s keembay -F "{'fip': {'path': '$FIP_FILE'}}"

# Wait for device to reboot into fastboot mode
echo "Waiting for device to reboot into fastboot mode..."
sleep 10

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
                snagflash -P fastboot -p 8087:da00 --timeout 300000 -f flash_sparse:"$img":system_a
                echo "Flashing system image to system_b partition..."
                snagflash -P fastboot -p 8087:da00 --timeout 300000 -f flash_sparse:"$img":system_b
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
echo "Reboot the system"

sleep 5
snagflash -P fastboot -p 8087:da00 -f reboot
