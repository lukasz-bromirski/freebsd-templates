#!/usr/bin/env bash

# some hardcoded defaults
KERNCONF=server
KERNCONF_STR="KERNCONF=${KERNCONF}"
MAKE_CMD="make"
MAKE_ARGS="-j4"
MAKE="$MAKE_CMD ${MAKE_ARGS}"
DATE=`date +%Y-%m-%d.%H%M%S`

# Preparation
rm -rf /usr/obj
cd /usr/src
${MAKE} clean >/dev/null
git pull > /usr/src/build.$DATE.git.txt

# Build process
${MAKE} buildworld > /usr/src/build.$DATE.world.txt
if [ $? -eq 0 ]; then
   echo "Process finished, moving to kernel" >> /usr/src/build.$DATE.world.txt
   ${MAKE} buildkernel > /usr/src/build.$DATE.kernel.txt
   if [$? -eq 0 ]; then
        echo "Process finished, build complete" >> /usr/src/build.$DATE.kernel.txt
   else
        echo "Process failed, check logs" >> /usr/src/build.$DATE.kernel.txt
   fi
else
   echo "Process failed, check logs" >> /usr/src/build.$DATE.world.txt
fi
