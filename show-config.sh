#!/bin/sh

if [ ! -f config.sh ]
then
	echo "config.sh not found by missing-port-categories.sh..."
	exit 1
fi

. config.sh

repos="doc ports ports-quarterly src"
for repo in $repos
do
  dir=$(convert_repo_label_to_directory ${repo})
  echo $repo becomes $dir
done
