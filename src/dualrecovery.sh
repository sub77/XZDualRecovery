#!/sbin/busybox sh
#
# Dual Recovery for the Xperia Z, ZL, Tablet Z, Z Ultra and Z1!
#
# Author:
#   [NUT]
#
# - Thanks go to DooMLoRD for the keycodes and a working example!
# - My gratitude also goes out to Androxyde for his sometimes briliant
#   ideas to simplify things while writing the scripts!
#
###########################################################################

set +x
_PATH="$PATH"
export PATH="/system/xbin:/system/bin:/sbin"

# Defining constants, from commandline
EVENTNODE="$1"
POWERNODE="$2"
DRPATH="$3"
LOGFILE="$4"
LOG="${DRPATH}/${LOGFILE}"

# Kickstarting log
DATETIME=`date +"%d-%m-%Y %H:%M:%S"`
echo "START Dual Recovery at ${DATETIME}: STAGE 2." > ${LOG}

# Z setup
#BOOTREC_CACHE_NODE="/dev/block/mmcblk0p25 b 179 25"
#BOOTREC_CACHE="/dev/block/mmcblk0p25"
BOOTREC_EXTERNAL_SDCARD_NODE="/dev/block/mmcblk1p1 b 179 32"
BOOTREC_EXTERNAL_SDCARD="/dev/block/mmcblk1p1"
BOOTREC_LED_RED="/sys/class/leds/$(ls -1 /sys/class/leds|grep red)/brightness"
BOOTREC_LED_GREEN="/sys/class/leds/$(ls -1 /sys/class/leds|grep green)/brightness"
BOOTREC_LED_BLUE="/sys/class/leds/$(ls -1 /sys/class/leds|grep blue)/brightness"

# Defining functions
ECHOL(){
  _TIME=`busybox date +"%H:%M:%S"`
  echo "$_TIME: $*" >> ${LOG}
  return 0
}
EXECL(){
  _TIME=`busybox date +"%H:%M:%S"`
  echo "$_TIME: $*" >> ${LOG}
  $* 2>&1 >> ${LOG}
  _RET=$?
  echo "$_TIME: RET=$_RET" >> ${LOG}
  return ${_RET}
}
SETLED() {
        if [ "$1" = "on" ]; then

                ECHOL "Turn on LED R: $2 G: $3 B: $4"
                echo "$2" > ${BOOTREC_LED_RED}
                echo "$3" > ${BOOTREC_LED_GREEN}
                echo "$4" > ${BOOTREC_LED_BLUE}

        else

                ECHOL "Turn off LED"
                echo "0" > ${BOOTREC_LED_RED}
                echo "0" > ${BOOTREC_LED_GREEN}
                echo "0" > ${BOOTREC_LED_BLUE}

        fi
}
DRGETPROP() {

	# Get the property from getprop
	PROP=`/system/bin/getprop $*`

	if [ "$PROP" = "" ]; then

		# If it's empty, see if what was requested was a XZDR.prop value!
		PROP=`grep "$*" ${DRPATH}/XZDR.prop | awk -F'=' '{ print $NF }'`

	fi
	if [ "$PROP" = "" ]; then

		# If it still is empty, try to get it from the build.prop
		PROP=`grep "$*" /system/build.prop | awk -F'=' '{ print $NF }'`

	fi

	echo $PROP

}

ECHOL "Checking device model..."
MODEL=$(DRGETPROP ro.product.model)
VERSION=$(DRGETPROP ro.build.id)
PHNAME=$(DRGETPROP ro.semc.product.name)

ECHOL "Model found: $MODEL ($PHNAME - $VERSION)"

ECHOL "DR Keycheck..."

cat ${EVENTNODE} > /dev/keycheck &

# Vibrate to alert user to make a choice
ECHOL "Trigger vibrator"
echo 150 > /sys/class/timed_output/vibrator/enable
usleep 300000
echo 150 > /sys/class/timed_output/vibrator/enable

# Turn on green LED as a visual cue
SETLED on 0 255 0

EXECL sleep 3

KEYCHECK=""

hexdump < /dev/keycheck > /dev/keycheckout

VOLUKEYCHECK=`cat /dev/keycheckout | grep '0001 0073' | wc -l`
VOLDKEYCHECK=`cat /dev/keycheckout | grep '0001 0072' | wc -l`

if [ "$VOLUKEYCHECK" != "0" ]; then
	ECHOL "Recorded VOL-UP on ${EVENTNODE}!"
	KEYCHECK="UP"
elif [ "$VOLDKEYCHECK" != "0" ]; then
	ECHOL "Recorded VOL-DOWN on ${EVENTNODE}!"
	KEYCHECK="DOWN"
elif [ "$VOLUKEYCHECK" != "0" -a "$VOLDKEYCHECK" != "0" ]; then
	ECHOL "Recorded BOTH VOL-UP & VOL-DOWN on ${EVENTNODE}! Making the choice to go to the UP target..."
	KEYCHECK="UP"
