#!/bin/bash
# by Wiesław Magusiak
#

VERSION=0.93 					# A crude but working version
LOG=${0%.sh}.log 				# A log in the current directory
KROK=1

# TODO:  Modify the script by assing another flag to control whether a boot/EFI partition
# is to be created on the first disk of those chosen for a RAID.
# TODO:  Hava a look to find whether it is possible to replace greps with awks.

# Dependencies: grep [grep], awk [gawk], sed [sed], cut [coreutils], tee [coreutils]
#               bc [bc] (install), sgdisk [gptfdisk]

function usage_raid () {
echo -e "\n\e[32;1m${0##*/} (ver.$VERSION)\e[0m"
echo -e "The script partitions (and wipes if so invoked) disks for RAID installation"
echo -e "calculates the available maximum size for RAID and assembles the array."
echo -e "\e[32;1mIt will remove MBRs/GPTs of chosen disks and creat new ones!\e[0m\n"
echo "Usage:"
echo -e "\t\e[1m${0##*/}\e[0m [\e[1m-r\e[0m \e[4mRAID_type\e[0m] [\e[1m-w\e[0m]"
echo "Where:"
echo -ne "\t\e[1mRAID_type\e[0m is the RAID level and can be 5 or 1 only; "
echo -e "\e[1mDefaults to 5\e[0m."
echo -e "\t\e[1m'-w'\e[0m tells the script to \e[1mwipe the disks\e[0m before partitioning."
}


[[ $USER == "root" ]] || { echo -e "\n\e[31;1mDon't try it at home.";
	echo -e "The script makes major and irreversible modifications to the disks.";
	echo -e "It can only be run by root.\e[0m"; usage_raid;
	exit 20;}

usage_raid
echo -e "${0##*/}.log, $(date +"%Y-%m-%d %H:%M:%S")\n" > ${LOG}


#---BEFORE WE START (ARE THERE ANY RAIDs DEFINED/ACTIVE)------
# Assumption is made that there is only one RAID defined.
echo -ne "\n\e[34;1m"
echo -e "(${KROK})\tChecking if there are any RAID devices defined." | tee -a $LOG
echo -ne "\e[0m"
#partprobe -s /dev/sd* 1>/dev/null 	# This should start RAIDs if they aren't active already.
if [[ $(mdadm -E --scan|wc -l) -gt 0 ]]; then
	echo -e "\e[31;1mYes, there are. They all will be removed!\e[0m"
	echo "Continue?  (Y/n)  "; IFS= read -srn1 Q
	[[ $Q != [yY] && $Q != "" ]] && exit 20
	DEV=$(mdadm -D --scan|cut -d" " -f2)
	if [[ $(echo $DEV | wc -w) -gt 0 ]]; then 				# It must be "-w" here!
		DEV=${DEV/\/0/0}
		x=$(mdadm -D ${DEV}|awk '/dev\/sd/ {print $7}') 	# List of partitions.
		mdadm -S ${DEV}; 					# Stop a RAID
		mdadm --zero-superblock ${x}; 		# Zero out superblocks from partitions.
		echo "Superblocks have been zeroed out from: $(echo ${x})." | tee -a $LOG
	else
		# This part should not be needed if partprobe -s had been used to start inactive RAIDs.
		echo "Be careful! RAID defined but not active." |tee -a ${LOG};
		lsblk | grep -E "sd|md" | tee -a ${LOG}
		x=$(lsblk |awk '/sd.[0-9]/ {print $1}' |sed 's/^../\/dev\//')
		echo "Shall partitions be scanned and superblocks removed?  (Y/n)  "
		IFS= read -srn1 Q
		[[ $Q != [yY] && $Q != "" ]] && exit 20
		for DEV in $x; { (($(mdadm -E ${DEV}|wc -l))) && mdadm --zero-superblock ${DEV};}
		echo "Superblocks have been zeroed out from: $(echo ${x})." | tee -a $LOG
	fi

	echo -ne "\nPress a key to continue."; 	IFS= read -srn1
	echo -ne "\r                        \r"

