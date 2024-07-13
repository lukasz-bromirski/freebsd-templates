#!/usr/bin/env sh

echo "kern.elf64.aslr.enable=1" >> /boot/loader.conf
echo "kern.elf32.aslr.enable=1" >> /boot/loader.conf
