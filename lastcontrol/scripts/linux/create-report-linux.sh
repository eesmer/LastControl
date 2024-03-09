#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

WDIR=/usr/local/lastcontrol
RDIR=$WDIR/reports
SCRIPTS=$WDIR/scripts
TUISCRIPTS=linux
LCKEY=/root/.ssh/lastcontrol
BOARDFILE=/usr/local/lastcontrol/doc/board.txt

rm -r $RDIR/$2* 2>/dev/null

scp -r -P22 -i $LCKEY $SCRIPTS/$TUISCRIPTS root@$2:/usr/local/ &> /dev/null
ssh -p22 -i $LCKEY root@$2 -- bash /usr/local/$TUISCRIPTS/$1.sh &> /dev/null

mkdir -p $RDIR/$2
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.txt $RDIR/$2 &> /dev/null
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.md $RDIR/$2 &> /dev/null
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.json $RDIR/$2 &> /dev/null

# copying report attachments
if [ "$1" = servicereport ]; then
	scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-listeningservice.txt $RDIR/$2 &> /dev/null
	scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-establishedservice.txt $RDIR/$2 &> /dev/null
fi

echo "Info: $1 generated." > $BOARDFILE
