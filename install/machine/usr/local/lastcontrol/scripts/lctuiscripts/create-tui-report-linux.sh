#!/bin/bash

WDIR=/usr/local/lastcontrol
RDIR=/usr/local/lastcontrolreports
SCRIPTS=$WDIR/scripts
TUISCRIPTS=lctuiscripts
LCKEY=/root/.ssh/lastcontrol

rm -r $RDIR/$2

scp -r -P22 -i $LCKEY $SCRIPTS/$TUISCRIPTS root@$2:/usr/local/
ssh -p22 -i $LCKEY root@$2 -- bash /usr/local/$TUISCRIPTS/$1.sh

mkdir -p $RDIR/$2
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.txt $RDIR
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-$1.md $RDIR

# copying report attachments
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-listeningservice.txt $RDIR
scp -r -P22 -i $LCKEY root@$2:/usr/local/lcreports/$2/$2-establishedservice.txt $RDIR
