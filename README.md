Arch Linux Installation Helper Scripts
--------------------------------------


These (bash) scripts help install arch linux:
- set language, fonts and keyboard
- prepare GPT disks
- set up RAID (type 5 or 1)
- encrypt the RAID
- create lvm2 
- install arch linux on such a hardware/software setup
Note that arch linux installation media run in zsh shell.

The scripts names suggest the order of use.

- ari-1-lang.sh
- ari-2-raid.sh
- ari-3-luks.sh

	WARNING!

	THIS IS NEITHER FINISHED WORK NOR WILL IT BE FINISHED SOON OR EVEN EVER. It depends on author's spare time and good moods. BEING A WORK IN PROGRESS THESE SCRIPTS MAY BE DANGEROUS TO USE, with an exception of the first one. DO NOT USE THEM.

However, they may be treated as a check list for arch linux installation or a base for further development.


USAGE

(1) Download a given script from here

	curl -o ari-1-lang.sh -L https://raw.github.com/wiemag/arch-install/master/ari-1-lang.sh

	curl -o ari-2-raid.sh -L https://raw.github.com/wiemag/arch-install/master/ari-2-raid.sh

	curl -o ari-3-luks.sh -L https://raw.github.com/wiemag/arch-install/master/ari-3-luks.sh

(2) Change permissions for the script to be executable

	chmod a+x arinst-*

(3) Run them without any parameters/flag first to see available options

	./arinst-1-lang.sh

or through bash

	bash arch-1-lang.sh

(4) Run them with chosen options, e.g.

	bash arinst-1-lang.sh -k pl -f lat2-16 -l pl_PL.UTF-8

NEVER RUN THESE SCRIPTS ON YOUR COMPUTER!!!

YOU MAY TRY THEM IN A VIRTUAL MACHINE
