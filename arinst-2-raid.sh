#!/bin/bash
# by Wiesław Magusiak
#

VERSION=0.91
#f=${0%.sh} 				# CONF=${f}.conf # If conf were to be used.

function usage_raid () {
echo -e "\n\e[32;1m${0##*/} (ver.$VERSION)\e[0m"
echo -e "The script partitions and wipes (if so invoked) disks for RAID installation.\n"
echo "Usage:"
echo -e "\t\e[1m${0##*/}\e[0m [\e[1m-r\e[0m \e[4mRAID_type\e[0m] [\e[1m-w\e[0m]"
echo "Where:"
echo -e "\tRAID_type defines the RAID type and defaults to 5."
echo -e "\tFlag \"-w\" tells the script to wipe the disks before partitioning."
}

#---INSTALL BASH CALCULATOR OR ABORT--------------------------
which bc 2>/dev/null 1>/dev/null
(($?)) && { echo -e "\n\e[32;1m${0##*/} (ver.$VERSION)\e[0m"; 
	echo "The script prepares disks for RAID and sets up RAID 5 or 1."
	echo -e "\e[1mBash calculator is needed for this script to run.";
	echo -e "Running:  pacman -Sy bc\e[0m";
	pacman -Sy bc; (($?)) && { echo "Aborted."; exit 28;} || clear; }


#---INSTALLATION PARAMETERS/OPTIONS---------------------------
while getopts  "r:wh" flag
do
	case "$flag" in
		r) RAID="$OPTARG";; 		# RAID type
		w) WIPE=1;; 				# WIPE DISKS
		h) usage_raid; exit 20;;
	esac
done

(( $# )) || usage_raid

#---INFORMATION ON RAID LEVELS SUPPORTED BY THIS SCRIPT-------
echo -e "\n\t*=====================================================*"
echo -e "\t*   This script allows RAID 1 and RAID 5 only.        *"
echo -e "\t*                                                     *"
echo -e "\t*   \e[1mRAID 1\e[0m:  \e[4mOnly two disks\e[0m are allowed here.         *"
echo -e "\t*   \e[1mRAID 5\e[0m:  \e[4mA minumum of three disks\e[0m is required.    *"
echo -e "\t*                                                     *"
echo -e "\t*   The script will force you to choose disks         *"
echo -e "\t*   if you have more disks available in the machine.  *"
echo -e "\t*-----------------------------------------------------*"

#---CHECK IF YOU ARE IN EFI ENVIRONMENT------------------------
[[ -d /sys/firmware/efi/efivars ]] && EFI=1 || EFI=0
EFI=1  # Testing
if [[ $EFI == 0 ]]; then
	echo -e "\t*   You are \e[1mNOT\e[0m in (U)EFI environment.                *"
else
	echo -e "\t*   You \e[1mARE\e[0m in (U)EFI environment.                    *"
	echo -e "\t*   \e[33mA 512 MiB (0.5 GiB) partition will be created\e[0m     *"
	echo -e "\t*   \e[33mon the first chosen disk.\e[0m                         *"
fi
echo -e "\t*=====================================================*"

WIPE=${WIPE-0}			# Do not wipe available sd disks unless invoked otherwise
RAID=${RAID-5} 			# RAID type (defaults to RAID 5)
case $RAID in
	5) NODR=3;; 		# No of disks required for RAID 5
	1) NODR=2;; 		# No of disks required for RAID 1
	?) usage_raid; echo -e "\nRAID 5 or RAID 1 only"; exit 2
esac
 					# Is it going to be an EFI setup? 
 						# Checked later and modified accordingly.

