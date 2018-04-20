#!/binb/bash


#node182
hosts=(
node101
)
function get_ops()
{
	ganesha_stats|grep NFSv4.0|awk '{print $4}'
}

function get_ops_from_hosts()
{
	ops=0
	for h in ${hosts[@]}
	do
		echo $h
		
		st=`ssh $h ganesha_stats|grep NFSv4.0|awk '{print $4}'`	
		echo $st
		#ops=$(($ops + $st))
	done
	#echo $ops
}

function ops_stat(){
	#get_ops_from_hosts
	old=`get_ops`
	new=0
	while [ 1 ] 
	do
		#new=`get_ops`	
		#echo "new = $new, old = $old"
		echo $(($new - $old))
		old=$new
	sleep 1
	done
}

function export_stat()
{
#requested	uint64_t	bytes requested
#transferred	uint64_t	actually tranferred
#total		uint64_t	Total number of operations
#errors		uint64_t	Number of operations that reported errors
#latency	uint64_t	cumulative time consumed by operation in nanoseconds
#queue wait	uint64_t	cumulative time spent in the rpc wait queue
	id=$1
	oldline=(`ganesha_stats iov4 $id|awk '/(READv4|WRITEv4)/{print $2" "$3" "$4" "$5" "$6" "$7}'`)
	newline=${oldline[@]}
	echo ${oldline[@]}
	echo ${newline[@]}
	while [ 1 ] 
	do
		echo -e "\trequested\ttransferred\ttotal\t\terrors\t\tlatency\t\tqueue_wait"
		newline=(`ganesha_stats iov4 $id|awk '/(READv4|WRITEv4)/{print $2" "$3" "$4" "$5" "$6" "$7}'`)
		for ((j=0; j<12; j++))
		do
			if [ $j -eq 0 ];then
				printf "READv4:\t" 
			fi
			if [ $j -eq 6 ];then
				echo -n -e "\nWRITEv4:"
			fi
			diff=$(( ${newline[$j]} - ${oldline[$j]} ))
			#echo -n -e "\t$diff"
			printf "%d\t\t" $diff
		done	
		echo
		echo
		oldline=(${newline[@]})
		sleep 1
	done
}

function nfs_op_stat()
{
	oldline=(`ganesha_stats fast|awk '/(ACCESS|CLOSE|CREATE|GETATTR|GETFH|LOOKUP|OPEN|OPEN_CONFIRM|PUTFH|READDIR|REMOVE|RENEW|SETCLIENTID|SETCLIENTID_CONFIRM|WRITE)/{print $3}'`)
	newline=
	while [ 1 ]
	do
		echo -e "op_name\t\t\t\t\tiops"
		newline=(`ganesha_stats fast|awk '/(ACCESS|CLOSE|CREATE|GETATTR|GETFH|LOOKUP|OPEN|OPEN_CONFIRM|PUTFH|READDIR|REMOVE|RENEW|SETCLIENTID|SETCLIENTID_CONFIRM|WRITE)/{print $3}'`)
		for ((j=0; j<15; j++))
		do
			case $j in
				0) echo -n -e "ACCESS\t\t\t:\t" ;;
				1) echo -n -e "CLOSE\t\t\t:\t" ;;
				2) echo -n -e "CREATE\t\t\t:\t" ;;
				3) echo -n -e "GETATTR\t\t\t:\t" ;;
				4) echo -n -e "GETFH\t\t\t:\t" ;;
				5) echo -n -e "LOOKUP\t\t\t:\t" ;;
				6) echo -n -e "OPEN\t\t\t:\t" ;;
				7) echo -n -e "OPEN_CONFIRM\t\t:\t" ;;
				8) echo -n -e "PUTFH\t\t\t:\t" ;;
				9) echo -n -e "READDIR\t\t\t:\t" ;;
				10) echo -n -e "REMOVE\t\t\t:\t" ;;
				11) echo -n -e "RENEW\t\t\t:\t" ;;
				12) echo -n -e "SETCLIENTID\t\t:\t" ;;
				13) echo -n -e "SETCLIENTID_CONFIRM\t:\t" ;;
				14) echo -n -e "WRITE\t\t\t:\t" ;;
				*) echo "WRONG OP"; exit ;;
			esac
			#echo -n ${newline[$j]} ${oldline[$j]}
			diff=$(( ${newline[$j]} - ${oldline[$j]} ))
			echo -e "\t$diff"
		done
		echo
		oldline=(${newline[@]})
		sleep 1
	done
}

function inode_cache_stat()
{
	oldline=(`ganesha_stats inode|awk '/Inode Cache/{print $4}'`)
	newline=
	while [ 1 ]
	do
		newline=(`ganesha_stats inode|awk '/Inode Cache/{print $4}'`)
		for ((j=0; j<6; j++))
		do
			case $j in
				0) echo -n -e "Inode Cache Requests\t:\t" ;;
				1) echo -n -e "Inode Cache Hits\t:\t" ;;
				2) echo -n -e "Inode Cache Misses\t:\t" ;;
				3) echo -n -e "Inode Cache Conflicts\t:\t" ;;
				4) echo -n -e "Inode Cache Adds\t:\t" ;;
				5) echo -n -e "Inode Cache Mapping\t:\t" ;;
				*) echo "WRONG item"; exit ;;
			esac
			#echo -n ${newline[$j]} ${oldline[$j]}
			diff=$(( ${newline[$j]} - ${oldline[$j]} ))
			echo -e "\t$diff"
		done
		echo
		oldline=(${newline[@]})
		sleep 1
	done
	
}

