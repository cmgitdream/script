#!/bin/bash

pool= #metadata
object=
binfile=/tmp/cephfs.inode.bin.$$
binfile2=/tmp/cephfs.inode.bin2.$$

function usage()
{
  echo "./parse_cephfs_inode.sh <metapool> <inode_object>"
  echo "eg ./parse_cephfs_inode.sh metadata 1.00000000.inode"
}

#
#inline void decode(std::string& s, bufferlist::iterator& p)
#{
#  __u32 len; // s.length() strlen()
#  decode(len, p);
#  s.clear();
#  p.copy(len, s);
#}
# __u32						// 4 bytes 
# CEPH_FS_ONDISK_MAGIC "ceph fs volume v011"	// 19 chars 19 bytes
# total 23 bytes
#  

function parse_cephfs_inode()
{
  rados -p $pool get $object $binfile || return 1
  #dd if=$binfile of=$binfile2 bs=1 skip=23 || return 1
  ceph-dencoder type InodeStore import $binfile skip 23 decode dump_json || return 1
}

if [ $# -lt 2 ];then
  usage
  exit
fi

pool=$1
object=$2
parse_cephfs_inode 

rm -f $binfile $binfile2
