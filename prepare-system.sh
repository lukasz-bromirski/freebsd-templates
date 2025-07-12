#!/usr/bin/env sh

# FreeBSD packages

echo "Updating FreeBSD packages to latest"
mv /etc/pkg/FreeBSD.conf /etc/pkg/FreeBSD.conf.old
cp FreeBSD.conf /etc/pkg/

# OpenSSH

echo "Updating OpenSSH to hardened and key-only auth"
rm /etc/ssh/ssh_host_*
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli

mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
cp sshd_config /etc/ssh/

/etc/rc.d/sshd restart

# NTP

echo "Updating NTP to hardened config and proper hosts"
mv /etc/ntp.conf /etc/ntp.conf.old
cp ntp.conf /etc/
cat etc_defaults_rc.conf >> /etc/rc.conf
/etc/rc.d/ntpd restart

# sysctl

echo "Updating system sysctls and applying them"
cp sysctl.conf /etc/
/sbin/sysctl -f /etc/sysctl.conf

# build system

echo "Adding proper build files"
cp make.conf /etc/
cp src.conf /etc/

echo "Cleaning up /usr/src"
rm -rf /usr/src
mkdir /usr/src
chown -R root:wheel /usr/src
chmod -R 0755 /usr/src

echo "Cloning 14-STABLE"
git clone --depth 1 -b stable/14 https://git.FreeBSD.org/src.git /usr/src

echo "Copying server14 configuration file"
cp server14 /usr/src/sys/amd64/conf/

echo "Done"
