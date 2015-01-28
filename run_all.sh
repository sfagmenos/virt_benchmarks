#!/bin/bash
KERNEL="linux-3.17"
KERNEL_TAR="$KERNEL.tar.gz"
KERNEL_XZ="$KERNEL.tar.xz"
KB="kernbench"
KB_VER="0.50"
KB_TAR="$KB-$KB_VER.tar.gz"
FIO="fio"
FIO_VER="2.1.10"
FIO_DIR="$FIO-$FIO_VER"
FIO_TAR="$FIO-$FIO_VER.tar.gz"
FIO_TEST_DIR="fio_test"

PBZIP_DIR="pbzip_test"

TEST_PBZIP=1
TEST_KERNBENCH=1
TEST_FIO=1

TIMELOG=time.txt
TIME="/usr/bin/time --format=%e -o $TIMELOG --append"

rm -f $TIMELOG
touch $TIMELOG

for i in time awk yes date bc pbzip2
do
	iname=`which $i`
	if [[ ! -a $iname ]] ; then
		echo "$i not found in path, please install it; exiting"
		exit
	else
		echo "$i is found: $iname"
	fi
done


if [[ -d $KERNEL ]]; then
	echo "$KERNEL is here"
else
	if [[ -f $KERNEL_TAR ]]; then
		echo "$KERNEL_TAR is here"
	else
		echo "$KERNEL_TAR is not here"
		wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.17.tar.gz
#I'd better to check checksum or at least file size
	fi

	tar xvfz $KERNEL_TAR
fi

if [[ -f $KERNEL/$KB ]]; then
	echo "$KB is here"
else
	wget http://ftp.be.debian.org/pub/linux/kernel/people/ck/apps/kernbench/kernbench-0.50.tar.gz
	tar xvfz $KB_TAR
	cp $KB-$KB_VER/$KB $KERNEL
fi


if [[ -f $KERNEL_XZ ]]; then
	echo "$KERNEL_XZ is here"
else
	echo "$KERNEL_XZ is not here"
	wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.17.tar.xz
#I'd better to check checksum or at least file size
fi

if [[ -f $FIO_DIR/$FIO ]]; then
	echo "$FIO is here"
else
	wget http://brick.kernel.dk/snaps/fio-2.1.10.tar.gz
	tar xvfz $FIO_TAR
	pushd $FIO_DIR
	./configure
	make
	popd
	if [[ -f $FIO_DIR/$FIO ]]; then
		echo "$FIO is ready"
	else
		echo "$FIO is not ready"
	fi
fi


echo "; random write of 128mb of data

[random-write]
rw=randwrite
filename=$KERNEL_XZ
direct=1
invalidate=1
iodepth=8
ioengine=sync
" > random-write-test.fio

echo "; random read of 128mb of data

[random-read]
rw=randread
filename=$KERNEL_XZ
direct=1
invalidate=1
iodepth=8
ioengine=sync
" > random-read-test.fio

if [[ $TEST_PBZIP == 1 ]]; then
	mkdir $PBZIP_DIR 
	cp $KERNEL_XZ $PBZIP_DIR
	echo "pbzip2 compress" >> $TIMELOG
	$TIME pbzip2 -p2 -m500 $PBZIP_DIR/$KERNEL.tar.xz
	echo "pbzip2 decompress" >> $TIMELOG
	$TIME pbzip2 -d -m500 -p2 $PBZIP_DIR/$KERNEL.tar.xz.bz2
	rm -rf $PBZIP_DIR
fi

if [[ $TEST_FIO == 1 ]]; then
	echo "fio random read" >> $TIMELOG
	$TIME ./$FIO_DIR/$FIO --output fio_read.out random-read-test.fio
	echo "fio random write" >> $TIMELOG
	$TIME ./$FIO_DIR/$FIO --output fio_write.out random-write-test.fio
fi

if [[ $TEST_KERNBENCH == 1 ]]; then
	pushd $KERNEL
	./kernbench -M -f
	popd

fi
