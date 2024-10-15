#!/bin/bash

#---------------------------------------------
# LastControl Check Distro
# 
#---------------------------------------------

source ./common.sh

CHECK_DISTRO(){
	$BLUE
	echo "Checking Distro.."
	$NOCOL
	if grep -qi "debian\|ubuntu" /etc/*-release; then
		REP=APT
	elif grep -qi "centos\|rocky\|red hat\|alma\|fedora" /etc/*-release; then
		REP=YUM
	elif grep -qi "arch" /etc/*-release; then
		REP=PACMAN
	elif grep -qi "suse" /etc/*-release; then
		REP=ZYPPER
	else
		REP=""
	fi
	
	if [[ "$REP" != "APT" && "$REP" != "YUM" ]]; then
		$RED
		echo "--------------------------------------------------------------"
		echo -e "Repository could not be detected.\nThis distro is not supported"
		echo "--------------------------------------------------------------"
		$NOCOL
		exit 1
	fi
}
