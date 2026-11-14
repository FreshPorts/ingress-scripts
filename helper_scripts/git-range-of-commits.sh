#!/bin/sh

# tell ingress to run a range of commits
#
# usage: git-range-of-commits.sh repo from to [branch]
#
# Processes the commits after from, up to and including to.  branch is main
# (the default) or a quarterly branch such as 2026Q4, and is passed on to
# git_proc_commit's git-range-of-commits.sh, which records it in the XML.
# Without it, quarterly-branch commits would be filed under main.

REPO=$1
COMMIT1=$2
COMMIT2=$3
BRANCH=${4:-main}

echo /usr/local/libexec/freshports/git-range-of-commits.sh $REPO $COMMIT1 $COMMIT2 $BRANCH | sudo su -fm ingress