function wipe_disk () { 
	echo -e "\tdd if=/dev/urandom of=/dev/${1}"; 
}
function usb_in () {
	echo $(ls -l /sys/block|grep usb|wc -l)
}
function disks_available {
	DISKS=""; j=0
	for DEV in /sys/block/sd*; do
		(( $(<${DEV}/removable) )) || { DISKS=${DISKS}" "${DEV##*/}; ((j++));}
	done
	echo ${j}${DISKS} 		# No of non-removable disks available and their names
}


#---INSTALLATION PARAMETRES-----------------------------------
echo -e "\n\t\e[1mRAID type ${RAID}\e[0m"
echo -e "\tNumber of disks required  = ${NODR}"
x=$(disks_available)
NODA=${x%% *}
DISKS=${x#* } 					# Available DISK device names
echo -e "\tNumber of disks available = ${NODA}"
echo -e "\tAvailable 'sd' disks:  \e[1m${DISKS}\e[0m\n"

#NODR=3 							# Just for testing
#NODA=5 							# Just for testing
#DISKS="sda sdb sdc sdd sde" 	# Just for testing
#echo -e "\e[32;1mTesting NODR=$NODR \e[0m"
#echo -e "\e[32;1mTesting NODA=$NODA \e[0m"
#echo -e "\e[32;1mTesting DISKS=$DISKS \e[0m"
#echo ""

#---NOT ENOUGH DISKS------------------------------------------
if [[ $NODA -lt $NODR ]]; then
	echo -e "\tToo few disks (just ${NODA}) for RAID type ${RAID}."
	exit 21
fi

#---(MORE THAN) ENOUGH DISKS----------------------------------
if [[ $NODA -gt $NODR ]]; then 		# Choose disks to be used by RAID
	echo -e "Number of disks available is larger than that required."
	for ((cont=1; ((cont)); )); do
		echo -e "Disks available:  \e[1m${DISKS}\e[0m"
		AVA=$NODA; NODC=0;
		CHOSEN=" $DISKS"
		for DEV in $DISKS; do
			if [[ $RAID == 5 ]]; then
				echo -ne "Shall \e[1m${DEV}\e[0m be used?  (Y/n/a)   "
				IFS= read -srn1 Q
				[[ $Q == [yY] || $Q == "" || $Q == [aA] ]] && echo "Yes" || { echo "No"; 
					CHOSEN=${CHOSEN/" $DEV"/}; ((((--AVA))-NODR)) || break;}
				[[ $Q == [aA] ]] && { CHOSEN=${DISKS}; AVA=$NODA; 
					echo -e "\r\e[1mUse them all\e[0m               "; break;}
			else
				echo -ne "Shall \e[1m${DEV}\e[0m be used?  (Y/n)   "
				IFS= read -srn1 Q
				[[ $Q == [yY] || $Q == "" ]] && { echo "Yes";
					((NODR-((++NODC)))) || { CHOSEN=${CHOSEN%${DEV}*}${DEV}; break;};} || 
					{ echo "No"; CHOSEN=${CHOSEN/" $DEV"/}; 
						((((--AVA))-NODR)) || { NODC=$AVA; break;};}
			fi
		done
		CHOSEN=${CHOSEN# }
		[[ $RAID == 5 ]] && NODC=$AVA
		echo -e "The chosen disks:  \e[1m${CHOSEN}\e[0m"
		echo -e "\tContinue? (\e[1mC\e[0m|\e[1m<enter>\e[0m)"
		echo -e "\tChoose a different set of disks? (\e[1mD\e[0m)"
		echo -e "\tAbort? (\e[1mA\e[0m)"
		Q="z"
		until [[ $Q == [cC] || $Q == "" || $Q == [aA] || $Q == [dD] ]]; do
			IFS= read -rsn1 Q
		done
		if [[ $Q == [cC] || $Q == "" ]]; then
			echo " "
			cont=0
		elif [[ $Q == [aA] ]]; then
			echo "Aborted. Nothing done."
			exit 20
		fi
	done
else
	CHOSEN=${DISKS}
	NODC=$NODA 							# Number of disks chosen for RAID
fi

#echo -e "\e[32;1mTesting  CHOSEN=$CHOSEN \e[0m" 	# Just for testing
#echo -e "\e[32;1mTesting  NODC=$NODC \e[0m"			# Just for testing

#---WIPE CHOSEN DISKS (OPTIONAL)------------------------------
if [[ $WIPE -gt 0 ]]; then
	echo -ne "\e[31;1mWarning! The disk"
	[[ $NODC -gt 1 ]] && echo 's are about to be wiped.' || echo -e ' is about to be wiped.'
	echo -e "This operation may take hours.\e[0m\n"
	for ((t=120;--t;)) {
		echo -en "\rContinue?  (y/N)  [\e[33m$t\e[0m sek] "
		IFS= read -rsn1 -t1 Q && break
	}
	if [[ "$Q" != [Yy] || "$Q" == "" ]]; then
		echo -e "\rAborted.                   "
		exit 22
	fi
	echo -e "\nThen go and have a bucket of coffee."
	echo -e "\e[1mNOT REALLY. Just joking! Wipe 'em manually!\e[0m" 	# Testing
	for DEV in $DISKS; do
		echo -e "\tWiping ${DEV}..."
        wipe_disk ${DEV}
	done;
	echo -e "Disk(s) cleaned.\n"
fi


#---LAST WARNING BEFORE PARTITIONING (NOT NEEDED IF WIPED)-----
if [[ $WIPE -eq 0 ]]; then 		# No need to warn when disks have been wiped.
	echo -e "The chosen disks (\e[1m${CHOSEN}\e[0m) are about to be partitioned."
	for ((t=120;--t;)) {
		echo -en "\rContinue?  (Y/n)  [\e[33m$t\e[0m sek] "
		IFS= read -rsn1 -t1 Q && break
	}
	if [[ "$Q" != [yY] && "x$Q" != "x" ]]; then
		echo -e "\rAborted.                   "
		exit 23
	fi
fi


#---INSTALL GPTFDISK IN NECESSARY (should be already there)----
# Install gptfdisk if necessary. (Provides gdisk, cgdisk, sgdisk, fixparts)
which sgdisk 2>/dev/null 1>/dev/null
(( $? )) && { echo -e "\r                                 ";
	echo -e "\tThe gptfdisk package needs to be installed."; 
	sudo pacman -Sy gptfdisk;
	(( $? )) && { echo "Aborted!"; exit 23;}; }


#---CREATING GPT DISK(s) (Both for EFI and MBR)----------------
echo -e "\r                                 "
echo -n "Creating GPT partition table"; [[ $NOC -gt 1 ]] && echo "s." || echo "."
# Remove previous GPT/MBR data and set alignment.
# Using "/dev/sd[abc] is not possible.
for DEV in $CHOSEN; do
	echo -e "\tsgdisk -Z /dev/${DEV}" 			# Destroy MBR and GPT data (clean the disk)
	echo -e "\tsgdisk -a 2048 -o /dev/${DEV}" 	# Clear out all partition data; -a sets alignment
done 									# in In fact, 2048 is the default

#---Create "EFI" partition (512MiB, vfat, label EFI)-----------
DEV0=${CHOSEN%% *}
if [[ $EFI == 1 ]]; then
	echo -e "\nCreating a 512-MB EFI partition on ${DEV0}."
	[[ $DEV0 != "sda" ]] && 
		echo -e "\e[1mWarning!\e[0m The EFI partition should be on /dev/sda."
	echo sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI /dev/${DEV0}
fi


#---CREATE PARTITIONS FOR RAID: SIZE---------------------------
echo -e "\nFree disk-surface space for partitioning:"
((EFI)) && echo There is a 0.5 GiB EFI partition on ${DEV0}.
for DEV in $CHOSEN; do
	x=$(sgdisk -p /dev/${DEV} | head -1|awk '{print $5" "$6 }')
	s=${x% *}; u=${x#* }
	case $u in 			 				# Convert into GiB
		MiB) s=$(echo "scale=1; $s / 1024" |bc);;
		TiB) s=$(echo "scale=1; $s * 1024" |bc);;
	esac
	[[ $DEV == $DEV0 ]] && { s=$(echo "scale=1; $s - $((EFI?1:0))/2"|bc); s0=$s;} # 0.5GiB
	printf "\t%s: %8.1f GiB\n" $DEV $s
	SIZES=$SIZES"$DEV $s "
	(($(echo "$s < $s0"|bc))) && s0=$s 	# s0 is the smallest free disk-surface on the disks
done
echo -e "The samllest disk area for assembling RAID: \e[1m${s0} GiB\e[0m."

#echo "Testing:  SIZES=(${SIZES})" 		# Testing

#---CREATE PARTITIONS FOR RAID---------------------------------
# It is possible to clone partitions with sgdisk (--backup/--load-backup)
i=0; x="RAID${RAID}"
echo -e "\nCreate partitions for ${x}:"
echo THIS IS WRONG!!! THE MINIMUM COMMON FREE SIZE HAS TO BE USED!!! UNLESS...
for DEV in ${CHOSEN}; do
	((i++)) && echo -e "\tsgdisk -a 2048 -n 1:0:-16M -t 1:fd00 -c 1:$x /dev/${DEV}" || 
	echo -e "\tsgdisk -a 2048 -n $((1+EFI)):0:-16M -t $((1+EFI)):fd00 -c $((1+EFI)):$x /dev/${DEV}"
done

# Check the partitions
#for DEV in $CHOSEN; do
#	sgdisk -p /dev/${DEV}
#done

exit 	# Testing

# Prepare partitions for the creation of a RAID5 device
modprobe raid5
#modprobe dm-mod  # already there
# mdadm --zero-superblock /dev/<drive>
echo -e "\nVerify disk partitions:"
echo -e "\tpartprobe -s /dev/sd*"

for DEV in $CHOSEN; do
	echo hdparm -W 0 /dev/${DEV} 	# Disable the disk write cache
done

# Create a RAID5 device
# -C = --create, -l = --level, -n = --raid-devices
# To avoid the initial resync with new hard drives add --assume-clean
mdadm -C /dev/md0 -l5 -n3 /dev/sda2 --assume-clean /dev/sd[bc]1


# Encrypt /dev/md0
modprobe dm-crypt
# -c = --cipher, -s = --key-size, -h = --hash,
# -i = --iter-time, -y = --verify-passphrase
cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random -y luksFormat /dev/md0
cryptsetup luksOpen /dev/md0 luksraid

