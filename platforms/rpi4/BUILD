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
# Raspberry Pi 4 "boot shim" SD card image.
#
# The resulting raw disk image only carries the Pi4 GPU firmware, the device
# tree and U-Boot. U-Boot provides a UEFI (EBBR) environment and boots the
# actual OS from a separate USB stick. See README.md.

exports_files(
    [
        "build_image.sh",
        "config.txt",
        "disk_layout.env",
    ],
    visibility = ["//visibility:public"],
)

# Boot files copied into the root of the FAT partition. Order is irrelevant;
# each file lands under its own basename.
BOOT_FILES = [
    "config.txt",
    "@u_boot_rpi_deb//:u-boot-bin",
    "@rpi4_fw_start4_elf//file",
    "@rpi4_fw_fixup4_dat//file",
    "@rpi4_fw_bcm2711_rpi_4_b_dtb//file",
]

# Assembles the partitioned raw disk image unprivileged (mtools + sfdisk).
# Built only on request: it depends on downloaded firmware/U-Boot artifacts and
# host tooling (mtools, util-linux).
genrule(
    name = "image",
    srcs = ["disk_layout.env"] + BOOT_FILES,
    outs = ["rpi4-boot.img"],
    cmd = "bash $(location build_image.sh) " +
          "$(location rpi4-boot.img) " +
          "$(location disk_layout.env) " +
          " ".join(["$(location %s)" % f for f in BOOT_FILES]),
    tags = ["manual"],
    tools = ["build_image.sh"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "disk_layout",
    srcs = ["disk_layout.env"],
    visibility = ["//visibility:public"],
)

# Smoke test: drives build_image.sh with dummy boot files (no downloads) and
# checks the partition table and FAT contents of the result. Requires mtools +
# util-linux on the host.
sh_test(
    name = "build_image_test",
    srcs = ["build_image_test.sh"],
    data = [
        "build_image.sh",
        "disk_layout.env",
    ],
    visibility = ["//visibility:private"],
)
