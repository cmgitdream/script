#!/bin/bash

parse_dir=/tmp/parse
pool= #default.rgw.buckets.data
object=
manifest_xattr=user.rgw.manifest
unix1_xattr=user.rgw.unix1
idtag_xattr=user.rgw.idtag
manifest_bin=$parse_dir/manifest.bin.$$
unix1_bin=$parse_dir/unix1.bin.$$
idtag_bin=$parse_dir/idtag.bin.$$
manifest_out=$parse_dir/manifest_out.$$
unix1_out=$parse_dir/unix1_out.$$
idtag_out=$parse_dir/idtag_out.$$
hexs=()

mkdir -p $parse_dir

function get_xattr()
{
  if [ $# -lt 4 ];then
    echo "$FUNCNAME <pool> <obj> <xattr> <binfile>"
    exit
  fi
  local mypool=$1
  local myobj=$2
  local myxattr=$3
  local mybin=$4
  rados -p $mypool getxattr $myobj $myxattr >$mybin || exit
}

function decode_idtag()
{
  get_xattr $pool $object $idtag_xattr $idtag_bin
  cp $idtag_bin $idtag_out
  echo -n -e "idtag:\t\t"`cat $idtag_out`
  #cat $idtag_out
  echo
}

function decode_manifest()
{
  get_xattr $pool $object $manifest_xattr $manifest_bin
  #ceph-dencoder type RGWObjManifest import $manifest_bin decode dump_json |tee $manifest_out || exit
  ceph-dencoder type RGWObjManifest import $manifest_bin decode dump_json > $manifest_out || exit
  #cat $manifest_out
}

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

function unixtime_to_date()
{
  second=$1
  echo $second | gawk -v str=$second '{ 
    day = strftime("%Y-%m-%d %H:%M:%S", str);
    print day
  }'
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
# 
#  src/common/ceph_time.h
# template<typename Clock, typename Duration>
# void decode(std::chrono::time_point<Clock, Duration>& t,
#	    bufferlist::iterator& p) {
#  uint32_t s;
#  uint32_t ns;
#  ::decode(s, p);	// 4
#  ::decode(ns, p);	// 4
#  struct timespec ts = {
#    static_cast<time_t>(s),
#    static_cast<long int>(ns)};
#
#  t = Clock::from_timespec(ts);
#}

function decode_unix1()
{
  get_xattr $pool $object $unix1_xattr $unix1_bin
  #hexdump -C $unix1_bin
  hexs=(`hexdump -C $unix1_bin | awk -F "|" '{split($1, arr, "  "); print arr[2]" "arr[3];}'`)
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

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  ctime_second=`string_to_int $e $s`
  state_ctime=`unixtime_to_date $ctime_second`
  #skip nanosecond (4 bytes)
  s=$(($s + 4))

  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  mtime_second=`string_to_int $e $s`
  state_mtime=`unixtime_to_date $mtime_second`
  #skip nanosecond (4 bytes)
  s=$(($s + 4))
  
  
  s=$(($s + $bytes))
  bytes=4
  e=$(($s + $bytes - 1))
  atime_second=`string_to_int $e $s`
  state_atime=`unixtime_to_date $atime_second`
  #skip nanosecond (4 bytes)
  s=$(($s + 4))

  inode_items=(
  $fh_type
  $state_dev
  $state_size
  $state_nlink
  $state_uid
  $state_gid
  $state_mode
  $state_ctime
  $state_mtime
  $state_atime
  )

  echo -e "fh_type:\t$fh_type" 
  echo -e "state_dev:\t$state_dev" 
  echo -e "state_size:\t$state_size" 
  echo -e "state_nlink:\t$state_nlink" 
  echo -e "state_uid:\t$state_uid" 
  echo -e "state_gid:\t$state_gid" 
  echo -e "state_mode:\t$state_mode" 
  echo -e "state_ctime:\t$state_ctime\t$ctime_second" 
  echo -e "state_mtime:\t$state_mtime\t$mtime_second" 
  echo -e "state_atime:\t$state_atime\t$atime_second" 


  for item in ${inode_items[@]}
  do
    echo $item >>$unix1_out
  done
}

#
# CDir::_omap_fetched()
# CDir::_encode_dentry()
#typedef struct inodeno_t {
#  uint64_t val; 		// 8 bytes
#} inodeno_t;
# _u32 len			// 4 bytes
# string			// len
#

function decode_CDentry()
{
  s=0
  e=0
  bytes=8

  e=$(()) 
}
