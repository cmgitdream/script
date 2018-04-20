#!/bin/bash

pool= #metadata
object=
binfile=/tmp/cephfs.file.parent.$$
binfile2=/tmp/cephfs.file.parent2.$$

function usage()
{
  echo "./parse_cephfs_file.sh <datapool> <inode_object>"
  echo "eg ./parse_cephfs_inode.sh data 10000989681.00000000"
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
  rados -p $pool getxattr $object parent > $binfile || return 1
  ceph-dencoder type inode_backtrace_t import $binfile decode dump_json || return 1
}

if [ $# -lt 2 ];then
  usage
  exit
fi

pool=$1
object=$2
parse_cephfs_inode 

rm -f $binfile $binfile2
