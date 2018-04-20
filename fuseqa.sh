#!/bin/bash

#set -x

notrunc="conv=notrunc"

function hello()
{
  echo $1
}

function error()
{
  ping -n 1 $1
}

function good()
{
  return 100
}

function try_rmdir()
{
  local mydir=$1
  rm -rf $mydir/*
  if [ $? -ne 0 ];then
    echo "$mydir has subdir, exit"
    exit
  fi
  umount $mydir
  rmdir $mydir
}

function rmdir_force()
{
  local pdir=$1
  rm -rf $pdir/*
  res=$?
  echo $FUNCNAME: 0 -- rm -rf $pdir res = $res
  if [ $res -eq 0 ];then
    return 0
  fi
  rmdir $pdir
  res=$?
  echo $FUNCNAME: 1 -- rmdir $pdir res = $res
  if [ $res -eq 0 ];then
    return 0
  fi
  for child in `ls $pdir`
  do
    item=$pdir/$child
    if [ -f $item ];then
      rm -f $item
      continue
    fi
    echo sub=$item
    umount $item
    rmdir_force $item
  done 
  rmdir $pdir
  local res=$?
  echo  $FUNCNAME: 2 -- rmdir $pdir res=$res
  # EBUSY
  if [ $res -ne 0 ];then
    umount $pdir
    rmdir $pdir
    res=$?
    echo $FUNCNAME: 3 -- rmdir $pdir res=$res
  fi
}

function get_filesize()
{
  (stat $1 || echo "Size: -1")|awk '/Size:/{print $2}'
}

function do_write_file()
{
  dofile=$1
  dobs=$2
  docount=$3
  dd if=/dev/urandom of=$dofile bs=$dobs count=$docount $notrunc 2>/dev/null|| return 1
}

function do_copy_file()
{
  srcfile=$1
  dstfile=$2
  #dd if=$srcfile of=$dstfile bs=1M oflag=direct 2>/dev/null|| return 1
  dd if=$srcfile of=$dstfile bs=1M 2>/dev/null|| return 1
  #dd if=$srcfile of=$dstfile bs=1M conv=notrunc oflag=direct || return 1
  #echo cp $srcfile $dstfile
  #cp $srcfile $dstfile
}

function do_read_file()
{
  file=$1
  dd if=$file of=/dev/null bs=1M || return 1
}

function CREATE_FILE()
{
  file=$1
  touch $file || return 1
  stat $file > /dev/null
}

function CREATE_DIR()
{
  dir=$1
  mkdir $dir || return 1
  stat $dir > /dev/null || return 1
  mkdir -p $dir/$dir"1"/$dir"11"
  find $dir > /dev/null
}

function WRITE_FILE()
{
  file=$1
  bs=$2
  count=$3
  backfile=$backupdir/`basename $file`
  #echo dd if=/dev/urandom of=$backfile bs=$bs count=$count
  #dd if=/dev/urandom of=$backfile bs=$bs count=$count 2>/dev/null || return 1
  #dd if=/dev/urandom of=$backfile bs=$bs count=$count || return 1
  do_write_file $backfile $bs $count||return 1
  src_md5=`md5sum $backfile|awk '{print $1}'`
  #echo src_md5=$src_md5
  #dd if=$backfile of=$file bs=$bs conv=notrunc oflag=direct 2>/dev/null || return 1
  #echo dd if=$backfile of=$file bs=$bs conv=notrunc count=$count oflag=direct
  #dd if=$backfile of=$file bs=$bs count=$count conv=notrunc oflag=direct|| return 1
  do_copy_file $backfile $file ||return 1
  #echo stat $file
  stat $file > /dev/null || return 1
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo dst_md5=$dst_md5
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function APPEND_WRITE_FILE()
{
  file=$1
  backfile=$backupdir/`basename $file`
  dd if=/dev/urandom of=$backfile bs=1M count=8 2>/dev/null || return 1
  sync
  src_md5=`md5sum $backfile|awk '{print $1}'`
  #echo "src_md5=$src_md5"
  dd if=$backfile of=$file bs=1M count=4 conv=notrunc 2>/dev/null || return 1
  sync
  dd if=$backfile of=$file bs=1M skip=4 seek=4 count=4 conv=notrunc 2>/dev/null || return 1
  sync
  stat $file > /dev/null || return 1
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function SEEK_WRITE_FILE()
{
  file=$1
  backfile=$backupdir/`basename $file`
  do_flag="conv=notrunc oflag=direct"
  # 0: 0 ~ 1 MB
  # 1: 1 ~ 5 MB
  # 2: 5 ~ 9 MB
  # 3: 9 ~ 13 MB
  # 4: 13 ~ 17 MB
  seeks=(16 14 8 4 1 0)
  counts=(1 1 1 2 1 1)
  for ((i=0; $i<${#seeks[@]}; i++))
  do
    #echo "dd if=/dev/urandom of=$backfile bs=1M count=${counts[$i]} seek=${seeks[$i]} 2>dev/null || return 1"
    dd if=/dev/urandom of=$backfile bs=1M count=${counts[$i]} seek=${seeks[$i]} $do_flag 2>/dev/null || return 1
  done
  sync

  src_md5=`md5sum $backfile|awk '{print $1}'`
  #echo "src_md5=$src_md5"

  for ((i=0; $i<${#seeks[@]}; i++))
  do
    #echo "dd if=/dev/urandom of=$file bs=1M count=${counts[$i]} seek=${seeks[$i]} 2>dev/null || return 1"
    dd if=$backfile of=$file bs=1M count=${counts[$i]} skip=${seeks[$i]} seek=${seeks[$i]} $do_flag 2>/dev/null || return 1
  done
  sync
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function PART_WRITE_FILE()
{
  file=$1
  backfile=$backupdir/`basename $file`
  datafile=$backfile"_content"
  dd if=/dev/urandom of=$backfile bs=1M count=8 2>/dev/null || return 1
  dd if=/dev/urandom of=$datafile bs=1M count=4 2>/dev/null || return 1
  dd if=$backfile of=$file bs=1M count=8 2>/dev/null || return 1
  dd if=$datafile of=$backfile bs=1M seek=2 count=4 conv=notrunc 2>/dev/null || return 1
  sync
  src_md5=`md5sum $backfile|awk '{print $1}'`
  #echo "src_md5=$src_md5"
  dd if=$datafile of=$file bs=1M seek=2 count=4 conv=notrunc 2>/dev/null || return 1
  sync
  stat $file > /dev/null || return 1
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function EXTEND_WRITE_FILE()
{
  file=$1
  backfile=$backupdir/`basename $file`
  datafile=$backfile"_content"
  dd if=/dev/urandom of=$backfile bs=1M count=8 2>/dev/null || return 1
  dd if=/dev/urandom of=$datafile bs=1M count=4 2>/dev/null || return 1
  dd if=$backfile of=$file bs=1M count=8 2>/dev/null || return 1
  dd if=$datafile of=$backfile bs=1M seek=6 count=4 2>/dev/null || return 1
  sync
  src_md5=`md5sum $backfile|awk '{print $1}'`
  #echo "src_md5=$src_md5"
  dd if=$datafile of=$file bs=1M seek=6 count=4 2>/dev/null || return 1
  sync
  stat $file > /dev/null || return 1
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function RANDOM_WRITE_FILE()
{
  file=$1
  #bs=$2
  #count=$3
  backfile=$backupdir/`basename $file`
  # 32MB file
  rand_seq=(15 18 5 7 16 19 13 30 25 0 1 4 5 31)
  unit_counts=(1 1 1 1 2 3 1 1 1 1 1 1 1 1)
  for ((i=0; $i<${#rand_seq[@]}; i++))
  do
    seqnum=${rand_seq[$i]}
    unit=${unit_counts[$i]}
    #echo "dd if=/dev/urandom of=$backfile'_rand_'$seqnum bs=1M count=$unit $notrunc 2>/dev/null || return 1"
    #echo "dd if=$backfile'_rand_'$seqnum of=$backfile bs=1M count=$unit seek=$seqnum $notrunc 2>/dev/null || return 1"
    #echo "dd if=$backfile'_rand_'$seqnum of=$file bs=1M count=$unit seek=$seqnum $notrunc 2>/dev/null || return 1"
    dd if=/dev/urandom of=$backfile'_rand_'$seqnum bs=1M count=$unit $notrunc 2>/dev/null || return 1
    dd if=$backfile'_rand_'$seqnum of=$backfile bs=1M count=$unit seek=$seqnum $notrunc 2>/dev/null || return 1
    dd if=$backfile'_rand_'$seqnum of=$file bs=1M count=$unit seek=$seqnum $notrunc 2>/dev/null || return 1
  done
  sync
  src_md5=`md5sum $backfile|awk '{print $1}'`
  dst_md5=`md5sum $file|awk '{print $1}'`
  #echo "src_md5=$src_md5"
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function READ_FILE()
{
  file=$1
  bs=$2
  count=$3
  backfile=$backupdir/`basename $file`
  backfile2=$backfile"2"
  dd if=/dev/urandom of=$file bs=$bs count=$count 2>/dev/null || return 1
  sync
  src_md5=`md5sum $file|awk '{print $1}'`
  dd if=$file of=$backfile2 2>/dev/null || return 1
  dst_md5=`md5sum $backfile2|awk '{print $1}'`
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function COPY_FILE()
{
  file=$1
  repfile=$file".rep"
  #dd if=/dev/urandom of=$file bs=1M count=4 2>/dev/null || return 1
  do_write_file $file $((1<<20)) 4||return 1
  cp $file $repfile || return 1
  sync
  src_md5=`md5sum $file|awk '{print $1}'`
  dst_md5=`md5sum $repfile|awk '{print $1}'`
  #if [ x$src_md5 = x$dst_md5 ];then
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function COPY_DIR()
{
  dir=$1
  repdir=$dir".rep"
  mkdir $dir
  touch $dir/file1
  mkdir -p $dir/dir2
  cp -r $dir $repdir || return 1
  result1=/tmp/result1
  result2=/tmp/result2
  pushd $dir &>/dev/null && find . >$result1 && popd &>/dev/null || return 1
  pushd $repdir &>/dev/null && find . >$result2 && popd &>/dev/null || return 1
  src_md5=`md5sum $result1|awk '{print $1}'`
  dst_md5=`md5sum $result2|awk '{print $1}'`
  rm -rf $result1 $result2 || return 1
  if [ x$src_md5 != x ] && [ x$src_md5 = x$dst_md5 ];then
    return 0;
  else
    return 1;
  fi
}

function RENAME_FILE()
{
  file=$1
  renamefile=$file".rename"
  touch $file
  stat $file >/dev/null || return 1
  mv $file $renamefile || return 1
  stat $file >/dev/null &>/dev/null
  res1=$?
  stat $renamefile >/dev/null || return 1
  res2=$?
  if [ $res1 -ne 0 ] && [ $res2 -eq 0 ];then
    return 0;
  else
    return 1;
  fi
}

function RENAME_BIG_FILE()
{
  file=$1
  bs=$2
  count=$3
  src_md5=
  dst_md5=
  renamefile=$file".rename"
  #do_write_file $file $((1<<20)) 8 || return 1
  do_write_file $file $bs $count || return 1
  sync
  size1=$((`get_filesize $file`))
  src_md5=`md5sum $file|awk '{print $1}'`
  stat $file >/dev/null || return 1
  mv $file $renamefile || return 1
  stat $file >/dev/null &>/dev/null
  res1=$?
  stat $renamefile >/dev/null || return 1
  res2=$?
  size2=$((`get_filesize $renamefile`))
  dst_md5=`md5sum $renamefile|awk '{print $1}'`
  if [ $size1 -ne $size2 ];then
    echo "$size1 != $size2"
    return 1
  fi
  #echo "src_md5=$src_md5"
  #echo "dst_md5=$dst_md5"
  if [ x$src_md5 != x ] && [ x$src_md5 != x$dst_md5 ];then
    return 1;
  fi
  if [ $res1 -ne 0 ] && [ $res2 -eq 0 ];then
    return 0;
  else
    return 1;
  fi
}

function UNLINK_FILE()
{
  file=$1
  do_write_file $file $((1<<20)) 8
  stat $file >/dev/null || return 1
  rm -f $file || return 1
  stat $file &>/dev/null
  res1=$?
  if [ $res1 -eq 0 ];then
    return 1;
  fi
  touch $file
}

function UNLINK_DIR()
{
  dir=$1
  subdir=$dir/subdir
  mkdir -p $subdir || return 1
  touch $subdir/dfile1 || return 1
  mkdir $subdir/dir2 || return 1
  rmdir $subdir &> /dev/null
  res1=$?
  if [ $res1 -eq 0 ];then
    return 1;
  fi
  rm -rf $subdir/* || return 1
  rmdir $subdir || return 1
}

function READ_DIR()
{
  dir=$1
  subdir=$dir/sublsdir
  mkdir -p $subdir || return 1
  lsfiles=(
    lsfile1
    lsfile2
    lsfile3
  )
  lsdirs=(
    lsdir1
    lsdir2
  )
  # create sub files
  for f in ${lsfiles[@]}
  do
    touch $subdir/$f || return 1
  done
  # create sub dirs
  for d in ${lsdirs[@]}
  do
    mkdir $subdir/$d || return 1
  done

  readdir_output=(`ls $subdir`)
  readdir_input=(${lsdirs[@]} ${lsfiles[@]})
  
  #echo "readdir_output =  '${readdir_output[@]}'"
  #echo "readdir_input  =  '${readdir_input[@]}'"
  if [ x"${readdir_input[*]}" != x"${readdir_output[*]}" ];then
    return 1
  fi
}

function RUN_CASE()
{
  local fname=$1
  shift;
  $fname $@
  ret=$?
  if [ $ret -eq 0 ];then
    echo -e "[ PASSED ]: $fname $@"
  else
    echo -e "[ FAILED ]: $fname $@"
    exit
  fi
}

if [ $# -lt 1 ];then
  echo "need target dir"
  exit;
fi

target=$1
workdir=$target/nfsqa
backupdir=~/nfsqa_backup

rmdir_force $workdir
rmdir_force $backupdir
mkdir $workdir 2>/dev/null
mkdir $backupdir 2>/dev/null

#do_write_file $workdir/testfilexx_2M $((1<<20)) 2
#do_write_file $workdir/testfilexx_8M $((1<<20)) 8
#do_read_file $workdir/testfilexx_8M
#RUN_CASE hello chenmin
#RUN_CASE good
#RUN_CASE error chenmin
<<xx
RUN_CASE CREATE_FILE $workdir/createfile1
RUN_CASE CREATE_DIR $workdir/dir_create
RUN_CASE WRITE_FILE $workdir/writefile1 $((1<<10)) 1 #1KB
RUN_CASE WRITE_FILE $workdir/writefile2 $((1<<19)) 100 #52MB
RUN_CASE WRITE_FILE $workdir/writefile3 $((1<<18)) 100 #26MB
RUN_CASE WRITE_FILE $workdir/writefile_1M $((1<<20)) 1
RUN_CASE WRITE_FILE $workdir/writefile_2M $((1<<20)) 2
RUN_CASE WRITE_FILE $workdir/writefile_4M $((1<<20)) 4
RUN_CASE WRITE_FILE $workdir/writefile_8M $((1<<20)) 8
RUN_CASE APPEND_WRITE_FILE $workdir/appendfile1
RUN_CASE SEEK_WRITE_FILE $workdir/seekfile1
RUN_CASE PART_WRITE_FILE $workdir/partfile1
RUN_CASE EXTEND_WRITE_FILE $workdir/extendfile1
RUN_CASE RANDOM_WRITE_FILE $workdir/randfile1
RUN_CASE READ_FILE $workdir/readfile_1M $((1<<20)) 1
RUN_CASE COPY_FILE $workdir/copyfile1
RUN_CASE COPY_DIR $workdir/dir_copy
xx
RUN_CASE RENAME_FILE $workdir/renamefile1
RUN_CASE RENAME_BIG_FILE $workdir/rename_bigfile_1M $((1<<20)) 1
RUN_CASE RENAME_BIG_FILE $workdir/rename_bigfile_8M $((1<<20)) 8
RUN_CASE UNLINK_FILE $workdir/rmfile1
RUN_CASE UNLINK_DIR $workdir/dir_remove
RUN_CASE READ_DIR $workdir/dir_ls
#xx
#ls -l $workdir
