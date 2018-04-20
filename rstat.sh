#!/bin/bash

#set -x

function parse_rstat()
{
	dir=$1
	if [ ! -e $dir ];then
		echo $dir not exist
		exit
	fi
	ino=`stat $dir|awk '/Inode:/{print $4}'`
	ceph daemon mds.a dump tree "" 0 | jq '.[] | select(.ino == '$ino')|.rstat'
	#ceph daemon mds.a dump cache | jq '.[] | select(.ino == '$ino')|.rstat'
}

parse_rstat $*