else
	echo -e "\tNo, there aren't any." | tee -a $LOG
fi


#---INSTALL BASH CALCULATOR OR ABORT--------------------------
which bc 2>/dev/null 1>/dev/null
if (($?)); then
	let KROK+=1
	echo -ne "\n\e[34;1m"
	echo -e "(${KROK})\tInstalling bash calculator." | tee -a ${LOG}
	echo -ne "\e[0m"
	echo -e "Bash calculator is needed for this script to run."
	echo -ne "Running:  \e[1m"; echo "pacman -Sy bc" | tee -a ${LOG}; echo -ne "\e[0m"
	pacman -Sy bc
	(($?)) && { echo "Aborted." | tee -a ${LOG}; exit 28;}
fi


#---INSTALLATION PARAMETERS/OPTIONS---------------------------
while getopts  "r:wh" flag
do
	case "$flag" in
		r) RAID="$OPTARG";; 		# RAID type
		w) WIPE=1;; 				# WIPE DISKS
		h) usage_raid; exit 20;;
	esac
done


#---CHECK IF YOU ARE IN EFI ENVIRONMENT------------------------
[[ -d /sys/firmware/efi/efivars ]] && EFI=1 || EFI=0
#EFI=1  # Testing
let KROK+=1
echo -ne "\e[34;1m"
if [[ $EFI == 0 ]]; then
	echo -e "\n(${KROK})\tYou are NOT in (U)EFI environment." | tee -a $LOG
else
	echo -e "\n(${KROK})\tYou ARE in (U)EFI environment." | tee -a $LOG
	echo -ne "\e[0m\e[33m"
	echo -e "\tA 512 MiB (0.5 GiB) partition will be created" | tee -a $LOG
	echo -e "\ton the first chosen disk." | tee -a $LOG
fi
echo -ne "\e[0m"


#---INFORMATION ON RAID LEVELS SUPPORTED BY THIS SCRIPT-------
if [[ "x$RAID" = "x" ]]; then  # Explanation not needed if the USER has chosen a RAID level.
	echo -ne "\e[34;1m"; 
	echo -e "\n($((++KROK)))\tInformation about number of disks required by this script."
	echo -e "\e[0m\n\tThis script allows RAID 1 and RAID 5 only.\n"
	echo -e "\t\e[1mRAID 1\e[0m:  \e[4mOnly two disks\e[0m are allowed by this script"
	echo -e "\t         in case of disk array level 1.\n"
	echo -e "\t\e[1mRAID 5\e[0m:  \e[4mA minimum of three disks\e[0m is required,"
	echo -e "\t         but more are also acceptable.\n"
	echo -e "\tThe script will force you to choose disks if there are more disks"
	echo -e "\tthan required for a given RAID level."
fi

WIPE=${WIPE-0}			# Do not wipe available sd disks unless invoked otherwise
RAID=${RAID-5} 			# RAID type (defaults to RAID 5)
case $RAID in
	5) NODR=3;modprobe raid5;; 		# No of disks required for RAID 5
	1) NODR=2;modprobe raid1;; 		# No of disks required for RAID 1
	?) usage_raid; echo -e "RAID 5 or RAID 1 only" | tee -a ${LOG}; exit 21;;
esac
 					# Testing:  Is it going to be an EFI setup? 
 					# Testing:  To be checked later and modified accordingly.

