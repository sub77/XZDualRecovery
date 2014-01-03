#!/sbin/sh

DRPATH="/external_sd/XZDualRecovery"

if [ !-d "/external_sd/XZDualRecovery" ]; then
	DRPATH="/storage/sdcard1/XZDualRecovery"
fi

if [ !-d "/storage/sdcard1/XZDualRecovery" ]; then
	DRPATH="/cache/XZDualRecovery"
fi

DRGETPROP() {

	# If it's empty, see if what was requested was a XZDR.prop value!
        PROP=`grep "$*" ${DRPATH}/XZDR.prop | awk -F'=' '{ print $NF }'`

        if [ "$PROP" = "" ]; then

                # If it still is empty, try to get it from the build.prop
                PROP=`grep "$*" /system/build.prop | awk -F'=' '{ print $NF }'`

        fi

        echo $PROP

}

DRSETPROP() {

	# We want to set this only if the XZDR.prop file exists...
	if [ ! -f "${DRPATH}/XZDR.prop" ]; then
		return 0
	fi

	PROP=$(DRGETPROP $1)

	if [ "$PROP" != "" ]; then
		sed -i -e '/$1=/ s/=$PROP/=$2/' ${DRPATH}/XZDR.prop
	else
		echo "$1=$2" >> ${DRPATH}/XZDR.prop
	fi
	return 0

}

ROMVER=$(DRGETPROP ro.build.id)

if [ "$ROMVER" = "10.4.B.0.569" -o "$ROMVER" = "14.2.A.0.290" ]; then

	cp /tmp/ramdisk.stock.cpio.lzma /system/bin/
	chmod 644 /system/bin/ramdisk.stock.cpio.lzma
	DRSETPROP dr.ramdisk.location /system/bin/ramdisk.stock.cpio.lzma

fi

if [ -f "/system/bin/ramdisk.stock.cpio.lzma" -a "$(DRGETPROP dr.insecure.ramdisk)" = "" ]; then

	echo "  ** Installed custom ramdisk! **"
	# This, once a working ramdisk has been produced, will be turned to true in the future
	DRSETPROP dr.insecure.ramdisk false

fi

exit 0
