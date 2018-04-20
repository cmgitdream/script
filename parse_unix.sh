#!/bin/bash

pool=default.rgw.buckets.data
object=$1
binfile=/tmp/unix1.bin.$$


#rados -p $pool listxattr $object
rados -p $pool getxattr $object user.rgw.unix1 >$binfile


hexs=()

function string_to_oct()
{
  end=$1
  start=$2 
  str=0x${hexs[$end]}
  i=$(($end - 1))
  for ((; i >= $start; i--))
  do
    str=$str""${hexs[$i]}
  done
  printf "%o" $str
}

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
  echo $(($str))
}

#    struct State {
#      uint64_t dev;
#      size_t size;
#      uint64_t nlink;
#      uint32_t owner_uid; /* XXX need Unix attr */
#      uint32_t owner_gid; /* XXX need Unix attr */
#      mode_t unix_mode;  // u32
#      struct timespec ctime;
#      struct timespec mtime;
#      struct timespec atime;
#    }
#
#    void decode(bufferlist::iterator& bl) {
#      DECODE_START(1, bl); //__u8 struct_v, struct_compat; __u32 struct_len --> 1 + 1 + 4 = 6
#      uint32_t fh_type;		// 6
#      ::decode(fh_type, bl);		// 4		
#      assert(fh.fh_type == fh_type);
#      ::decode(state.dev, bl);		// 8
#      ::decode(state.size, bl);	// 8 	for 64 bit os
#      ::decode(state.nlink, bl);	// 8
#      ::decode(state.owner_uid, bl);	// 4
#      ::decode(state.owner_gid, bl);	// 4
#      ::decode(state.unix_mode, bl);	// 4
#      ceph::real_time enc_time;
#      for (auto t : { &(state.ctime), &(state.mtime), &(state.atime) }) {
#	::decode(enc_time, bl);
#	*t = real_clock::to_timespec(enc_time);
#      }
#      DECODE_FINISH(bl);
#    }
function decode_unix1()
{
  #hexdump -C $binfile | awk -F "|" '{str=$1; split($1, arr, "  "); print arr[2]" "arr[3];}'
  hexs=(`hexdump -C $binfile | awk -F "|" '{split($1, arr, "  "); print arr[2]" "arr[3];}'`)
  #echo ${hexs[@]}
  s=0
  e=0
  bytes=6
  e=$(($s + $bytes - 1))

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  fh_type=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=8
  e=$(($s + $bytes - 1))
  state_dev=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=8
  e=$(($s + $bytes - 1))
  state_size=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=8
  e=$(($s + $bytes - 1))
  state_nlink=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  state_uid=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  state_gid=`string_to_int $e $s`

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  state_mode=`string_to_int $e $s`

  echo "fh_type = $fh_type" 
  echo "state_dev = $state_dev" 
  echo "state_size = $state_size" 
  echo "state_nlink = $state_nlink" 
  echo "state_uid = $state_uid" 
  echo "state_gid = $state_gid" 
  echo "state_mode = $state_mode" 
}

decode_unix1
rm -f $binfile
