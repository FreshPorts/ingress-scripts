#!/bin/sh

# tell ingress to run a commit

REPO=$1
COMMIT=$2

echo /usr/local/libexec/freshports/git-single-commit.sh $REPO $COMMIT | sudo su -fm ingress
