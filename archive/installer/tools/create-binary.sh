#!/bin/bash

WDIR=/usr/local/lastcontrol
LCBINARY=/tmp/lc-binary
PREFIX=lc

SCRIPTLIST=$(ls $WDIR/scripts/linux |grep -v create-report-linux.sh |grep -v allreports.sh | cut -d "." -f1 > /tmp/scriptlist.txt)
SCRIPTCOUNT=$(cat /tmp/scriptlist.txt | wc -l)
rm -r $LCBINARY
mkdir -p $LCBINARY

i=1
while [ "$i" -le "$SCRIPTCOUNT" ]; do
	SCRIPT=$(ls -l |sed -n $i{p} /tmp/scriptlist.txt)
	echo $SCRIPT
	shc -U -r -f $WDIR/scripts/linux/$SCRIPT.sh -o $LCBINARY/$PREFIX-$SCRIPT
i=$(( i + 1 ))
done

#scp -r -P22 $LCBINARY esmerkan.com:/tmp/
