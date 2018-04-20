#!/bin/bash
function find_one_py_packages()
{
        pat=$1
        find /usr/lib/python2.7/|grep $pat; find /usr/lib64/python2.7/|grep $pat;
}
function find_group_py_packages()
{
        find_one_py_packages ceph
        find_one_py_packages rados
        find_one_py_packages rbd
        find_one_py_packages rgw
}
function rm_group_py_packages()
{
        find_group_py_packages |xargs -n 1 -I @ rm -rf @
}
find_group_py_packages
rm_group_py_packages
