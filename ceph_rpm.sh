#!/bin/bash
set -e

version=
url=http://xxx/$version/x86_64
suffix=el7.x86_64.rpm
subversion=0

version2=
url2=http://xxx/x86_64
subversion2=
suffix2=el7.x86_64.rpm


#ceph-selinux
rpms=(
librados2
librados2-devel
libradosstriper1
libradosstriper1-devel
librbd1
librbd1-devel
libcephfs1
libcephfs1-devel
librgw2
librgw2-devel
python-rados
python-rbd
python-cephfs
ceph-base
ceph-common
ceph
ceph-devel-compat
ceph-mon
ceph-osd
ceph-mds
ceph-radosgw
ceph-fuse
rbd-fuse
rbd-nbd
rbd-mirror
ceph-test
)


rpms2=(
librados2
librados-devel
librgw2
librgw-devel
librbd1
librbd1-devel
python-ceph-compat
python-rados
python-rbd
python-rgw
ceph-base
ceph-common
ceph
ceph-mon
ceph-mgr
ceph-osd
ceph-radosgw
rbd-nbd
ceph-test
)

# rpm in rpms not in rpms2
extra_rpms=(
ceph-mds
libradosstriper1
libradosstriper-devel
libcephfs2
libcephfs-devel
librados2-devel
libradosstriper1-devel
libcephfs2-devel
librgw2-devel
ceph-devel-compat
rbd-mirror
ceph-fuse
rbd-fuse
python-cephfs
)

check_or_install()
{
    set +e
    rpm -q `rpm -qp $1` > /dev/null 2>&1;
    code=$?
    set -e
    if [[ $code -ne 0 ]]; then
        rpm -Uvh --force --nodeps $1
    fi
}

install_one()
{
    package=$url/$1-$version-$subversion.$suffix
    echo $package
    rpm -Uvh --force --nodeps $package
}

install2_one()
{
    local dir=./pkgs
    if [ ! -e $dir ];then
      sudo mkdir $dir
    fi
    pushd $dir
    package=$1-$version2-$subversion2.$suffix2
    sudo wget -r -np -nd --no-check-certificate $url2/$package
    echo $package
    rpm -Uvh --force --nodeps $package
    popd
}

function install()
{
  for rpm in ${rpms[@]}
  do
	package=$url/$rpm-$version-$subversion.$suffix
		
	echo $package
	rpm -Uvh --force --nodeps $package
  done
}

#install luminous
function install2()
{
  local force=0
  if [ $# -gt 0 ];then
    force=$(($1))
  fi
  local dir=./pkgs
  if [ ! -e $dir ];then
  sudo mkdir $dir
  fi
  pushd $dir
  #force download packages
  if [ $force -ne 0 ];then
  rm -rf $dir/*
  for rpm in ${rpms2[@]}
  do
    package=$rpm-$version2-$subversion2.$suffix2
    sudo wget -r -np -nd --no-check-certificate $url2/$package
   
    echo $package
  done
  fi
  pwd 
  ls -l .
  for rpm in ${rpms2[@]}
  do
    package=$rpm-$version2-$subversion2.$suffix2
    sudo rpm -Uvh --force --nodeps $package
  done
  popd
}

function uninstall()
{
  N=${#rpms[@]}
  i=$(($N - 1))
  for ((; i >=0; i-- ))
  do
	package=${rpms[$i]}
	echo $package
	rpm -e --nodeps $package || echo ok
  done
}

function uninstall2()
{
  N=${#rpms2[@]}
  i=$(($N - 1))
  for ((; i >=0; i-- ))
  do
	package=${rpms2[$i]}
	echo $package
	rpm -e --nodeps $package || echo ok
  done
  N=${#extra_rpms[@]}
  i=$(($N - 1))
  # extra uninstall for rpms
  for ((; i >=0; i-- ))
  do
	package=${extra_rpms[$i]}
	echo $package
	rpm -e --nodeps $package || echo ok
  done
}

$*
