#!/usr/bin/env sh

rm -rf /usr/src
mkdir /usr/src
chown -R root:wheel /usr/src
chmod -R 0755 /usr/src

git clone --depth 1 -b stable/14 https://git.FreeBSD.org/src.git /usr/src

cp server14 /usr/src/sys/amd64/conf/

./build.master.sh
