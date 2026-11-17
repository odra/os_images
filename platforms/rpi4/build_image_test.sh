#!/bin/bash
# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
#
# Smoke test for build_image.sh: builds an image from dummy boot files (no
# downloads needed) and asserts the result is a partitioned disk whose FAT boot
# partition contains the expected files.

set -euo pipefail

here=$(dirname "$0")
script=$(realpath "$here/build_image.sh")
layout=$(realpath "$here/disk_layout.env")

for tool in mformat mcopy mdir sfdisk dd truncate; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: required tool '$tool' is not installed." >&2
        exit 1
    fi
done

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

# Dummy boot files. Content is arbitrary; we only check that it round-trips.
boot_dir="$fixture/boot"
mkdir -p "$boot_dir"
printf 'u-boot-fixture' > "$boot_dir/u-boot.bin"
printf 'kernel=u-boot.bin\n' > "$boot_dir/config.txt"
printf 'start4-fixture' > "$boot_dir/start4.elf"
printf 'fixup4-fixture' > "$boot_dir/fixup4.dat"
printf 'dtb-fixture' > "$boot_dir/bcm2711-rpi-4-b.dtb"

expected_files=(u-boot.bin config.txt start4.elf fixup4.dat bcm2711-rpi-4-b.dtb)

# Offset (bytes) of the FAT partition, from the defaults in disk_layout.env.
offset_bytes=$((1024 * 1024))

# Asserts the FAT partition at $offset_bytes in $1 holds every expected file,
# and that u-boot.bin round-trips byte-for-byte.
assert_fat_contents() {
    local img="$1" f
    # Check presence by copying each file out (mcopy resolves long names; mdir
    # prints 8.3 short names, so its text can't be grepped for "u-boot.bin").
    for f in "${expected_files[@]}"; do
        if ! mcopy -i "$img@@$offset_bytes" -o "::$f" "$fixture/fat.out" 2>/dev/null; then
            echo "Error: '$f' missing from FAT partition of $img" >&2
            mdir -i "$img@@$offset_bytes" :: >&2 || true
            return 1
        fi
    done
    mcopy -i "$img@@$offset_bytes" -o ::u-boot.bin "$fixture/u-boot.out"
    cmp -s "$boot_dir/u-boot.bin" "$fixture/u-boot.out"
}

# --- Default layout: MBR + bootable FAT32 ----------------------------------
mbr_img="$fixture/mbr.img"
bash "$script" "$mbr_img" "$layout" \
    "$boot_dir/u-boot.bin" "$boot_dir/config.txt" "$boot_dir/start4.elf" \
    "$boot_dir/fixup4.dat" "$boot_dir/bcm2711-rpi-4-b.dtb"

[[ -f "$mbr_img" ]]
mbr_table=$(sfdisk -d "$mbr_img")
grep -Fq 'label: dos' <<<"$mbr_table"
# Single partition, FAT32 LBA (type c), flagged bootable.
grep -Eq 'type=c\b' <<<"$mbr_table"
grep -Fq 'bootable' <<<"$mbr_table"
assert_fat_contents "$mbr_img"

# --- GPT layout: single EFI System Partition -------------------------------
gpt_img="$fixture/gpt.img"
PARTITION_TABLE=gpt bash "$script" "$gpt_img" "$layout" \
    "$boot_dir/u-boot.bin" "$boot_dir/config.txt" "$boot_dir/start4.elf" \
    "$boot_dir/fixup4.dat" "$boot_dir/bcm2711-rpi-4-b.dtb"

[[ -f "$gpt_img" ]]
gpt_table=$(sfdisk -d "$gpt_img")
grep -Fq 'label: gpt' <<<"$gpt_table"
grep -Fiq 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' <<<"$gpt_table"
assert_fat_contents "$gpt_img"

# --- Too few arguments must fail -------------------------------------------
if bash "$script" "$fixture/bad.img" > "$fixture/bad.log" 2>&1; then
    echo "Error: build_image.sh accepted too few arguments" >&2
    exit 1
fi

echo "RPi4 boot image smoke tests passed"
