#!/bin/bash

######################
# Create TXT Report File
######################
rm $RDIR/$HOST_NAME.txt
cat > $RDIR/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE

