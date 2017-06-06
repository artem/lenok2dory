#!/bin/sh

clear
echo "***** lenok2dory patcher started! *****"
echo
echo "***** You maybe will be asked for root permissions *****"
echo
if [ "`sudo whoami`" != "root" ]
  then echo "***** You aren't root! *****"
  exit 1
fi

export BUILD_DIR=`pwd`
# export PATH=$BUILD_DIR/prebuilt:$PATH


echo
echo "***** Cleaning up... *****"
echo
sudo rm -rf extract/ temp/

echo
echo "***** Extracting images... *****"
echo
mkdir -p extract/dory/ extract/lenok/
sudo unsquashfs -f -d extract/lenok/ images/lenok/system.img
sudo unsquashfs -f -d extract/dory/ images/dory/system.img


echo
echo "***** Cleaning lenok's system... *****"
echo
cd extract/lenok/bin/
sudo rm install-recovery.sh irsc_util sensors.qcom subsystem_ramdump wpa_supplicant ../recovery-from-boot.p

cd ../etc/
sudo rm -rf firmware/ permissions/android.hardware.sensor.barometer.xml permissions/android.hardware.sensor.heartrate.xml \
permissions/android.hardware.wifi.xml recovery-resource.dat sensors/sensor_def_lenok.conf wifi/

cd ../lib/
sudo rm hw/*lenok.so #libwpa_client.so FIXME

cd ../vendor/lib/
sudo rm -rf ../firmware hw/ libAKM8963.so libdiag.so libdsutils.so libidl.so libmdmdetect.so libqmi* libsensor1.so \
libsensor_reg.so libsensor_user_cal.so

cd $BUILD_DIR


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
sudo patch -p0 -l -i patch/dory.patch
# Disable checking certs for shared system apps
# Because framework-res.apk is app with shared user id, system checks its signature anyway. Let's avoid this behavior
patch -p0 -l < patch/shared-certs.patch
sudo sed -i "/\b\(ro.build.expect.bootloader\|ro.expect.recovery_id\)\b/d" extract/lenok/build.prop
cp patch/product_image.png temp/lenok-OEMSetup/res/drawable-hdpi-v4/

apktool b -c -p temp/framedir/ temp/lenok-SettingsProvider/
cd temp/lenok-SettingsProvider/dist/
zipalign -fpt 4 SettingsProvider.apk SettingsProvider-aligned.apk
mv SettingsProvider-aligned.apk SettingsProvider.apk
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-SettingsProvider/dist/SettingsProvider.apk > extract/lenok/priv-app/SettingsProvider/SettingsProvider.apk)"

apktool b -c -p temp/framedir/ temp/lenok-ClockworkAmbient/
cd temp/lenok-ClockworkAmbient/dist/
zipalign -fpt 4 ClockworkAmbient.apk ClockworkAmbient-aligned.apk
mv ClockworkAmbient-aligned.apk ClockworkAmbient.apk
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-ClockworkAmbient/dist/ClockworkAmbient.apk > extract/lenok/priv-app/ClockworkAmbient/ClockworkAmbient.apk)"

apktool b -c -p temp/framedir/ temp/lenok-ClockworkSettings/
cd temp/lenok-ClockworkSettings/dist/
zipalign -fpt 4 ClockworkSettings.apk ClockworkSettings-aligned.apk
mv ClockworkSettings-aligned.apk ClockworkSettings.apk
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-ClockworkSettings/dist/ClockworkSettings.apk > extract/lenok/priv-app/ClockworkSettings/ClockworkSettings.apk)"

apktool b -c temp/lenok-OEMSetup/
cd temp/lenok-OEMSetup/dist/
zipalign -fpt 4 OEMSetup.apk OEMSetup-aligned.apk
mv OEMSetup-aligned.apk OEMSetup.apk
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-OEMSetup/dist/OEMSetup.apk > extract/lenok/priv-app/OEMSetup/OEMSetup.apk)"

apktool b -c temp/lenok-framework-res/
cd temp/lenok-framework-res/dist/
zipalign -fpt 4 framework-res.apk framework-res-aligned.apk
mv framework-res-aligned.apk framework-res.apk
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-framework-res/dist/framework-res.apk > extract/lenok/framework/framework-res.apk)"

apktool b -c temp/lenok-services/
cd temp/lenok-services/dist/
zipalign -fpt 4 services.jar services-aligned.jar
mv services-aligned.jar services.jar
cd $BUILD_DIR
sudo sh -c "(cat temp/lenok-services/dist/services.jar > extract/lenok/framework/services.jar)"

cd extract/
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
sudo cp -a dory/media/bootanimation.zip lenok/media/
sudo cp -ar dory/vendor/firmware/ lenok/vendor/
cd $BUILD_DIR


echo
echo "***** Making system image... *****"
echo
# sudo env "PATH=$PATH" mksquashfsimage.sh extract/lenok system4dory.img -s -m /system -c file_contexts
sudo prebuilt/mksquashfs extract/lenok/ system4dory.img -comp gzip -b 131072 -no-exports -noappend -android-fs-config \
-context-file file_contexts -mount-point /system
sudo chmod 777 system4dory.img

echo
echo "***** Done! *****"
