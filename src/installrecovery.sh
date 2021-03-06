#!/data/local/tmp/recovery/busybox sh
set +x

_PATH="$PATH"
export PATH="/system/bin:/system/xbin:/sbin"

BUSYBOX="/data/local/tmp/recovery/busybox"

LOGDIR="XZDualRecovery"
SECUREDIR="/system/.XZDualRecovery"
DRPATH="/storage/sdcard1/${LOGDIR}"

if [ ! -d "$DRPATH" ]; then
	DRPATH="/cache/${LOGDIR}"
fi

# Find the gpio-keys node, to listen on the right input event
gpioKeysSearch() {
        for INPUTUEVENT in `${BUSYBOX} find /sys/devices \( -path "*gpio*" -path "*keys*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
	return 1
}

# Find the power key node, to listen on the right input event
pwrkeySearch() {
        # pm8xxx (xperia Z and similar)
        for INPUTUEVENT in `${BUSYBOX} find /sys/devices \( -path "*pm8xxx*" -path "*pwrkey*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
        # qpnp_pon (xperia Z1 and similar)
        for INPUTUEVENT in `${BUSYBOX} find $(${BUSYBOX} find /sys/devices/ -name "name" -exec ${BUSYBOX} grep -l "qpnp_pon" {} \; | ${BUSYBOX} awk -F '/' 'sub(FS $NF,x)') \( -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
	return 1
}


DRGETPROP() {

        VAR=`${BUSYBOX} grep "$*" /data/local/tmp/recovery/dr.prop | ${BUSYBOX} awk -F'=' '{ print $1 }'`
        PROP=`${BUSYBOX} grep "$*" /data/local/tmp/recovery/dr.prop | ${BUSYBOX} awk -F'=' '{ print $NF }'`

	if [ "$VAR" = "" -a "$PROP" = "" ]; then

		# If it's empty, see if what was requested was a XZDR.prop value!
        	VAR=`${BUSYBOX} grep "$*" ${DRPATH}/XZDR.prop | ${BUSYBOX} awk -F'=' '{ print $1 }'`
        	PROP=`${BUSYBOX} grep "$*" ${DRPATH}/XZDR.prop | ${BUSYBOX} awk -F'=' '{ print $NF }'`

        	if [ "$VAR" = "" -a "$PROP" = "" ]; then

        	        # If it still is empty, try to get it from the build.prop
                	VAR=`${BUSYBOX} grep "$*" /system/build.prop | ${BUSYBOX} awk -F'=' '{ print $1 }'`
                	PROP=`${BUSYBOX} grep "$*" /system/build.prop | ${BUSYBOX} awk -F'=' '{ print $NF }'`

        	fi

	fi

	if [ "$VAR" != "" ]; then
        	echo $PROP
	else
		echo "false"
	fi

}
DRSETPROP() {

        # We want to set this only if the XZDR.prop file exists...
        if [ ! -f "${DRPATH}/XZDR.prop" ]; then
                return 0
        fi

        PROP=$(DRGETPROP $1)

        if [ "$PROP" != "false" ]; then
                ${BUSYBOX} sed -i 's|'$1'=[^ ]*|'$1'='$2'|' ${DRPATH}/XZDR.prop
        else
                ${BUSYBOX} echo "$1=$2" >> ${DRPATH}/XZDR.prop
        fi
        return 0

}

echo ""
echo "##########################################################"
echo "#"
echo "# Installing XZDR version $(DRGETPROP version) $(DRGETPROP release)"
echo "#"
echo "#####"
echo ""

echo "Temporarily disabling the RIC service, remount rootfs and /system writable to allow installation."
if [ "$1" = "unrooted" ]; then
	/data/local/tmp/zxz.sh
fi
# Thanks to Androxyde for this method!
RICPATH=$(ps | ${BUSYBOX} grep "bin/ric" | ${BUSYBOX} awk '{ print $NF }')
if [ "$RICPATH" != "" ]; then
	${BUSYBOX} mount -o remount,rw / && mv ${RICPATH} ${RICPATH}c && ${BUSYBOX} pkill -f ${RICPATH}
fi
# Thanks to MohammadAG for this method
if [ -e "/data/local/tmp/wp_mod.ko" ]; then
        insmod /data/local/tmp/wp_mod.ko
fi
# Thanks to cubeandcube for this method
if [ -e "/data/local/tmp/writekmem" -a -e "/data/local/tmp/ricaddr" ]; then
        /data/local/tmp/writekmem `/data/local/tmp/recovery/busybox cat /data/local/tmp/ricaddr` 0
fi

sleep 2
${BUSYBOX} mount -o remount,rw /
${BUSYBOX} blockdev --setrw $(${BUSYBOX} find /dev/block/platform/msm_sdcc.1/by-name/ -iname "system")
${BUSYBOX} mount -o remount,rw /system

echo "Copy recovery files to system."
${BUSYBOX} cp /data/local/tmp/recovery/recovery.twrp.cpio.lzma /system/bin/
${BUSYBOX} cp /data/local/tmp/recovery/recovery.cwm.cpio.lzma /system/bin/
${BUSYBOX} cp /data/local/tmp/recovery/recovery.philz.cpio.lzma /system/bin/
${BUSYBOX} chmod 644 /system/bin/recovery.twrp.cpio.lzma
${BUSYBOX} chmod 644 /system/bin/recovery.cwm.cpio.lzma
${BUSYBOX} chmod 644 /system/bin/recovery.philz.cpio.lzma

if [ -f "/data/local/tmp/recovery/ramdisk.stock.cpio.lzma" ]; then
	${BUSYBOX} cp /data/local/tmp/recovery/ramdisk.stock.cpio.lzma /system/bin/
	${BUSYBOX} chmod 644 /system/bin/ramdisk.stock.cpio.lzma
fi

if [ ! -f "/system/bin/mr.stock" -a -f "/system/bin/mr" ]; then
	echo "Rename stock mr"
	${BUSYBOX} mv /system/bin/mr /system/bin/mr.stock
fi

if [ -f "/system/bin/mr.stock" -a ! -f "/system/bin/mr" ]; then
	echo "Copy mr wrapper script to system."
	${BUSYBOX} cp /data/local/tmp/recovery/mr /system/bin/
	${BUSYBOX} chmod 755 /system/bin/mr
fi

if [ ! -f "/system/bin/chargemon.stock" ]; then
	echo "Rename stock chargemon"
	${BUSYBOX} mv /system/bin/chargemon /system/bin/chargemon.stock
fi

echo "Copy chargemon script to system."
${BUSYBOX} cp /data/local/tmp/recovery/chargemon /system/bin/
${BUSYBOX} chmod 755 /system/bin/chargemon

echo "Copy dualrecovery.sh to system."
${BUSYBOX} cp /data/local/tmp/recovery/dualrecovery.sh /system/bin/
${BUSYBOX} chmod 755 /system/bin/dualrecovery.sh

echo "Copy rickiller.sh to system."
${BUSYBOX} cp /data/local/tmp/recovery/rickiller.sh /system/bin/
${BUSYBOX} chmod 755 /system/bin/rickiller.sh

echo "Installing NDRUtils to system."
${BUSYBOX} cp /data/local/tmp/recovery/NDRUtils.apk /system/app/
${BUSYBOX} chmod 644 /system/app/NDRUtils.apk

if [ "$(${BUSYBOX} grep '/sys/kernel/security/sony_ric/enable' init.* | ${BUSYBOX} wc -l)" = "1" ]; then
	echo "Copy disableric to system."
	${BUSYBOX} cp /data/local/tmp/recovery/disableric /system/xbin/
	${BUSYBOX} chmod 755 /system/xbin/disableric
fi

if [ -f "/system/etc/.xzdrbusybox" ]; then
	${BUSYBOX} rm -f /system/etc/.xzdrbusybox
fi

if [ ! -d "$SECUREDIR" ]; then
	echo "Creating $SECUREDIR to store a backup copy of busybox."
	mkdir $SECUREDIR
fi

echo "Copy busybox to system."
${BUSYBOX} cp /data/local/tmp/recovery/busybox /system/xbin/
${BUSYBOX} cp /data/local/tmp/recovery/busybox $SECUREDIR/
${BUSYBOX} chmod 755 /system/xbin/busybox
${BUSYBOX} chmod 755 $SECUREDIR/busybox

echo "Trying to find and update the gpio-keys event node."
GPIOINPUTDEV="$(gpioKeysSearch)"
echo "Found and will be using ${GPIOINPUTDEV}!"
DRSETPROP dr.gpiokeys.node ${GPIOINPUTDEV}

echo "Trying to find and update the power key event node."
PWRINPUTDEV="$(pwrkeySearch)"
echo "Found and will be monitoring ${PWRINPUTDEV}!"
DRSETPROP dr.pwrkey.node ${PWRINPUTDEV}

FOLDER1=/sdcard/clockworkmod/
FOLDER2=/sdcard1/clockworkmod/
FOLDER3=/cache/recovery/

echo "Speeding up backups."
if [ ! -e "$FOLDER1" ]; then
	${BUSYBOX} mkdir /sdcard/clockworkmod/
	${BUSYBOX} touch /sdcard/clockworkmod/.hidenandroidprogress
else
	${BUSYBOX} touch /sdcard/clockworkmod/.hidenandroidprogress
fi

if [ ! -e "$FOLDER2" ]; then
	${BUSYBOX} mkdir /sdcard1/clockworkmod/
	${BUSYBOX} touch /sdcard1/clockworkmod/.hidenandroidprogress
else
	${BUSYBOX} touch /sdcard1/clockworkmod/.hidenandroidprogress
fi

echo "Make sure firstboot goes to recovery."
if [ -e "$FOLDER3" ];
then
	${BUSYBOX} touch /cache/recovery/boot
else
	${BUSYBOX} mkdir /cache/recovery/
	${BUSYBOX} touch /cache/recovery/boot
fi

DRSETPROP dr.xzdr.version $(DRGETPROP version)
DRSETPROP dr.release.type $(DRGETPROP release)

echo ""
echo "============================================="
echo "DEVICE WILL NOW TRY A DATA SAFE REBOOT!"
echo "============================================="
echo ""

/system/bin/am start -a android.intent.action.REBOOT 2>&1 > /dev/null
if [ "$?" != "0" ]; then

	echo ""
	echo "============================================="
	echo "If you want the installer to clean up after itself,"
	echo "reboot to system after entering recovery for the first time!"
	echo "============================================="
	echo ""

	reboot

else

	echo ""
	echo "============================================="
	echo "Your installation has already cleaned up after"
	echo "itself if you see the install.bat/install.sh exit."
	echo "============================================="
	echo ""

fi
