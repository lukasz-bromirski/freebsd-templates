#!/usr/bin/env bash

# some hardcoded defaults
KERNCONF=server14
KERNCONF_STR="KERNCONF=${KERNCONF}"
MAKE_CMD="make"
MAKE_ARGS="-j`sysctl -n hw.ncpu`"
MAKE="$MAKE_CMD ${MAKE_ARGS}"
DATE=`date +%Y-%m-%d.%H%M%S`

# Preparation
rm -rf /usr/obj
cd /usr/src
${MAKE} clean >/dev/null
git pull > /usr/src/build.$DATE.git.txt

# Build process
time -h ${MAKE} buildworld > /usr/src/build.$DATE.world.txt
if [ $? -eq 0 ]; then
   echo "Process finished, moving to kernel" >> /usr/src/build.$DATE.world.txt
   time -h ${MAKE} ${KERNCONF_STR} kernel > /usr/src/build.$DATE.kernel.txt
   if [ $? -eq 0 ]; then
        echo "Process finished, build complete" >> /usr/src/build.$DATE.kernel.txt
   else
        echo "Process failed, check logs" >> /usr/src/build.$DATE.kernel.txt
   fi
else
   echo "Process failed, check logs" >> /usr/src/build.$DATE.world.txt
fi
