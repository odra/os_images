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
# Assembles a bootable Raspberry Pi 4 SD card image that only carries the Pi4
# GPU firmware, the device tree and U-Boot. U-Boot provides a UEFI (EBBR)
# environment and boots the actual OS from a separate USB stick.
#
# The image is a raw disk with a single FAT boot partition. The whole image is
# produced unprivileged (no loop mounts / no root) using mtools + sfdisk.
#
# Usage:
#   build_image.sh <out_image> <layout_env> <boot_file> [<boot_file> ...]
#
# Every <boot_file> (config.txt, u-boot.bin, start4.elf, ...) is copied into the
# root of the FAT partition under its own basename.

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <out_image> <layout_env> <boot_file> [<boot_file> ...]" >&2
    exit 1
fi

OUT_IMAGE="$1"
LAYOUT_ENV="$2"
shift 2
BOOT_FILES=("$@")

SECTOR_SIZE=512

for tool in mformat mcopy sfdisk dd truncate; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "Error: required tool '${tool}' is not installed." >&2
        echo "       Need mtools (mformat, mcopy) and util-linux (sfdisk)." >&2
        exit 1
    fi
done

if [[ ! -f "${LAYOUT_ENV}" ]]; then
    echo "Error: layout file does not exist: ${LAYOUT_ENV}" >&2
    exit 1
fi

# Defaults, overridable by the environment and then by the layout file.
PARTITION_TABLE="${PARTITION_TABLE:-mbr}"
BOOT_PART_OFFSET_KIB="${BOOT_PART_OFFSET_KIB:-1024}"
BOOT_PART_SIZE_MIB="${BOOT_PART_SIZE_MIB:-128}"
FAT_TYPE="${FAT_TYPE:-32}"
VOLUME_LABEL="${VOLUME_LABEL:-RPI4BOOT}"
# shellcheck source=/dev/null
source "${LAYOUT_ENV}"

case "${PARTITION_TABLE}" in
    mbr|gpt) ;;
    *) echo "Error: PARTITION_TABLE must be 'mbr' or 'gpt', got '${PARTITION_TABLE}'." >&2; exit 1 ;;
esac
case "${FAT_TYPE}" in
    16|32) ;;
    *) echo "Error: FAT_TYPE must be 16 or 32, got '${FAT_TYPE}'." >&2; exit 1 ;;
esac

# Geometry, all in 512-byte sectors.
offset_sectors=$(( BOOT_PART_OFFSET_KIB * 1024 / SECTOR_SIZE ))
part_sectors=$(( BOOT_PART_SIZE_MIB * 1024 * 1024 / SECTOR_SIZE ))
# GPT keeps a backup table at the end of the disk; reserve a 1 MiB tail for it
# (and for alignment slack on MBR).
tail_sectors=$(( 1024 * 1024 / SECTOR_SIZE ))
total_sectors=$(( offset_sectors + part_sectors + tail_sectors ))

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
FAT_IMAGE="${WORK_DIR}/boot.fat"

# ---------------------------------------------------------------------------
# 1. Build the FAT filesystem image and populate it.
# ---------------------------------------------------------------------------
truncate -s "$(( part_sectors * SECTOR_SIZE ))" "${FAT_IMAGE}"

# mformat derives the filesystem size from the backing file. MTOOLS_SKIP_CHECK
# silences the geometry heuristics that otherwise reject plain image files.
export MTOOLS_SKIP_CHECK=1
mformat_args=(-i "${FAT_IMAGE}" -v "${VOLUME_LABEL}")
if [[ "${FAT_TYPE}" == "32" ]]; then
    mformat_args+=(-F)
fi
mformat "${mformat_args[@]}" ::

for f in "${BOOT_FILES[@]}"; do
    if [[ ! -e "${f}" ]]; then
        echo "Error: boot file does not exist: ${f}" >&2
        exit 1
    fi
    # -s copies files and directories recursively into the FAT root.
    mcopy -i "${FAT_IMAGE}" -s "${f}" ::
done

# ---------------------------------------------------------------------------
# 2. Create the raw disk, write the partition table, place the FAT partition.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "${OUT_IMAGE}")"
rm -f "${OUT_IMAGE}"
truncate -s "$(( total_sectors * SECTOR_SIZE ))" "${OUT_IMAGE}"

if [[ "${PARTITION_TABLE}" == "mbr" ]]; then
    # type=c -> W95 FAT32 (LBA); bootable flag set so the firmware scans it.
    sfdisk "${OUT_IMAGE}" <<EOF
label: dos
unit: sectors
start=${offset_sectors}, size=${part_sectors}, type=c, bootable
EOF
else
    # EFI System Partition type GUID.
    ESP_GUID="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    sfdisk "${OUT_IMAGE}" <<EOF
label: gpt
unit: sectors
start=${offset_sectors}, size=${part_sectors}, type=${ESP_GUID}, name="${VOLUME_LABEL}"
EOF
fi

dd if="${FAT_IMAGE}" of="${OUT_IMAGE}" bs="${SECTOR_SIZE}" seek="${offset_sectors}" \
    conv=notrunc status=none

echo "Wrote ${PARTITION_TABLE^^} disk image: ${OUT_IMAGE}" >&2
echo "  boot partition: ${BOOT_PART_SIZE_MIB} MiB FAT${FAT_TYPE} @ ${BOOT_PART_OFFSET_KIB} KiB, label '${VOLUME_LABEL}'" >&2
