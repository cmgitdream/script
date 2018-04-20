#!/bin/bash

#dir=/cephfuse/dir1
mnt=/cephfuse
if [ $# -gt 0 ];then
	mnt=$1
fi

function parse_rstat()
{
	dir=$1
	if [ ! -e $dir ];then
		echo $dir not exist
		exit 1
	fi
	ino=`stat $dir|awk '/Inode:/{print $4}'`
	ceph daemon mds.a dump tree "" 0 | jq '.[] | select(.ino == '$ino')|.rstat'
	#ceph daemon mds.a dump cache | jq '.[] | select(.ino == '$ino')|.rstat'
}

function WRITE_4M_FILE()
{
	local myfile=$1
	dd if=/dev/urandom of=$myfile bs=4M count=1 conv=notrunc oflag=sync 2>/dev/null
}

function WRITE_1M_FILE()
{
	local myfile=$1
	dd if=/dev/urandom of=$myfile bs=1M count=1 conv=notrunc oflag=sync 2>/dev/null
}

files=5
dirs=3
inodes=$(($files + $dirs))
bytes=$(((1<<20) * 5))
function MAKE_BASE_HIER()
{
	local unix_sec=`date +%s`
	local mydir="dir_"$unix_sec
	local myprefix=hier
	if [ $# -gt 1 ];then
		mydir=$1
		myprefix=$2
	fi
	mkdir -p $mydir/$myprefix"_dir1"
	mkdir -p $mydir/$myprefix"_dir2"
	mkdir -p $mydir/$myprefix"_dir3"
	WRITE_1M_FILE $mydir/$myprefix"_file1"
	WRITE_1M_FILE $mydir/$myprefix"_file2"
	WRITE_1M_FILE $mydir/$myprefix"_file3"
	WRITE_1M_FILE $mydir/$myprefix"_dir1"/file111
	WRITE_1M_FILE $mydir/$myprefix"_dir1"/file112
}

function SHOW_HIER_TOTAL()
{
	local mydir=$1	
	local myinodes=$(($files + $dirs + 1))
	local mybytes=$bytes
	if [ $# -gt 2 ];then
		myinodes=$2
		mybytes=$3
	fi
	echo $mydir rstat:
	parse_rstat $mydir
	echo total inodes: $myinodes
	echo total bytes: $mybytes
}

function TEST_BASE_STATS() {
	echo -n "TEST_BASE_STATS: "
	local mydir=$mnt/dir1
	MAKE_BASE_HIER $mydir base
	sleep 10
	SHOW_HIER_TOTAL $mydir
}

function TEST_CHOWN() {
	echo -n "TEST_CHOWN: "
	local mydir=$mnt/chown
	MAKE_BASE_HIER $mydir chown
	local subdir1=$mydir/chown_dir1
	chown -R user1:user1 $mydir
	chown -R root:root $mydir
	chown -R user1:user1 $subdir1
	sleep 10
	SHOW_HIER_TOTAL $mydir
}

function TEST_UNLINK() {
	echo -n "TEST_UNLINK: "
	local mydir=$mnt/unlink
	MAKE_BASE_HIER $mydir unlink
	local subdir1=$mydir/unlink_dir1
	local rminodes=3
	local rmbytes=$(((1<<20)*2))
	rm -rf $subdir1
	sleep 10
	SHOW_HIER_TOTAL $mydir $(($inodes + 1 - $rminodes)) $((bytes - $rmbytes))
}

function TEST_LINK() {
	echo -n "TEST_LINK: "
	local mydir=$mnt/link
	MAKE_BASE_HIER $mydir link
	local subfile1=$mydir/link_dir1/file111
	local linkfile1=$mydir/link_dir1/file111.link
	local linodes=1
	local lbytes=$(((1<<20)))
	link $subfile1 $linkfile1
	sleep 10
	SHOW_HIER_TOTAL $mydir $(($inodes + 1 +linodes)) $((bytes + lbytes))
}

#umount /cephfuse
#ceph-fuse /cephfuse
umount $mnt
mount.ceph 10.0.11.212:/ $mnt
if [ $? -ne 0 ];then
	echo "ceph-fuse /cephfuse error"
	exit
fi
rm -rf $mnt/*
sleep 3
#TEST_BASE_STATS
#TEST_CHOWN
#TEST_UNLINK
TEST_LINK
