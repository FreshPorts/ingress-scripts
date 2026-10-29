#!/bin/sh

# pathname to file we want to move
fullfilename=$1

sudo mv -i $fullfilename ~ingress/message-queues/incoming/
