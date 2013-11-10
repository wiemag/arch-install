#!/bin/bash
# by Wiesław Magusiak
# Configuring language settings: 
# keyboard layout, font, locale (language+charset)
# It has to work under the zsh shell of arch linux installation medium.

VERSION=0.99
KB="us"					# Keyboard layout (pl, de, cz, fr, uk, ru...)
FONT="lat2-16" 			# Font for the language
LOCALE="en_US.UTF-8"	# Languag locale; see /etc/locale.gen (e.g. pl_PL.UTF-8)
						# If LOCALE="", set only 
i=0 					# Installation step number
EFI=0 					# Is it going to be an EFI setup?
Q="N" 					# A temporary variable used for yes/no question

function usage_arinst-1-lang () {
echo -e "\n\e[1;32m${0##*/} (ver.${VERSION})\e[0m"
echo -e "\nUsage:\n\t\e[1m${0##*/} [-k KB] [-f FONT] [-l LOCALE] | -h \e[0m"
echo -e "Where:\n\t\e[1mKB\e[0m is a keyboard layout, e.g. pl, de, ru,..."
echo -e "\t\e[1mFONT\e[0m is a console (tty) font, e.g. lat2-16 or Lat2-Terminus16."
echo -e "\t     For available fonts, browse '/usr/share/kbd/consolefonts/'."
echo -e "\t\e[1mLOCALE\e[0m is a language encoding, e.g. pl_PL.UTF-8"
echo -e "\t     Availavle encodings are listed in '/etc/locale.gen'.\n"
}

[[ $# < 1 ]] && { usage_arinst-1-lang; 
echo -e "\tNo change in the default settings.\n";
	exit;}

while getopts  ":k:f:l:hv?" flag
do
    case "$flag" in
		h|v) usage_arinst-1-lang && exit;;
		k) KB="$OPTARG";
			[[ -z $(ls /usr/share/kbd/keymaps/i386/*/${KB}.map.gz 2>/dev/null) ]] && \
				{ usage; echo -e "\tKeyboard layout \e[1m${KB}\e[0m not found.\n"; exit;} || \
				loadkeys $KB 1>/dev/null;;
		f) FONT="$OPTARG";
			[[ ! -f /usr/share/kbd/consolefonts/${FONT}.psfu.gz ]] && \
				{ usage_arinst-1-lang; 
					echo -e "\tFont \e[1m${FONT}\e[0m does not exist.\n"; exit;};;
		l) LOCALE="$OPTARG";
			[[ -z $(grep "$LOCALE" /etc/locale.gen) ]] && \
				{ usage_arinst-1-lang; 
					echo -e "\tLocale \e[1m${LOCALE}\e[0m not listed in /etc/locale.gen.\n"; 
					exit;} || \
				{ sed -i s/#"$LOCALE"/"$LOCALE"/ /etc/locale.gen;
					#export LANG=${LOCALE%% *}; 
					locale-gen 1>/dev/null; } ;;
	esac
done

#---KEYBOARD LAYOUT (alredy set up)----------------------------
echo -e "($((++i)))\tKeyboard layout/map \e[1m${KB}\e[0m has been set."

#---SETTING UP THE CONSOLE FONT--------------------------------
setfont "$FONT" 							# see /usr/share/kbd/consolefonts
echo -e "($((++i)))\tFont \e[1m${FONT}\e[0m has been set."
#{LOCALE%%_*}

#---SETTING UP THE LOCALE (already set up)---------------------
echo -e "($((++i)))\tLanguage/charset \e[1m${LOCALE}\e[0m has been set."
x="$KB"_$(echo "$KB"|tr "[a-z]" "[A-Z]").UTF-8
if [[ "$x" != "$LOCALE" && -n $(grep "#$x" /etc/locale.gen) ]]; then
	echo -e "\tThe locale $LOCALE does not correspond to the keyboard layout."
	echo -en "\tChange the locale to ${x}?  (y/N) "
	read -e -n1  -t120  Q
	if [[ "$Q" == [Yy] ]]; then
		sed -i s/#"$x"/"$x"/ /etc/locale.gen
		#export LANG=${x}
		locale-gen
		echo -e "\tLanguage/charset has been generated for \e[1m${x}\e[0m."
	fi
fi


################## JUST FOR TESTING: TO BE DELETED LATER ON ###################

#---CHECK IF YOU ARE IN EFI ENVIRONMENT------------------------
#modprobe efivars
[[ -d /sys/firmware/efi ]] && EFI=1
echo -e "($((++i)))\tYou are \e[1m$([[ $EFI = 0 ]] && echo NOT)\e[0m in (U)EFI environment."

#---OPTIONAL: ZERO THE DRIVE---(Go have a cup of coffee)-------
echo -en "($((++i)))\tWipe the drive:  Are you sure you want to do it? (y/N) "
Q="N"
read -e -n1 -t120 Q
if [[ "$Q" == [yY] ]]; then
	echo -e "\tThen go and have a cup of coffee."
##	dd if=/dev/urandom of=/dev/sda
	echo -e "\tDisk cleaned."
fi
