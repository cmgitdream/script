#!/bin/bash

pool= #metadata
object=
dir=
binfile=/tmp/cephfs.cdir.bin.$$
binfile2=/tmp/cephfs.cdir.bin2.$$

function usage()
{
  echo "./parse_cephfs_dir.sh <metapool> <dir_object>"
  echo "eg ./parse_cephfs_dir.sh metadata 1.00000000"
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
hexs=()

function string_to_int()
{
  end=$1
  start=$2
  str=0x${hexs[$end]}
  i=$(($end - 1))
  for ((; i >= $start; i--))
  do
    str=$str""${hexs[$i]}
  done
  echo -n $(($str))
}

function string_to_hex()
{
  end=$1
  start=$2
  str=0x${hexs[$end]}
  i=$(($end - 1))
  for ((; i >= $start; i--))
  do
    str=$str""${hexs[$i]}
  done
  printf "%llx" $str
}

# parse CDir::_load_entry()
function parse_cephfs_dir_by_object()
{
  echo "flush journal in mds rank 0"
  ceph daemon mds.a flush journal >/dev/null
  rados -p $pool get $object $binfile || return 1
  dentries=(`rados -p $pool listomapkeys $object 2>/dev/null`)
  for key in ${dentries[@]}
  do
    file=`echo $key|cut -d"_" -f1`
    file=$key
    bfile=$binfile"_"key
    rados -p $pool getomapval $object $key $bfile 2>/dev/null
    #hexdump -C $bfile
    hexs=(`hexdump -C $bfile | awk -F "|" '{split($1, arr, "  "); print arr[2]" "arr[3];}'`)
    type=$(echo -e "\x${hexs[8]}")
    
    if [ x$type = "xI" ];then
      echo -n -e "inode:\t"
      # index = 9+6 = 15
      # end = 9+6+8-1 = 22
      echo -n -e $file"\t\t"
      string_to_hex 22 15
      echo -n -e "\t"
      string_to_int 22 15
      echo
      # encode_bare skip sruct_v, compat_v, len
      # 1 + 1 + 4
      # skip = 9 + 1 + 1 + 4 = 15
      # should insert 15 chars into bfile
      #dd if=$bfile of=$tmpfile bs=1 count=9 oflag=sync conv=notrunc
      #echo -n -e \\x06\\x04\\x00\\x00\\x00\\x00 >> $tfile
      
    elif [ x$type = "xL" ];then
      echo -n -e "link:\t"
      # index = 9
      # end = 9 + 8 - 1
      echo -n -e $file"\t\t"
      string_to_hex 16 9 
      echo -n -e "\t"
      string_to_int 16 9 
      echo
    fi
    
    rm -f $bfile
  done
}

function parse_cephfs_dir_by_path()
{
  if [ ! -e $dir ];then
    echo $dir not exist
    exit
  fi
  ino=`stat $dir|awk '/Inode:/{print $4}'`
  # assume there is no dirfrag
  object=`printf "%lx.%08lx" $ino 0`
  #echo object = $object
  parse_cephfs_dir_by_object
}

if [ $# -lt 2 ];then
  usage
  exit
fi

pool=$1
dir=$2
object=$3
parse_cephfs_dir_by_path

rm -f $binfile $binfile2
