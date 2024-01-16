#!/usr/bin/env sh

mv /etc/pkg/FreeBSD.conf /etc/pkg/FreeBSD.conf.old
cp FreeBSD.conf /etc/pkg/

./ssh-harden.sh

mv /etc/ntp.conf /etc/ntp.conf.old
cp ntp.conf /etc/
/etc/rc.d/ntpd restart

cp make.conf /etc/
cp src.conf /etc/
cp sysctl.conf /etc/
/sbin/sysctl -f /etc/sysctl.conf

./init.14.sh



