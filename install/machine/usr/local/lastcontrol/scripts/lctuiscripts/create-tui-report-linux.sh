#!/bin/bash

WDIR=/usr/local/lastcontrol
RDIR=/usr/local/lastcontrolreports
SCRIPTS=$WDIR/scripts
TUISCRIPTS=lctuiscripts
LCKEY=/root/.ssh/lastcontrol
NONSHOW=/dev/null
BOARDFILE=/usr/local/lastcontrol/doc/board.txt

rm -r $RDIR/$2

scp -r -P22 -i $LCKEY $SCRIPTS/$TUISCRIPTS root@$2:/usr/local/ >> $NONSHOW
ssh -p22 -i $LCKEY root@$2 -- bash /usr/local/$TUISCRIPTS/$1.sh

mkdir -p $RDIR/$2
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.txt $RDIR >> $NONSHOW
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.md $RDIR >> $NONSHOW

# copying report attachments
if [ "$1" = servicereport ]; then
	scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-listeningservice.txt $RDIR >> $NONSHOW
	scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-establishedservice.txt $RDIR >> $NONSHOW
fi

echo "Info: $1 generated." > $BOARDFILE
