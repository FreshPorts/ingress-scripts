#!/bin/sh

#ABI=$(./current_list_of_valid_abi.sh)
ABI=$(cat)

in_list=''
#echo $ABI
for abi in ${ABI}
do
#  echo $abi
  if [ "$in_list" == "" ]
  then
    in_list="('${abi}')"
  else
    in_list="${in_list}, ('${abi}')"
  fi
done

#echo $in_list

query="
with new_and_old as (
WITH current_abi_list as (
select name 
  from (VALUES $in_list)
   v(name))
select current_abi_list.name as name, abi.name as missing from current_abi_list left outer join abi on current_abi_list.name = abi.name) 
insert into abi (name)
select name from new_and_old where missing is null;"

echo $query
