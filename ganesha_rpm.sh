#!/bin/bash
set -e

version=
url=http://xxx/$version/x86_64
suffix=el7.x86_64.rpm
subversion=0

rpms=(
nfs-ganesha
nfs-ganesha-ceph_rgwfs
nfs-ganesha-debuginfo
nfs-ganesha-mount-9P
nfs-ganesha-nullfs
nfs-ganesha-proxy
nfs-ganesha-utils
nfs-ganesha-vfs
)

function install()
{
for rpm in ${rpms[@]}
do
	package=$url/$rpm-$version-$subversion.$suffix
	echo $package
	rpm -Uvh --force --nodeps $package
done
}

function uninstall()
{
  N=${#rpms[@]}
  i=$(($N - 1))
  for ((; i >=0; i-- ))
  do
        package=${rpms[$i]}
        echo $package
        rpm -e --nodeps $package || return 1
  done
}

$*
