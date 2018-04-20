#!/bin/bash

#set -e -x

<<ddd
ceph-fuse /cephfuse
mkdir /cephfuse/dir1
mkdir /cephfuse/dir1/dir11
sleep 1
mkdir /cephfuse/dir1/dir12
sleep 1
mkdir /cephfuse/dir1/dir13
sleep 1
touch /cephfuse/dir1/file11
sleep 1
touch /cephfuse/dir1/file12
sleep 1
mkdir /cephfuse/dir1/dir11/file111 
sleep 1
bash parse_cephfs_rstat.sh /cephfuse/dir1
rmdir /cephfuse/dir1/dir13
sleep 1
bash parse_cephfs_rstat.sh /cephfuse/dir1
ddd


mnt=/cephfuse
user1=quser1
user2=quser2
user3=quser3
group1=qgroup1
group2=qgroup2
password=password

function groupid()
{
  if [ $# -ne 0 ];then
    grpname=$1
    sudo grep "^$grpname:" /etc/group|cut -d: -f3
  fi
}

function first_user_by_gid()
{
  if [ $# -ne 0 ];then
    gid=$1
    sudo awk -F ":" '/':"$gid":'/{if ($4 == '"$gid"') {print $1; exit 0;}}' /etc/passwd
  fi
}
	
function reset_env()
{
	if [ `groupid $group1`x = ""x ];then
		groupadd $group1
	fi
	if [ `groupid $group2`x = ""x ];then
		groupadd $group2
	fi
	id $user1 >/dev/null || useradd -g $group1 $user1 # -p $password
	id $user2 >/dev/null || useradd -g $group1 $user2 # -p $password
	id $user3 >/dev/null || useradd -g $group2 $user3 # -p $password
	#useradd -g $group1 $user2 # -p $password
	#useradd -g $group2 $user3 # -p $password
}


# symmetry tree, with heavy leaves
function touch_files()
{
  local leaves=1024
  local dname=
  local files=
  local depth=1
  local branches=1024 # max child count of any subtree unless child is leaf
  # default: only allow 1024 subdirs of this dir  

  dname=$1
  shift
  files=$1
  shift
  depth=$1
  shift
  branches=$1
  shift
  local left_files=$(($files >> 1))
  local right_files=$(($files - $left_files))
}

function files_1000()
{
	local mydir=$mnt/dir1000
	local sub=

	rm -rf $mydir
	mkdir $mydir
	setfattr -n ceph.quota.user.0.max_files -v 1004 $mydir
		
	# create 1000 files & 4 subdirs
	for((i=0; i<4; i++)); 
 	do
		sub=$mydir/dir$i
		mkdir $sub
		for ((j=0; j<250; j++))
		do
			touch $sub/file$i$j
		done
	done
	echo "sleep 10"
	sleep 10
	touch $mydir/tfile1
	echo $?
}

function bytes_1024()
{
	local mydir=$mnt/dir1000_bytes
	local sub=
	local mbytes=$((1024*(1<<20)))

	rm -rf $mydir
	mkdir $mydir
	setfattr -n ceph.quota.user.0.max_bytes -v $mbytes $mydir
		
	# create 1000 files & 4 subdirs
	for((i=0; i<4; i++)); 
 	do
		sub=$mydir/dir$i
		mkdir $sub
		for ((j=0; j<256; j++))
		do
			dd if=/dev/urandom of=$sub/file$i$j bs=1M count=1 oflag=sync
		done
	done
	sleep 10
	dd if=/dev/urandom of=$mydir/tfile1 bs=4M count=2 oflag=sync
}

# set quota and exceed quota
function bytes_files_any()
{
	local mydir=$1	# parent dir
	local prefix=$2	# file name prefix
	local qval=$3	# quota bytes or files
	local unit=$4	# dd write bs
	local cur_ug=$5	# user or group
	local new_user=$6
	local isuser=$(($7))	# is user or group
	local isbytes=$(($8))	# is quota bytes or files
	local ischg=$(($9))	# if chown owner
	local id=
	local myfile=
	local qkey=
	local mbytes=
	local mfiles=
	local cur_user=
	local cur_group=
	local new_group=
	local res=1

	id $new_user >/dev/null || return 2
	new_group=`id -n -g $new_user`

	if [ $isuser -eq 1 ];then
		id $cur_ug >/dev/null||return 2
		id=`id -u $cur_ug`
		cur_user=$cur_ug
		cur_group=`id -n -g $cur_user`
	else
		id=`groupid $cur_ug`
		#echo "gid = $id"
		cur_user=`first_user_by_gid $id`
		cur_group=$cur_ug
	fi	

	#echo "whoami = " `whoami`
	#echo "cur_user = $cur_user"
	sudo rm -rf $mydir
	sudo mkdir $mydir
	sudo chown $cur_user:$cur_group $mydir
	#stat $mydir
	
	if [ $isuser -eq 1 ];then
		if [ $isbytes -eq 1 ];then
			qkey="ceph.quota.user."$id".max_bytes"
		else
			qkey="ceph.quota.user."$id".max_files"
		fi
		
	else
		if [ $isbytes -eq 1 ];then
			qkey="ceph.quota.group."$id".max_bytes"
		else
			qkey="ceph.quota.group."$id".max_files"
		fi
	fi
	sudo setfattr -n $qkey -v $qval $mydir
	#getfattr -n $qkey $mydir
	
	if [ $isbytes -eq 1 ];then
		if [ $ischg -eq 1 ];then
			#echo "BYTES CHOWN"
			myfile=$mydir/$prefix"_dd_chg_"$qval
			touch $myfile
			sudo chown $new_user:$new_group $myfile
			dd if=/dev/urandom of=$myfile bs=$unit count=2 oflag=sync conv=notrunc
			sudo chown $cur_user:$cur_group $myfile
		else
			#echo "BYTES DO NOT CHOWN"
			myfile=$mydir/$prefix"_dd_"$qval
			touch $myfile
			if [ x`whoami` != x$cur_user ];then
				sudo chown $cur_user:$cur_group $myfile
			fi
			dd if=/dev/urandom of=$myfile bs=$unit count=3 oflag=sync conv=notrunc	
		fi
		
		res=$?
		#echo " quota_bytes: dd res = $?"
	else
		for ((i=0; i<$qval; i++))
		do
			myfile=$mydir/$prefxi"_touch_"$i
			touch $myfile
			if [ x`whoami` != x$cur_user ];then
			sudo chown $cur_user:$cur_group $myfile
			fi
		done
		if [ $ischg -eq 1 ];then
			#echo "FILES CHOWN"
			myfile=$mydir/$prefix"_touch_chg_extra"
			touch $myfile
			sudo chown $new_user:$new_group $myfile
			sudo chown $cur_user:$cur_group $myfile
		else
			#echo "FILES DO NOT CHOWN"
			myfile=$mydir/$prefix"_touch_extra"
			touch $myfile
			if [ x`whoami` != x$cur_user ];then
			sudo chown $cur_user:$cur_group $myfile
			fi
		fi
		res=$?
		#echo " quota_files: touch res = $?"
	fi
	if [ $res -eq 1 ];then
		return 0;
	else
		return 1;
	fi
}

function bytes_user_any()
{
	local mydir=$1
	local prefix=$2
	local bytes=$3
	local user=$4
	local bs=$((1<<20))
	bytes_files_any $mydir $prefix $bytes $bs $user root 1 1 0
}

function bytes_group_any()
{
	local mydir=$1
	local prefix=$2
	local bytes=$3
	local group=$4
	local bs=$((1<<20))
	bytes_files_any $mydir $prefix $bytes $bs $group root 0 1 0
}

function bytes_chown_user_any()
{
	local mydir=$1
	local prefix=$2
	local bytes=$3
	local user=$4
	local nuser=$5
	local bs=$((1<<20))

	bytes_files_any $mydir $prefix $bytes $bs $user $nuser 1 1 1
}

function bytes_chown_group_any()
{
	local mydir=$1
	local prefix=$2
	local bytes=$3
	local group=$4
	local nuser=$5
	local bs=$((1<<20))

	bytes_files_any $mydir $prefix $bytes $bs $group $nuser 0 1 1
}

function files_user_any()
{
	local mydir=$1
	local prefix=$2
	local files=$3
	local user=$4
	local bs=0
	bytes_files_any $mydir $prefix $files $bs $user root 1 0 0
}

function files_group_any()
{
	local mydir=$1
	local prefix=$2
	local files=$3
	local group=$4
	local bs=0
	bytes_files_any $mydir $prefix $files $bs $group root 0 0 0
}

function files_chown_user_any()
{
	local mydir=$1
	local prefix=$2
	local files=$3
	local user=$4
	local nuser=$5
	local bs=0

	bytes_files_any $mydir $prefix $files $bs $user $nuser 1 0 1
}

function files_chown_group_any()
{
	local mydir=$1
	local prefix=$2
	local files=$3
	local group=$4
	local nuser=$5
	local bs=0

	bytes_files_any $mydir $prefix $files $bs $group $nuser 0 0 1
}

# --- test cases ---

function TEST_user_write()
{
  local user=$user1
  bytes_user_any $mnt/bytesdir1 bytes $((1<<20)) $user
}

function TEST_user_chown_write()
{
  local user=$user1
  local nuser=$user2
  bytes_chown_user_any $mnt/byteschowndir1 bytes $((1<<20)) $user $nuser
}

function TEST_user_files()
{
  local user=$user1
  files_user_any $mnt/filesdir1 files 3 $user
}

function TEST_user_chown_files()
{
  local user=$user1
  local nuser=$user2
  files_chown_user_any $mnt/fileschowndir1 files 3 $user $nuser
}

function TEST_group_write()
{
  local user=$user1
  local grp=`id -n -g $user`
  bytes_group_any $mnt/group_bytesdir1 bytes $((1<<20)) $grp
}

function TEST_group_chown_write()
{
  local user=$user1
  local grp=`id -n -g $user`
  local nuser=$user3
  bytes_chown_group_any $mnt/group_byteschowndir1 bytes $((1<<20)) $grp $nuser
}

function TEST_group_files()
{
  local user=$user1
  local grp=`id -n -g $user`
  files_group_any $mnt/group_filesdir1 files 3 $grp
}

function TEST_group_chown_files()
{
  local user=$user1
  local grp=`id -n -g $user`
  local nuser=$user3
  files_chown_group_any $mnt/group_fileschowndir1 files 3 $grp $nuser
}

# move file from one dir to anther
function user_rename()
{
  
  return 0;
}

function user_link()
{
  return 0;
}

function user_hardlink()
{
  return 0;
}

function user_remove()
{
  return 0;
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
    exit 1
  fi
}

reset_env
#files_1000
#bytes_1024

#<<xx
RUN_CASE TEST_user_write
RUN_CASE TEST_user_chown_write
RUN_CASE TEST_user_files
RUN_CASE TEST_user_chown_files
RUN_CASE TEST_group_write
RUN_CASE TEST_group_chown_write
RUN_CASE TEST_group_files
RUN_CASE TEST_group_chown_files
#xx
