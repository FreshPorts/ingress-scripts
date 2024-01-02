#!/bin/sh

ABI=$(./current_list_of_valid_abi.sh)

in_list=''
#echo $ABI
for abi in ${ABI}
do
#  echo $abi
  if [ "$in_list" == "" ]
  then
    in_list="'${abi}'"
  else
    in_list="${in_list}, '${abi}'"
  fi
done

#echo $in_list

query="DELETE FROM abi where name not in (${in_list})"

echo $query