function wipe_disk () { true;
	# dd if=/dev/urandom of=/dev/${1}; 
}
function usb_in () { 	# Not used; Shows if any usb drives are put in.
	echo $(ls -l /sys/block|grep usb|wc -l)
}
function disks_available {
	DISKS=""; j=0
	for DEV in /sys/block/sd*; do
		(( $(<${DEV}/removable) )) || { DISKS=${DISKS}" "${DEV##*/}; ((j++));}
	done
	echo ${j}${DISKS} 		# No of non-removable disks available and their names
}


#---INSTALLATION PARAMETERS-----------------------------------
let KROK+=1
echo -ne "\e[34;1m"
echo -e "\n(${KROK})\tInstallation parameters." | tee -a ${LOG}
echo -ne "\e[0m\e[1m"
echo -e "\n\tRAID type ${RAID}" | tee -a ${LOG}
echo -ne "\e[0m"
echo -e "\tNumber of disks required  = ${NODR}" | tee -a ${LOG}
x=$(disks_available)
NODA=${x%% *}
DISKS=${x#* } 					# Available DISK device names
echo -e "\tNumber of disks available = ${NODA}" | tee -a ${LOG}
echo -ne "\tAvailable 'sd' disks:  " | tee -a ${LOG}
echo -e "\e[1m$(echo ${DISKS} | tee -a ${LOG})\e[0m"

#NODR=3 							# Just for testing
#NODA=5 							# Just for testing
#DISKS="sda sdb sdc sdd sde" 	# Just for testing
#echo -e "\e[32;1mTesting NODR=$NODR \e[0m"
#echo -e "\e[32;1mTesting NODA=$NODA \e[0m"
#echo -e "\e[32;1mTesting DISKS=$DISKS \e[0m"
#echo ""

#---NOT ENOUGH DISKS------------------------------------------
if [[ $NODA -lt $NODR ]]; then
	echo -e "\tToo few disks (just ${NODA}) for RAID type ${RAID}." | tee -a ${LOG}
	exit 21
fi

#---(MORE THAN) ENOUGH DISKS----------------------------------
if [[ $NODA -gt $NODR ]]; then 		# Choose disks to be used by RAID
	echo -e "Number of disks available is larger than that required." | tee -a ${LOG}
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
			echo
			cont=0
		elif [[ $Q == [aA] ]]; then
			echo "Aborted. Nothing done." | tee -a ${LOG}
			exit 20
		fi
	done
else
	CHOSEN=${DISKS}
	NODC=$NODA 							# Number of disks chosen for RAID
fi
echo -e "\tThe chosen disks:  ${CHOSEN}" >> ${LOG}

#echo -e "\e[32;1mTesting  CHOSEN=$CHOSEN \e[0m"
#echo -e "\e[32;1mTesting  NODC=$NODC \e[0m"

#---WIPE CHOSEN DISKS (OPTIONAL)------------------------------
if [[ $WIPE -gt 0 ]]; then
	let KROK+=1
	echo -ne "\e[34;1m"
	echo -e "\n(${KROK})\tWiping the chosen disks." | tee -a ${LOG}
	echo -ne "\e[31;1mWarning! The disk"
	[[ $NODC -gt 1 ]] && echo 's are about to be wiped.' || echo -e ' is about to be wiped.'
	echo -e "This operation may take hours.\e[0m\n"
	for ((t=120;--t;)) {
		echo -en "\rContinue?  (y/N)  [\e[33m$t\e[0m sec] "
		IFS= read -rsn1 -t1 Q && break
	}
	if [[ "$Q" != [Yy] || "$Q" == "" ]]; then
		echo -e "\rAborted.                   " | tee -a ${LOG}
		exit 22
	fi
	echo -e "\nThen go and have a bucket of coffee."
	echo -e "\e[1mNOT REALLY. Just joking! Wipe 'em manually!\e[0m" 	# Testing
	for DEV in $CHOSEN; do
		echo -e "\tWiping ${DEV}..."
		echo -e "\tdd if=/dev/urandom of=/dev/${DEV}" | tee -a ${LOG}
        wipe_disk ${DEV} 					# ACTUAL WIPING! SEE wipe_disk function
	done;
	echo -e "\tDisk(s) wiped.\n" | tee -a ${LOG}
fi


#---LAST WARNING BEFORE PARTITIONING (NOT NEEDED IF WIPED)-----
if [[ $WIPE -eq 0 ]]; then 		# No need to warn when disks have been wiped.
	echo -e "\nThe chosen disks (\e[1m${CHOSEN}\e[0m) are about to be partitioned."
	for ((t=120;--t;)) {
		echo -en "\rContinue?  (Y/n)  [\e[33m$t\e[0m sec] "
		IFS= read -rsn1 -t1 Q && break
	}
	if [[ "$Q" != [yY] && "x$Q" != "x" ]]; then
		echo -e "\rAborted.                   " | tee -a ${LOG}
		exit 23
	fi
fi


#---INSTALL GPTFDISK IN NECESSARY (should be already there)----
# Install gptfdisk if necessary. (Provides gdisk, cgdisk, sgdisk, fixparts)
which sgdisk 2>/dev/null 1>/dev/null
(( $? )) && { let KROK+=1; echo -e "\r                                 ";
	echo -ne "\e[34;1m";
	echo -e "\n(${KROK})\tThe gptfdisk package needs to be installed." | tee -a ${LOG};
	echo -ne "\e[0m";
	sudo pacman -Sy gptfdisk;
	(( $? )) && { echo "Aborted!" | tee -a ${LOG}; exit 23;}; }


#---CREATING GPT DISK(s) (Both for EFI and MBR)----------------
let KROK+=1
echo -e "\e[34;1m\r                                 "
echo -e "(${KROK})\tCreating GPT disks." | tee -a ${LOG}
echo -e "\e[0m"
# Remove previous GPT/MBR data and set alignment.
# Using "/dev/sd[abc] is not possible.
for DEV in $CHOSEN; do 				# ACTUAL DISKS MODIFICATIONS!!!!
	echo -e "\tsgdisk -Z /dev/${DEV}" | tee -a ${LOG}
	sgdisk -Z /dev/${DEV} 			# Destroy MBR and GPT data (clean the disk)
	echo -e "\tsgdisk -a 2048 -o /dev/${DEV}" | tee -a ${LOG}
	sgdisk -a 2048 -o /dev/${DEV} 	# Clear out all partition data; -a sets alignment
done 								# in In fact, 2048 is the default

#---Create "EFI" partition (512MiB, vfat, label EFI)-----------
DEV0=${CHOSEN%% *}
if [[ $EFI == 1 ]]; then
	let KROK+=1
	echo -ne "\e[34;1m"
	echo -e "\n(${KROK})\tCreating a 512-MiB EFI partition on ${DEV0}." | tee -a ${LOG}
	echo -ne "\e[0m"
	[[ $DEV0 != "sda" ]] && 
		echo -e "\e[1mWarning!\e[0m The EFI partition should be on /dev/sda."
	echo sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI /dev/${DEV0} | tee -a ${LOG}
	sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI /dev/${DEV0} 	# ACTUAL DISKS MODIFICATIONS!!!!
fi


#---CREATE PARTITIONS FOR RAID: SIZE---------------------------
((EFI)) && echo -e "\nThere is a 0.5 GiB EFI partition on ${DEV0}."
let KROK+=1
echo -ne "\e[34;1m"
echo -e "\n(${KROK})\tFree disk-surface space for partitioning:" | tee -a ${LOG}
echo -ne "\e[0m"
for DEV in $CHOSEN; do
	x=$(cat /sys/block/${DEV}/size) 		# Size in sectors.
	y=$(blockdev --getss /dev/${DEV})		# Logical sector size.
	s=$(echo "$x * $y / 1024 / 1024"|bc)
	#s=$((x * y / 1024 / 1024))
	u="MiB"
	s=${s%.*}
	[[ $DEV == $DEV0 ]] && { s=$(($s - $((EFI?1:0))*512)); s0=$s;} # 512 MiB
	printf "%s: %14d MiB  %9.1f GiB\n" $DEV $s $(echo "scale=2; $s / 1024" |bc) | tee -a $LOG
	(($(echo "$s < $s0"|bc))) && s0=$s 	# s0 is the smallest free disk-surface on the disks
done
echo -ne "The smallest disk area for RAID: " | tee -a ${LOG}
echo -ne "\e[1m"
echo -ne "${s0} MiB" | tee -a ${LOG}
echo -e "($(echo "scale=2; $s0 / 1024" |bc) GiB)." | tee -a ${LOG}
echo -ne "\e[0m"
echo -ne "\e[32m"
echo -ne "Decrease the smallest size by 17 MiB " | tee -a ${LOG}
echo -e "(1 at the beginning, 16 at the end)." | tee -a ${LOG}
echo -ne "\e[0m"
s0=$((s0 - 17))


#---CREATE PARTITIONS FOR RAID---------------------------------
# It is possible to clone partitions with sgdisk (--backup/--load-backup)
# sgdisk does not accept floating point numbers for partition size!
i=0; x="RAID${RAID}"
let KROK+=1
echo -ne "\e[34;1m"
echo -e "\n(${KROK})\tCreating partitions for ${x}:" | tee -a ${LOG}
echo -ne "\e[0m"
for DEV in ${CHOSEN}; do
	((i++)) && 
	echo -e "\tsgdisk -a 2048 -n 1:0:+${s0}M -t 1:fd00 -c 1:$x /dev/${DEV}" |tee -a $LOG || 
	echo -e "\tsgdisk -a 2048 -n $((1+EFI)):0:+${s0}M -t $((1+EFI)):fd00 -c $((1+EFI)):$x /dev/${DEV}" |tee -a $LOG
	((i--))
	((i++)) && sgdisk -a 2048 -n 1:0:+${s0}M -t 1:fd00 -c 1:$x /dev/${DEV} || 
	sgdisk -a 2048 -n $((1+EFI)):0:+${s0}M -t $((1+EFI)):fd00 -c $((1+EFI)):$x /dev/${DEV}
done


#---CHECK CREATED PARTITIONS-----------------------------------
echo -e "\nVerify disk partitions:" |tee -a $LOG
echo -e "partprobe -s /dev/sd*" |tee -a $LOG
for DEV in $CHOSEN; { partprobe -s /dev/${DEV};}
echo -e "\e[32mRun \e[1;32msgdisk -p /dev/sd*\e[0;32m to see all the partitions details.\e[0m"
#for DEV in $CHOSEN; do
#	sgdisk -p /dev/${DEV}
#done


# Prepare partitions for the creation of a RAID5 device
# modprobe dm-mod  # already there

#for DEV in $CHOSEN; do
#	echo hdparm -W 0 /dev/${DEV} 	# Disable the disk write cache
#done

# Create a RAID5 device
# -C = --create, -l = --level, -n = --raid-devices
# To avoid the initial resync with new hard drives add --assume-clean

#---CREATE RAID DEVICE: /dev/md0-------------------------------
let KROK+=1
echo -ne "\e[34;1m"
echo -e "\n(${KROK})\tCreating RAID${RAID}." | tee -a ${LOG}
echo -ne "\e[0m"
s=" ${CHOSEN}"
s=${s// sd/ \/dev\/sd}
s="${s# } "
s=${s// /1 }
((EFI)) && s=${s/1/2}
s="${s% } "
echo -ne "\e[1m"
echo -ne "mdadm -C /dev/md0 -l${RAID} -n${NODC} --assume-clean ${s}" | tee -a ${LOG}
echo -e "\e[0m"
mdadm -C /dev/md0 -l${RAID} -n${NODC} --assume-clean ${s}
echo "cat /proc/mdstat"
cat /proc/mdstat
#mdadm -C /dev/md0 -l5 -n3 /dev/sda2 --assume-clean /dev/sd[bc]1

echo -e "\nA RAID${RAID} has been created and is active."
echo -e "\e[1mA log file has been created. See ${LOG} in the current directory.\e[0m"
echo "Go on to encrypt it and make lvm2 system."
