#!/bin/bash

modprobe nfs
echo 65535 > /proc/sys/sunrpc/nfs_debug
