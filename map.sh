#!/bin/bash

declare -A map=();
map[key1]=val1;
map[key2]=val2;
map[key3]=val3;
for k in ${!map[@]}
do
	echo "$k --> ${map[$k]}"
done

