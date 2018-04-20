#!/bin/bash

function unixtime_to_date()
{
  second=$1
  echo $second | gawk -v str=$second '{  
    day = strftime("%Y-%m-%d %H:%M:%S", str);
    print day
  }'
}

unixtime_to_date $1
