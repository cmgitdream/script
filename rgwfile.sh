#!/bin/bash

# mapping file to rgw objects

. parse_h.sh

workdir= #/tmp/$file
head_file= #$workdir/head.$$
objects_file= #$workdir/objects.$$
objects_dir= #$workdir/objdir
pool= #default.rgw.buckets.data


function dump_backslash()
{
	echo $1|sed -e 's/_/\\\\u/gp'|head -n 1
}

usage() {
	echo "./rgwfile <bucket> <file_in_bucket>"
	echo -e "eg. if search /nfsqa/testfile1\n ./rgwfile nfsroot2 nfsqa/testfile1"
}

function joint_no_hole_file()
{
	filename=$objects_dir/`basename $1`
	mkdir -p $objects_dir
	echo $filename
	> $filename

	#echo head_file=$head_file
	#cat $head_file
	#echo
	head_object=`cat $head_file`
	data_object=
	head_obj_file=$objects_dir/`basename $1`

	#echo head_object=$head_object
	#echo head_obj_file=$head_obj_file
	rados -p $pool get $head_object $filename
	#ls -l $filename

	for data_object in `cat $objects_file`
	do
		echo $data_object
		i=`echo $data_object|awk -F "_" '{print $5}'`
		f=$objects_dir/$data_object
		rados -p $pool get $data_object $f
		#ls -l $f
		cat $f >> $filename
		rm -f $f
	done

	echo
	ls -lh $filename
	du -h $filename
	md5sum $filename
}

function get_rgwfile()
{
	if [ $# -lt 2 ];then
		usage
		exit
	fi
	
	bucket=$1
	file=$2
	bucketid=`radosgw-admin bucket stats --bucket=$bucket 2>/dev/null |awk '{if ($1 ~ /"id":/) { split($2, arr, /"/); print arr[2]}}'`
	datapool=`radosgw-admin bucket stats --bucket=$bucket 2>/dev/null |awk '{if ($1 ~ /"pool":/) { split($2, arr, /"/); print arr[2]}}'`

	workdir=/tmp/$bucket"_"$file
	head_file=$workdir/head.$$
	objects_file=$workdir/objects.$$
	objects_dir=$workdir/objdir
	pool=$datapool #default.rgw.buckets.data
	mkdir -p $workdir
	mkdir -p $objects_dir

        #echo $bucketid $datapool
 	echo "bucketid = $bucketid"
 	echo "datapool = $datapool"
        head_obj=`rados -p $datapool ls|grep -E "^$bucketid"_"$file$"`
	echo head_obj = $head_obj
        if [ "$head_obj"x = ""x ];then
                echo "$file not exist in bucket $bucket"
                exit
        fi
        #echo head_obj=$head_obj

	object=$head_obj
	#echo "object=$object"
	decode_manifest
	decode_unix1
	decode_idtag

	prefix=`cat $manifest_out \
		| awk '{if ($1 ~ /"prefix":/) { split($2, arr, /"/); print arr[2]}}'`

	filesize=`cat $manifest_out \
		| awk '{if ($1 ~ /"obj_size":/) { split($2, arr, /,/); print arr[1]}}'`

	echo -n $head_obj > $head_file

	rados -p $datapool ls|grep -E $bucketid"_.*_"$prefix".*"|sort -t '_' -k 5.1,5 -h >$objects_file

	echo -e "bucket:\t\t$bucket"
	echo -e "file:\t\t$file"
	echo -e "filesize:\t$filesize"
	echo -e "prefix:\t\t$prefix"
	hsize=`rados -p $datapool stat $head_obj|awk '{print $6}'`
	echo -e "head_obj:\t$hsize\t\t$head_obj\t"


	for data in `cat $objects_file`
	do
		osize=`rados -p $datapool stat $data|awk '{print $6}'`
		echo -e "data_obj:\t$osize\t\t$data\t"
		
	done

	#joint_no_hole_file $file
	#rm -f $head_file
}

get_rgwfile $*
