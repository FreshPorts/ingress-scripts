#!/bin/sh
cd ~freshports/message-queues/recent
FILES=`ls *.errors`
for file in ${FILES}
do
  basefilename=`basename ${file} .errors`
  sudo mv -i ${basefilename}.xml ~ingress/message-queues/incoming/
done
