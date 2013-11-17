#!/bin/bash
# by Wiesław Magusiak
# UEFI or BIOS: LVM on LUKS on RAID (5|1)
#
VARSION=0.10
# Dependencies:  bc

function usage_lvm () {
echo -e "Usage:"
echo -e "\t\e[1m${0##*/} [-n NAME] [-g vgNAME] [-r rtSIZE]\e[0m"
echo -e "Meaning and default values:"
echo -e "\t\e[1mNAME\e[0m is an open LUKS encrypted partition mapping name.  (luksraid)"
echo -e "\t\e[1mvgNAME\e[0m is an LVM volume group name.                           (vg)"
echo -e "\t\e[1mrtSIZE\e[0m is the GiB size of 'root' logical volume on the vg . (12.0)"
}

usage_lvm

while getopts "n:g:r:" flag; do
	case $flag in
		n) NAME="$OPTARG";;
		g) VG="$OPTARG";;
		r) rtSIZE="$OPTARG";;
	esac
done

NAME=${NAME-luksraid}
echo Testing: $NAME
VG=${VG-vg}

luks=$(readlink -f /dev/mapper/${NAME})
luks=$(readlink -f /sys/block/${luks##*/})
echo Testing LUKS device      = $luks
echo Testing LUKS device name = $(<${luks}/dm/name)
echo Testing LUKS dev size    = $(<${luks}/size) 512-byte blocks
luSIZE0=$(<${luks}/size) 								# luks part size in 512-byte blocks
luSIZE=$(echo "scale=2; $luSIZE0 / 2048 / 1024" | bc) 	# luks part size in GiB
rtSIZE=${rtSIZE-12.0}
echo "Testing LUKS size (GiB)  = "${luSIZE}
echo "Testing root size (GiB)  = "${rtSIZE}
echo "---------------------------"

# pvcreate --dataalignment 1m /dev/mapper/luksraid
echo Testing: pvcreate /dev/mapper/${NAME}
#pvdisplay      # to check
echo Testing: vgcreate vg /dev/mapper/${NAME}
#vgdisplay      # to check

echo Testing: lvcreate -L 6.6G -n root vg
echo Testing: lvcreate -l +100%FREE -n home vg
#lvdisplay      # to check

