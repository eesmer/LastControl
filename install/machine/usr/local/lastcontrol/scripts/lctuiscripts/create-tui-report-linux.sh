#!/bin/bash

WDIR=/usr/local/lastcontrol
RDIR=/usr/local/lastcontrolreports
LCSCRIPTS=$WDIR/scripts/lctuiscripts
LCKEY=/root/.ssh/lastcontrol
###LCSCRIPTPATH=/usr/local/lcscripts
###LCREPORTPATH=/usr/local/lcreports

rm -r $RDIR/$2

scp -r -P22 -i $LCKEY $LCSCRIPTS root@$2:/usr/local/

exit 1

ssh -p22 -i $LCKEY root@$2 -- bash $LCSCRIPTS/$1.sh

mkdir -p $RDIR/$2
scp -r -P22 -i $LCKEY root@$2:$LCSCRIPTS/$2/$2-$1.txt $RDIR
scp -r -P22 -i $LCKEY root@$2:$LCSCRIPTS/$2/$2-$1.md $RDIR

# copying report attachments
scp -r -P22 -i $LCKEY root@$2:$LCSCRIPTS/$2/$2-listeningservice.txt $RDIR
scp -r -P22 -i $LCKEY root@$2:$LCSCRIPTS/$2/$2-establishedservice.txt $RDIR

##echo "" >> $RDIR/$2-$1.md
##echo "![](/tmp/lastcontrol_logo.png){ width=25% }" >> $RDIR/$2-$1.md

#echo ""
#cat $RDIR/$2-$1.txt

#NUMMACHINE=$(cat $WDIR/linuxhost | wc -l)
#i=1
#while [ "$i" -le "$NUMMACHINE" ]; do
#	LINUXMACHINE=$(ls -l |sed -n $i{p} $WDIR/linuxhost)
#	
#	scp -r -P22 -i $LCKEY $CLSCRIPTS root@$LINUXMACHINE:/usr/local/
#	ssh -p22 -i $LCKEY root@$LINUXMACHINE -- bash /usr/local/cl-scripts/run-scripts.sh
#
#	mkdir -p $RDIR/$LINUXMACHINE
#	scp -r -P22 -i $LCKEY root@$LINUXMACHINE:/usr/local/lastcontrol-reports/$LINUXMACHINE  /usr/local/lastcontrolreports/
#
#	ssh -p22 -i $LCKEY root@$LINUXMACHINE -- bash /usr/local/cl-scripts/clear-reports.sh
#
#i=$(( i + 1 ))
#done
