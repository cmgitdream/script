#!/bin/bash

mds=a
mds_rank=0
fs_name=fs1
meta_pool=metadata
data_pool=data

echo umount /cephfuse
umount /cephfuse
pkill gdb
pkill ceph-mds

n=5
i=0
while [ $i -lt $n ]
do
	echo try $i
	ceph mds fail $mds_rank
	ceph fs rm $fs_name --yes-i-really-mean-it
	rados purge $data_pool --yes-i-really-really-mean-it
	rados purge $meta_pool --yes-i-really-really-mean-it
	ceph fs new $fs_name $meta_pool $data_pool
	ceph fs set $fs_name allow_multimds 1 --yes-i-really-mean-it
	ceph fs set $fs_name max_mds 2
	if [ $? -eq 0 ];then
		break;
	fi
	i=$(($i + 1))
	break;
done