function nfs_stat()
{
	id=$1
	export_oldline=(`ganesha_stats iov4 $id|awk '/(READv4|WRITEv4)/{print $2" "$3" "$4" "$5" "$6" "$7}'`)
	export_newline=
	op_oldline=(`ganesha_stats fast|awk '/(ACCESS|CLOSE|CREATE|GETATTR|GETFH|LOOKUP|OPEN|OPEN_CONFIRM|PUTFH|READDIR|REMOVE|RENEW|SETCLIENTID|SETCLIENTID_CONFIRM|WRITE)/{print $3}'`)
	op_newline=
	inode_oldline=(`ganesha_stats inode|awk '/Inode Cache/{print $4}'`)
	inode_newline=
	while [ 1 ] 
	do
		echo -e "\trequested\ttransferred\ttotal\t\terrors\t\tlatency\t\tqueue_wait"
		export_newline=(`ganesha_stats iov4 $id|awk '/(READv4|WRITEv4)/{print $2" "$3" "$4" "$5" "$6" "$7}'`)
		for ((j=0; j<12; j++))
		do
			if [ ${export_oldline[$j]}""x = ""x ];then
				break;
			fi
			if [ $j -eq 0 ];then
				printf "READv4:\t" 
			fi
			if [ $j -eq 6 ];then
				echo -n -e "\nWRITEv4:"
			fi
			export_diff=$(( ${export_newline[$j]} - ${export_oldline[$j]} ))
			#echo -n -e "\t$diff"
			printf "%d\t\t" $export_diff
		done	
		echo
		echo
		export_oldline=(${export_newline[@]})

		#echo -e "op_name\t\t\t\t\tiops"
		op_newline=(`ganesha_stats fast|awk '/(ACCESS|CLOSE|CREATE|GETATTR|GETFH|LOOKUP|OPEN|OPEN_CONFIRM|PUTFH|READDIR|REMOVE|RENEW|SETCLIENTID|SETCLIENTID_CONFIRM|WRITE)/{print $3}'`)
		for ((j=0; j<15; j++))
		do
			if [ ${op_oldline[$j]}""x = ""x ];then
				break;
			fi
			case $j in
				0) echo -n -e "ACCESS\t\t\t:\t" ;;
				1) echo -n -e "CLOSE\t\t\t:\t" ;;
				2) echo -n -e "CREATE\t\t\t:\t" ;;
				3) echo -n -e "GETATTR\t\t\t:\t" ;;
				4) echo -n -e "GETFH\t\t\t:\t" ;;
				5) echo -n -e "LOOKUP\t\t\t:\t" ;;
				6) echo -n -e "OPEN\t\t\t:\t" ;;
				7) echo -n -e "OPEN_CONFIRM\t\t:\t" ;;
				8) echo -n -e "PUTFH\t\t\t:\t" ;;
				9) echo -n -e "READDIR\t\t\t:\t" ;;
				10) echo -n -e "REMOVE\t\t\t:\t" ;;
				11) echo -n -e "RENEW\t\t\t:\t" ;;
				12) echo -n -e "SETCLIENTID\t\t:\t" ;;
				13) echo -n -e "SETCLIENTID_CONFIRM\t:\t" ;;
				14) echo -n -e "WRITE\t\t\t:\t" ;;
				*) echo "WRONG OP"; exit ;;
			esac
			op_diff=$(( ${op_newline[$j]} - ${op_oldline[$j]} ))
			echo -e "\t$op_diff"
		done
		echo
		op_oldline=(${op_newline[@]})

		inode_newline=(`ganesha_stats inode|awk '/Inode Cache/{print $4}'`)
		for ((j=0; j<6; j++))
		do
			if [ ${inode_oldline[$j]}""x = ""x ];then
				break;
			fi
			case $j in
				0) echo -n -e "Inode Cache Requests\t:\t" ;;
				1) echo -n -e "Inode Cache Hits\t:\t" ;;
				2) echo -n -e "Inode Cache Misses\t:\t" ;;
				3) echo -n -e "Inode Cache Conflicts\t:\t" ;;
				4) echo -n -e "Inode Cache Adds\t:\t" ;;
				5) echo -n -e "Inode Cache Mapping\t:\t" ;;
				*) echo "WRONG item"; exit ;;
			esac
			inode_diff=$(( ${inode_newline[$j]} - ${inode_oldline[$j]} ))
			echo -e "\t$inode_diff"
		done
		echo
		inode_oldline=(${inode_newline[@]})
		sleep 3
	done
	
}

#export_stat 1
#nfs_op_stat
#inode_cache_stat
nfs_stat 1