fi

EXECL killall cat

EXECL rm -f /dev/keycheck
EXECL rm -f /dev/keycheckout

if [ "$KEYCHECK" != "" -o -f "${DRPATH}/boot" -o -f "/cache/recovery/boot" ]; then

	ECHOL "Recovery boot mode selected"

	# Recovery boot mode notification
	SETLED on 255 0 255

	if [ -f "${DRPATH}/boot" ]; then
		EXECL rm -f ${DRPATH}/boot
	fi

	if [ -f "/cache/recovery/boot" ]; then
		EXECL rm -f /cache/recovery/boot
	fi

	cd /

	#read what CWM to use
	if [ "$(DRGETPROP dr.vanilla.cwm)" = "true" -o "$(DRGETPROP dr.vanilla.cwm)" = "1" -o "$(DRGETPROP dr.vanilla.cwm)" = "yes" ]; then
		ECHOL "User defined choice for vanilla CWM!"
		CWM="cwm"
	else
		ECHOL "Will be using PhilZ Touch Recovery when CWM choice has been made!"
		CWM="philz"
	fi

	#read default, for use with the boot flag file.
	if [ "$(DRGETPROP dr.default.recovery)" = "twrp" ]; then
		RECLOG="Booting TWRP by default..."
		RECOVERY="/sbin/recovery.twrp.cpio.lzma"
	else
		RECLOG="Booting CWM/PhilZ by default..."
		RECOVERY="/sbin/recovery.${CWM}.cpio.lzma"
	fi

  	# Prepare CWM recovery
	if [ -f "/system/bin/recovery.${CWM}.cpio.lzma" -a "$KEYCHECK" = "UP" ]; then
		RECLOG="Booting CWM/PhilZ by keypress..."
		RECOVERY="/sbin/recovery.${CWM}.cpio.lzma"
	fi

	# Prepare TWRP recovery
	if [ -f "/system/bin/recovery.twrp.cpio.lzma" -a "$KEYCHECK" = "DOWN" ]; then
		RECLOG="Booting TWRP by keypress..."
		RECOVERY="/sbin/recovery.twrp.cpio.lzma"
	fi

	# Boot the recovery, if the file exists
	if [ -f "${RECOVERY}" ]; then

		# Record choice in log
		ECHOL "${RECLOG}"

		# Stop init services.
		ECHOL "Stop init services..."
		for SVCRUNNING in $(getprop | grep -E '^\[init\.svc\..*\]: \[running\]'); do
			SVCNAME=$(expr ${SVCRUNNING} : '\[init\.svc\.\(.*\)\]:.*')
			EXECL stop ${SVCNAME}
		done

		EXECL kill -9 $(ps | grep rmt_storage | grep -v "grep" | awk -F' ' '{print $1}')

		# umount partitions, stripping the ramdisk to bare metal
		ECHOL "Umount partitions and then executing init..."
		EXECL umount -l /acct
		EXECL umount -l /dev/cpuctl
		EXECL umount -l /dev/pts
		EXECL umount -l /mnt/asec
		EXECL umount -l /mnt/obb
		EXECL umount -l /mnt/qcks
		EXECL umount -l /data/idd	# Appslog
		EXECL umount -l /data		# Userdata
		EXECL umount -l /lta-label	# LTALabel

		# AS OF HERE NO MORE BUSYBOX SYMLINKS IN $PATH!!!!

		export PATH="/sbin"
		busybox umount -l /system	# System

		# rm symlinks & files.
		busybox find . -maxdepth 1 \( -type l -o -type f \) -exec busybox rm -fv {} \; 2>&1 >> ${LOG}

		for directory in `busybox find . -maxdepth 1 -type d`; do
			if [ "$directory" != "." -a "$directory" != ".." -a "$directory" != "./" -a "$directory" != "./dev" -a "$directory" != "./proc" -a "$directory" != "./sys" -a "$directory" != "./sbin" -a "$directory" != "./cache" -a "$directory" != "./storage" ]; then
				busybox echo "rm -vrf $directory" >> ${LOG}
				busybox rm -vrf $directory 2>&1 >> ${LOG}
			fi
		done

		# extract recovery
		busybox echo "Extracting recovery..." >> ${LOG}
		busybox lzcat ${RECOVERY} | busybox cpio -i -u

		# Turn off LED
		SETLED off

		# From here on, the log dies, as these are the locations we log to!
		# Ending log
		DATETIME=`busybox date +"%d-%m-%Y %H:%M:%S"`
		echo "STOP Dual Recovery at ${DATETIME}: Executing recovery init, have fun!" >> ${LOG}
		umount -l /storage/sdcard1	# SDCard1
		umount -l /cache		# Cache
		umount -l /proc
		umount -l /sys

		# exec
		exec /init

	else

		ECHOL "The recovery file does not exist, exitting with a visual warning!"
		SETLED on 255 0 0

		sleep 2

	fi

