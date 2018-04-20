#!/bin/bash

function reload_export()
{
	func=reload_export
	if [ $# -lt 3 ];then
		echo "$func: not enough parameters"
		exit;
	fi
	id=$1
	pesudo=$2
	conf=$3 #/etc/ganesha/ganesha.conf
	echo $id $pesudo
	dbus-send --print-reply --system --dest=org.ganesha.nfsd /org/ganesha/nfsd/ExportMgr \
	org.ganesha.nfsd.exportmgr.RemoveExport uint16:$id
	
	dbus-send --print-reply --system --dest=org.ganesha.nfsd /org/ganesha/nfsd/ExportMgr \
	org.ganesha.nfsd.exportmgr.AddExport string:$conf string:"EXPORT(Pseudo=$pesudo)"
	
	dbus-send --print-reply --system --dest=org.ganesha.nfsd /org/ganesha/nfsd/ExportMgr \
	org.ganesha.nfsd.exportmgr.ShowExports
}

function reload_all()
{
	local func=reload_all
	if [ $# -lt 1 ];then
		echo "$func: conf not input"
		exit;
	fi
	conf=$1
	echo reload_all
	export_ids=(`awk '/Export_Id/{split($3, arr, ";"); print arr[1]}' $conf`);
	pseudo_paths=(`awk '/Pseudo/{split($3, arr, ";"); print arr[1]}' $conf`);
	IIFS=$IFS
	IFS='"'
	for ((i = 0; i < ${#export_ids[@]}; i++))
	do
		#echo ${export_ids[$i]} ${pseudo_paths[$i]}
		reload_export ${export_ids[$i]} $(echo ${pseudo_paths[$i]}) $conf
	done
	IFS=$IIFS
	#export_ids=(`awk '{/Export_Id/}'`);
}

reload_all /etc/ganesha/ganesha.conf
