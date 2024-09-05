#!/bin/sh

for jail in /usr/local/jails/*; do
   service jail stop $jail
   make installworld DESTDIR=$jail
   make BATCH_DELETE_OLD_FILES=YES delete-old delete-old-libs DESTDIR=$jail
   etcupdate -D $jail
   service jail start $jail
done
