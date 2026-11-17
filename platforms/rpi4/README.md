<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->
Raspberry Pi 4 U-Boot boot disk
===============================

This target builds a small **SD card image** for the Raspberry Pi 4 that only
carries the boot firmware and U-Boot. It deliberately contains **no operating
system**: U-Boot provides a UEFI (EBBR) environment and boots the actual OS from
a **separate USB stick**.

```
 SD card (this image)            USB stick (built elsewhere)
 ┌───────────────────────┐      ┌───────────────────────────┐
 │ FAT boot partition     │      │ the real OS image          │
 │  - start4.elf          │      │  (e.g. the AutoSD disk)    │
 │  - fixup4.dat          │ ───▶ │                            │
 │  - bcm2711-rpi-4-b.dtb │ UEFI │                            │
 │  - u-boot.bin          │      │                            │
 │  - config.txt          │      │                            │
 └───────────────────────┘      └───────────────────────────┘
```

Boot flow: the Pi4 GPU firmware reads `config.txt`, loads `u-boot.bin` as the
"kernel", and U-Boot's UEFI implementation then finds and boots the OS on USB.

## Building

```
bazel build //platforms/rpi4:image
```

The resulting raw image is `bazel-bin/platforms/rpi4/rpi4-boot.img`. Flash it to
an SD card, e.g.:

```
sudo dd if=bazel-bin/platforms/rpi4/rpi4-boot.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The image is assembled **unprivileged** (no loop mounts / no root) using
`mtools` (`mformat`, `mcopy`) and `sfdisk` from `util-linux`. Make sure those are
installed on the build host.

## Testing

```
bazel test //platforms/rpi4:build_image_test
```

A smoke test drives `build_image.sh` with dummy boot files (no downloads) and
asserts, for both the MBR and GPT layouts, that the image has the expected
partition table and that the FAT partition contains the boot files
(`u-boot.bin` round-tripped byte-for-byte). It needs `mtools` + `util-linux` on
the host.

## Configuring the partition layout

The layout is driven by [`disk_layout.env`](disk_layout.env). Edit the defaults
there, or override per-build from the environment:

| Variable                | Default    | Meaning                                   |
| ----------------------- | ---------- | ----------------------------------------- |
| `PARTITION_TABLE`       | `mbr`      | `mbr` (classic RPi) or `gpt` (EBBR/ESP)   |
| `BOOT_PART_OFFSET_KIB`  | `1024`     | First-partition offset in KiB (alignment) |
| `BOOT_PART_SIZE_MIB`    | `128`      | FAT boot partition size in MiB            |
| `FAT_TYPE`              | `32`       | `16` or `32`                              |
| `VOLUME_LABEL`          | `RPI4BOOT` | FAT volume label (≤ 11 chars)             |

For GPT the boot partition is created as an EFI System Partition.

## Downloaded inputs (not stored in the repo)

The firmware and U-Boot binaries are downloaded by Bazel; see the
`//platforms/rpi4` section in [`MODULE.bazel`](../../MODULE.bazel). Before the
target can build you must fill in the `TODO` placeholders there:

- **RPi4 firmware** (`start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb`): pin a
  [`raspberrypi/firmware`](https://github.com/raspberrypi/firmware) commit in
  `RPI_FIRMWARE_COMMIT` and set each `sha256`.
- **U-Boot** (`u-boot.bin`): taken from the Ubuntu `u-boot-rpi` package via the
  `deb` rule (see `u_boot_rpi_deb` in `MODULE.bazel` and
  [`//third_party/uboot`](../../third_party/uboot)). Pin the package version in the
  pool URL and set its `sha256`. The binary is exposed as
  `@u_boot_rpi_deb//:u-boot-bin` (the `rpi_arm64` build).

To add more firmware files (e.g. `overlays/`, `start4cd.elf`), declare them as
extra `http_file`s and append them to `BOOT_FILES` in
[`BUILD`](BUILD) — each entry is copied into the FAT root under its basename.
