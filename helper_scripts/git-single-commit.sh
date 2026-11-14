#!/bin/sh

# tell ingress to run a commit
#
# usage: git-single-commit.sh repo commit [branch]
#
# branch is main (the default) or a quarterly branch such as 2026Q4, and is
# passed on to git_proc_commit's git-single-commit.sh, which records it in
# the XML.  Without it, a quarterly-branch commit would be filed under main.

REPO=$1
COMMIT=$2
BRANCH=${3:-main}

echo /usr/local/libexec/freshports/git-single-commit.sh $REPO $COMMIT $BRANCH | sudo su -fm ingress
