#!/bin/bash -x

set -e

function expect_false()
{
	#set -x
	ret=$@
	echo ret=$ret
	#if "$@";then
	eval "$ret";
	#if eval "$ret";then
	if eval "$@"; then
		echo return 1;
		return 1;
	else
		echo return 0;
		return 0;
	fi
}

function expect_value()
{
	wanted_ret=$(($1))
	shift
	
	eval $@ &> /dev/null
	ret=$?
	echo wanted_ret=$wanted_ret
	echo ret=$ret
	if [ $wanted_ret -ne $ret ];then
		echo 1
		return 1
	fi
	echo 0
	return 0
}

#expect_false echo helloword
expect_value 1 echo helloword
