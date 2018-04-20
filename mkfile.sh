#!/bin/bash

dir=/cephfuse/dir1
mkdir $dir

if [ $# -lt 2 ];then
	echo "./mkfile.sh <prefix> <num>"
	exit
fi

prefix=$1
n=$2


for ((i=0; i<$n; i++))
do
	touch $dir/$prefix"_"$i
done
echo "create $n files"

