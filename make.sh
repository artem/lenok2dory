#!/usr/bin/env bash

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

build_priv-apk () {
    apktool -q b -c -p temp/framedir/ temp/lenok-$1/
	pushd temp/lenok-$1/dist/
	zipalign -fp 4 $1.apk $1-aligned.apk
	mv $1-aligned.apk $1.apk
	popd
	sudo cp temp/lenok-$1/dist/$1.apk extract/lenok/priv-app/$1/$1.apk
	sudo chown root:root extract/lenok/priv-app/$1/$1.apk
}


echo "***** lenok2dory patcher started! *****"
echo
echo "***** You maybe will be asked for root permissions *****"
echo
if [ "`sudo whoami`" != "root" ]
  then echo "***** You aren't root! *****"
  exit 1
fi

pushd `pwd`
# export PATH=$BUILD_DIR/prebuilt:$PATH


echo
echo "***** Cleaning up... *****"
echo
sudo rm -rf temp/

echo
echo "***** Extracting images... *****"
echo
mkdir -p extract/dory/ extract/lenok/
mkdir -p mnt/dory/ mnt/lenok/
sudo mount images/lenok/system.img mnt/lenok/
sudo mount images/dory/system.img mnt/dory/
sudo rsync -a mnt/lenok/ extract/lenok/
sudo rsync -a mnt/dory/ extract/dory/
sudo umount mnt/lenok/
sudo umount mnt/dory/
rm -rf mnt


echo
echo "***** Cleaning lenok's system... *****"
echo

pushd extract/lenok/
sudo rm recovery-from-boot.p

pushd bin/
sudo rm install-recovery.sh irsc_util sensors.qcom subsystem_ramdump wpa_supplicant
popd

pushd etc/
sudo rm -rf firmware/ recovery-resource.dat sensors/sensor_def_lenok.conf wifi/
pushd permissions/
sudo rm -rf android.hardware.sensor.barometer.xml android.hardware.sensor.heartrate.xml android.hardware.wifi.xml
popd
popd

pushd lib/
sudo rm hw/*lenok.so #libwpa_client.so FIXME
popd

pushd vendor/lib/
sudo rm -rf ../firmware hw/ libAKM8963.so libdiag.so libdsutils.so libidl.so libmdmdetect.so libqmi* libsensor1.so \
libsensor_reg.so libsensor_user_cal.so
popd

popd


echo
echo "***** Decompiling lenok's resources, please wait... *****"
echo
apktool -q if -p temp/framedir/ extract/lenok/framework/framework-res.apk
apktool -q d -f -o temp/lenok-framework-res/ extract/lenok/framework/framework-res.apk
apktool -q d -f -o temp/lenok-services/ extract/lenok/framework/services.jar
apktool -q d -f -p temp/framedir/ -o temp/lenok-OEMSetup/ extract/lenok/priv-app/OEMSetup/OEMSetup.apk
apktool -q d -s -f -p temp/framedir/ -o temp/lenok-SettingsProvider/ extract/lenok/priv-app/SettingsProvider/SettingsProvider.apk
apktool -q d -s -f -p temp/framedir/ -o temp/lenok-ClockworkAmbient/ extract/lenok/priv-app/ClockworkAmbient/ClockworkAmbient.apk
apktool -q d -s -f -p temp/framedir/ -o temp/lenok-ClockworkSettings/ extract/lenok/priv-app/ClockworkSettings/ClockworkSettings.apk

echo
echo "***** Patching lenok's system... *****"
echo

sudo cp patch/media/bootanimation.zip lenok/media/
sudo chown root:root lenok/media/bootanimation.zip

sudo patch -p0 -l -i patch/dory.patch
# Disable checking certs for shared system apps
# Because framework-res.apk is app with shared user id, system checks its signature anyway. Let's avoid this behavior
patch -p0 -l < patch/shared-certs.patch
sudo sed -i "/\b\(ro.build.expect.bootloader\|ro.expect.recovery_id\)\b/d" extract/lenok/build.prop
cp patch/product_image.png temp/lenok-OEMSetup/res/drawable-hdpi-v4/

build_priv-apk SettingsProvider
build_priv-apk ClockworkAmbient
build_priv-apk ClockworkSettings
build_priv-apk OEMSetup

apktool -q b -c temp/lenok-framework-res/
pushd temp/lenok-framework-res/dist/
zipalign -fp 4 framework-res.apk framework-res-aligned.apk
mv framework-res-aligned.apk framework-res.apk
popd
sudo cp temp/lenok-framework-res/dist/framework-res.apk extract/lenok/framework/framework-res.apk
sudo chown root:root extract/lenok/framework/framework-res.apk

apktool -q b -c temp/lenok-services/
pushd temp/lenok-services/dist/
zipalign -fp 4 services.jar services-aligned.jar
mv services-aligned.jar services.jar
popd
sudo cp temp/lenok-services/dist/services.jar extract/lenok/framework/services.jar
sudo chown root:root extract/lenok/framework/services.jar

pushd extract/
sudo rm lenok/build.prop.orig

sudo cp -a dory/bin/batteryd lenok/bin/
sudo cp -a dory/etc/audioservice.conf lenok/etc/
sudo cp -a dory/etc/regulatory_info.png lenok/etc/
sudo cp -ar dory/etc/sensors/ lenok/etc/
# sudo cp -a dory/lib/libhardware_legacy.so lenok/lib/
# ^^^ WARNING!!! FIX ME!!! ^^^
sudo cp -a dory/lib/libinvensense_hal.so lenok/lib/
sudo cp -a dory/lib/libmllite.so lenok/lib/
sudo cp -a dory/lib/libmplmpu.so lenok/lib/
sudo cp -a dory/lib/hw/audio.primary.dory.so lenok/lib/hw/
sudo cp -a dory/lib/hw/lights.dory.so lenok/lib/hw/
sudo cp -a dory/lib/hw/lis3dsh_tilt.so lenok/lib/hw/
sudo cp -a dory/lib/hw/power.dory.so lenok/lib/hw/
sudo cp -a dory/lib/hw/sensors.dory.so lenok/lib/hw/
sudo cp -a dory/lib/hw/sensors.invensense.so lenok/lib/hw/
# sudo cp -a dory/media/bootanimation.zip lenok/media/
sudo cp -ar dory/vendor/firmware/ lenok/vendor/
popd


echo
echo "***** Making system image... *****"
echo
# sudo env "PATH=$PATH" mksquashfsimage.sh extract/lenok system4dory.img -s -m /system -c file_contexts
sudo prebuilt/mksquashfs extract/lenok/ system4dory.img -comp lz4 -b 131072 -no-exports -noappend -no-fragments -no-duplicates \
-android-fs-config -context-file file_contexts -mount-point /system
sudo chmod 777 system4dory.img

popd

echo
echo "***** Done! *****"
