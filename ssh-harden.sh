#!/bin/sh

rm /etc/ssh/ssh_host_*
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" 

awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli

mv /etc/ssh/sshd_config /etc/ssh/sshd_config.old
cp sshd_config /etc/ssh/

/etc/rc.d/sshd restart
