#!/bin/sh

# pathname to file we want to move
fullfilename=$1

# just the filename, no path
filename=`basename $fullfilename`

# remove the trailing .raw
destfilename=`basename $filename .raw`

sudo mv -i $fullfilename ~ingress/message-queues/incoming/${destfilename}
