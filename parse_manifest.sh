#!/bin/bash

pool=default.rgw.buckets.data
object=$1
binfile=/tmp/mm.bin.$$

rados -p $pool getxattr $object user.rgw.manifest >$binfile
ceph-dencoder type RGWObjManifest import $binfile decode dump_json

rm -f $binfile