fi

# Turn off LED
SETLED off

# Check and prepare for stock ramdisk
STOCKRAMDISK=""
PACKED=""
if [ -f "$(DRGETPROP dr.ramdisk.location)" -a "$(DRGETPROP dr.insecure.ramdisk)" = "true" ]; then

	STOCKRAMDISK=$(DRGETPROP dr.ramdisk.location)
	PACKED=$(basename $STOCKRAMDISK | awk -F . '{print $NF}')
	cp $STOCKRAMDISK /sbin/

fi

if [ -f "$(DRGETPROP dr.ramdisk.location)" -a "$(DRGETPROP dr.insecure.ramdisk)" = "power" ]; then

	ECHOL "Power keycheck..."

	cat ${POWERNODE} > /dev/keycheck &

	# Vibrate to alert user to make a choice
	ECHOL "Trigger vibrator"
	echo 150 > /sys/class/timed_output/vibrator/enable
	usleep 300000
	echo 150 > /sys/class/timed_output/vibrator/enable

	# Turn on amber LED as a visual cue
	SETLED on 255 255 0

	EXECL sleep 3

	KEYCHECK=""

	hexdump < /dev/keycheck > /dev/keycheckout

	SETLED off

	POWERKEYCHECK=`cat /dev/keycheckout | wc -l`

	if [ "$POWERKEYCHECK" != "0" ]; then
		ECHOL "Power button pressed, will attempt booting insecure ramdisk!"
		STOCKRAMDISK=$(DRGETPROP dr.ramdisk.location)
		PACKED=$(basename $STOCKRAMDISK | awk -F . '{print $NF}')
		cp $STOCKRAMDISK /sbin/
	fi

	EXECL killall cat

	EXECL rm -f /dev/keycheck
	EXECL rm -f /dev/keycheckout

fi

if [ "$PACKED" != "lzma" -a "$PACKED" != "cpio" -a "$PACKED" != "tar" ]; then

	ECHOL "Unknown archive type, use only cpio, cpio.lzma and tar archives!"
	STOCKRAMDISK=""

fi

# If the ramdisk is not present or if the setting in the XZDR.prop
# file has been set to disabled, we do a regular boot.
if [ "$STOCKRAMDISK" != "" ] && [ "$(DRGETPROP dr.insecure.ramdisk)" = "true" -o "$(DRGETPROP dr.insecure.ramdisk)" = "power" ]; then

	ECHOL "Insecure ramdisk boot..."

	cd /

	# extract replacement ramdisk
	ECHOL "Extracting ramdisk..."
	if [ "$PACKED" = "tar" ]; then
		tar xf $STOCKRAMDISK
	elif [ "$PACKED" = "cpio" ]; then
		cpio -i -u < $STOCKRAMDISK
	else
		lzcat $STOCKRAMDISK | busybox cpio -i -u
	fi

	# Ending log
	DATETIME=`date +"%d-%m-%Y %H:%M:%S"`
	ECHOL "STOP Dual Recovery at ${DATETIME}: Executing insecure ramdisk init, have fun!"

	# exec
	exec /init

else

	# The following will get done 'on boot' which spoils the fun on the Z1 JB4.3 ROM's ...
	# mount -o nosuid,nodev,noexec securityfs /sys/kernel/security
	# echo 1 > /sys/kernel/security/sony_ric/enable
	# This script will attempt to reverse that... (and sofar, failing to do so)
	# In any case it is the complete integration of the remount-reboot fix

	TECHOL "RIC service: Making sure it does not bother us..."
	nohup /system/bin/rickiller.sh $(which busybox) &

	# init.d support
	if [ "$(DRGETPROP dr.enable.initd)" = "true" ]; then

		ECHOL "Init.d folder found and execution is enabled!"
		ECHOL "It will run the following scripts:"
		run-parts -t /system/etc/init.d 2>&1 >> ${LOG}
		ECHOL "Executing them in the background now."
		nohup run-parts /system/etc/init.d &

	else

		ECHOL "Init.d execution is disabled."
		ECHOL "To enable it, set dr.enable.initd to true in XZDR.prop!"

	fi

	ECHOL "Remount / ro..."
	mount -o remount,ro rootfs /
	ECHOL "Remount /system ro..."
	mount -o remount,ro /system

	ECHOL "Return to normal boot mode..."

	# Ending log
	DATETIME=`busybox date +"%d-%m-%Y %H:%M:%S"`
	echo "STOP Dual Recovery at ${DATETIME}: STAGE 2." >> ${LOG}

	# Unmount SDCard1
	umount -f /storage/sdcard1

	# Return path variable to default
	export PATH="${_PATH}"

	# Continue booting
	exec /system/bin/chargemon.stock

fi
