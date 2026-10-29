#!/bin/sh

# tell ingress to run a commit

REPO=$1
COMMIT1=$2
COMMIT2=$3

echo /usr/local/libexec/freshports/git-range-of-commits.sh $REPO $COMMIT1 $COMMIT2 | sudo su -fm ingress
