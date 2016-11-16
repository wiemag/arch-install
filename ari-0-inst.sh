#!/bin/bash
less <<EOF
INSTALLATION GUIDE

- Choose disks
- Disks: GPT partitioning regardless of EFI/BIOS
- Wipe chosen disks (Skip wiping as a default)
- Create EFI (ESP) partition:
----- on the first chosen disk as a default
----- or no EFI partition
----- ESP as boot partition (default)
----- EFI partition size:  512 MiB
----- boot partition size: 112 MiB (if other than ESP)
EOF
