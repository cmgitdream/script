#!/bin/bash

pool=$1
pg_num=$2

ceph osd pool set $pool pg_num $pg_num
sleep 2
ceph osd pool set $pool pgp_num $pg_num
