#!/bin/bash

meta_pool=metadata
data_pool=nfsdata
fs_name=nfs
id=0
recovery=nfsv41.clientid.directory
pg_num=4
pgp_num=$pg_num

function clean()
{
	rados -p $data_pool ls |xargs -n 1 -I @ rados -p $data_pool rm @
	rados -p $meta_pool rm $recovery
}

function resize_pool()
{
	local poolid=$1
	local size=$2

	ceph osd pool set $poolid min_size $size
	ceph osd pool set $poolid size $size
}

function mds()
{
	clean
	ceph mds fail $id
	ceph fs rm $fs_name --yes-i-really-mean-it
	ceph fs new $fs_name $meta_pool $data_pool 
}

function mds_pool()
{
	ceph mds fail $id
	ceph fs rm $fs_name --yes-i-really-mean-it
	ceph osd pool delete $data_pool $data_pool --yes-i-really-really-mean-it && \
	ceph osd pool create nfsdata $pg_num $pgp_num && \
	ceph osd pool set $data_pool min_size 1 && \
	ceph osd pool set $data_pool size 1 && \
	ceph fs new $fs_name $meta_pool $data_pool 

}

function new_fs()
{
	ceph osd pool create $meta_pool $pg_num $pgp_num
	ceph osd pool create $data_pool $pg_num $pgp_num
	resize_pool $meta_pool 1
	resize_pool $data_pool 1
	ceph fs new $fs_name $meta_pool $data_pool 
}

$*
