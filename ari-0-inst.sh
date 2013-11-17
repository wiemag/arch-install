#!/bin/bash
less <<EOF
INSTALLATION GUIDE

- Choose disks
- Disks: GPT partitioning regardless of EFI/BIOS
- Wipe chosen disks
- Create EFI (EPS) partition: 
----- on the first chosen disk as a default
----- or no EFI partition 
----- EFI partition size:  512 MiB
----- boot partition size: 112 MiB
----- If EFI -> boot
EOF
