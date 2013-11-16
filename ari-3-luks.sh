#!/bin/bash
# by Wiesław Magusiak
VERSION=0.11

PART0=$(readlink -f $(mdadm -E --scan 2>/dev/null|awk '{print $2}'))
[[ -z "$PART0" ]] && { 
	echo -e "\e[31mWarning! There is no active RAID in the machine.\e[0m"; 
	echo "Trying to activate a RAID by running 'partprobe -s /dev/sd*'";
	partprobe -s /dev/sd* ;
	PART0=$(readlink -f $(mdadm -E --scan 2>/dev/null|awk '{print $2}'));
	[[ -z "$PART0" ]] && { echo -e "It didn't help.\nAborting."; exit 30;}
}

function usage_crypt () {
	echo -e "\n\e[1m${0##*/} (ver. v${VERSION})\e[0m"
	echo -e "The script uses LUKS to format and encrypt a PARTITION with a password,"
	echo "and gives its user some information about available options."
	echo -e "See \e[34;4mhttps://wiki.archlinux.org/index.php/LUKS\e[0m."
	echo -ne "\n\e[1m${0##*/}\e[0m [\e[1m-c\e[0m cypher] [\e[1m-s\e[0m size\e[0m] ["
	echo -e "\e[1m-h\e[0m hash] [\e[1m-i\e[0m miliosec] [\e[1m-R\e[0m] \e[1mPARTITION\e[0m"
	echo -e "\nWhere:"
	echo -e "\tParameters -c, -s, -h, -i are used by the 'cryptsetup' command, see below."
	echo -e "\tPARTITION is the partition to encrypt (defaults to \e[1m${PART0}\e[0m)."
	echo -e "\tThe \e[1m-R\e[0m option tells the script to actually run 'cryptsetup';"
	echo -e "\t\e[32mOtherwise it is just a dry run.\e[0m"
	echo -e "\tSee default values below:"
}

function press_a_key () {
	echo -n "Press a key for more information."
	read -srn1
}

while getopts  c:s:h:i:R flag; do
    case "$flag" in
		c) CYPHER="$OPTARG";;
		s) SIZE="$OPTARG";;
		H) HASH="$OPTARG";;
		i) ITIME="$OPTARG";;
		R) RUN="1";;
		?) true;;
	esac
done
shift $((OPTIND-1))
PART=${1-$PART0}
CYPHER=${CYPHER-aes-xts-plain64}
SIZE=${SIZE-512}
HASH=${HASH-sha512}
ITIME=${ITIME-5000}
RUN=${RUN-0}

(( $UID )) || { 			# The condition to be removed after testing; commands remain
	modprobe dm-mod 		#already there
	modprobe dm-crypt
}

(($RUN)) || { 				# Usage info
	usage_crypt;
	# -c = --cipher, -s = --key-size, -h = --hash,
	# -i = --iter-time, -y = --verify-passphrase
	echo -e "\ncryptsetup -c aes-xts-plain64\t# cypher (use this default for disks >2TiB)
           -s 512       \t# key size
           -h sha512    \t# hash algorithm for PBKDF-2
           -i 5000      \t# iter-time: time for iterations
           --use-random \t# enforce generation of high entropy master key
           -y           \t# verify password by forcing double entry
           luksFormat   \t# action name: Format for dm-crypt with LUKS 
           ${PART0}   \t# partition to encrypt\n";
}

(($RUN)) && echo "Running:" || { press_a_key;
	echo -e "\e[1m\rIt is a dry run.                 \e[0m";
	echo -e "Use the \e[32;1m-R\e[0m option to actually encrypt ${PART} by running:";}
echo -ne "\e[1mcryptsetup\e[0m -c \e[1m${CYPHER}\e[0m -s \e[1m${SIZE}\e[0m -h \e[1m${HASH}"
echo -e "\e[0m -i \e[1m${ITIME}\e[0m --use-random -y luksFormat \e[1m${PART}\e[0m"

(($RUN)) && { 
	echo "cryptsetup -c $CYPHER -s $SIZE -h $HASH -i $ITIME --use-random -y luksFormat ${PART}";
	# 'luksraid' (see below) is just an arbitrary name
	echo cryptsetup luksOpen ${PART} luksraid
} || { 
	echo -e "\n\e[32;1mAvailable RAID partitions: ";
	echo -e "\t$(readlink -f $(mdadm -D --scan|awk '{print $2}'))\e[0m";
	echo -e "\nConsider running:\n\t\e[32mcryptsetup --help\e[0m";
	echo -e "and\n\t\e[32mcryptsetup benchmark\e[0m\nbefore this script.";
	echo -e "The latter helps to chose a different cypher.";
	echo -e "\nNormally, the default options are advisable. Running";
	echo -e "\t\e[32mbash ${0##*/} -R\e[0m\nor\n\t\e[32mbash ${0##*/} -R ${PART0}\e[0m"
	echo -e "might be the best choice."
	echo -e "\n\e[31;1mHowever, be extremely careful if you have more than one RAID."
	echo -e "Do not use the default RAID partition without thinking.\e[0m"
}

