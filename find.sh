#!/bin/bash


lib_pattern=$1
func=$2

function usage()
{
  echo "./$0 <pattern> <func>"
}

if [ $# -lt 2 ];then
  usage
  exit
fi

echo $@

libs=(`find /usr/lib64|grep $lib_pattern`)
for lib in ${libs[@]}
do
	nm -o $lib 2>/dev/null |grep " $func$"
done

sbins=(`find /usr/sbin/|grep $lib_pattern`)
for sbin in ${sbins[@]}
do
	nm -o $sbin 2>/dev/null |grep " $func$"
done

bins=(`find /usr/sbin/|grep $lib_pattern`)
for bin in ${bins[@]}
do
	nm -o $bin 2>/dev/null |grep " $func$"
done
