#!/bin/bash

function usage()
{
  echo " <pool> <size>"
}

function resize_pool()
{
  local poolid=$1
  local size=$2
  
  ceph osd pool set $poolid min_size $size
  ceph osd pool set $poolid size $size
}

function resize_to_one()
{
  local lpool=$1
  local lsize=1
  resize_pool $lpool $lsize
}

function main()
{
  if [ $# -lt 2 ];then
    usage
    exit
  fi
  resize_to_one $1
}

main $*
