#!/bin/sh
cd ~freshports/message-queues/retry
FILES=`ls *.raw`
for file in ${FILES}
do
  destfilename=`basename ${file} .raw`
  sudo mv -i ${file} ~ingress/message-queues/incoming/${destfilename}
done
