#!/bin/bash

#set -x

dir=/root/ceph-master/ceph/build2
CEPH=$dir/bin/ceph
CONF=$dir/ceph.conf

function parse_dir()
{
	mds=$1
	dir=$2
	if [ ! -e $dir ];then
		echo $dir not exist
		exit
	fi
	ino=`stat $dir|awk '/Inode:/{print $4}'`
	$CEPH -c $CONF daemon $mds dump tree "" 0 | jq '.[] | select(.ino == '$ino')|.dirfrags'
	#ceph daemon mds.a dump cache | jq '.[] | select(.ino == '$ino')|.rstat'
}

parse_dir $*
