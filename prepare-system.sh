#!/usr/bin/env sh

# FreeBSD packages

mv /etc/pkg/FreeBSD.conf /etc/pkg/FreeBSD.conf.old
cp FreeBSD.conf /etc/pkg/

# OpenSSH

rm /etc/ssh/ssh_host_*
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli

mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
cp sshd_config /etc/ssh/

/etc/rc.d/sshd restart

# NTP

mv /etc/ntp.conf /etc/ntp.conf.old
cp ntp.conf /etc/
cat etc_defaults_rc.conf >> /etc/rc.conf
/etc/rc.d/ntpd restart

# sysctl

cp sysctl.conf /etc/
/sbin/sysctl -f /etc/sysctl.conf

# build system

cp make.conf /etc/
cp src.conf /etc/

rm -rf /usr/src
mkdir /usr/src
chown -R root:wheel /usr/src
chmod -R 0755 /usr/src

git clone --depth 1 -b stable/14 https://git.FreeBSD.org/src.git /usr/src

cp server14 /usr/src/sys/amd64/conf/
