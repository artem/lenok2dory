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

cd `dirname "$0"`

echo
echo "***** Extracting images... *****"
echo
mkdir -p extract/dory/ extract/lenok/
sudo unsquashfs -f -d ./extract/lenok/ ./images/lenok/system.img
sudo unsquashfs -f -d ./extract/dory/ ./images/dory/system.img



echo
echo "***** Cleaning lenok's system... *****"
echo
cd ./extract/lenok/bin/
sudo rm install-recovery.sh irsc_util sensors.qcom subsystem_ramdump wpa_supplicant ../recovery-from-boot.p

cd ../etc/
sudo rm -rf dhcpcd/dhcpcd.conf firmware/ permissions/android.hardware.sensor.barometer.xml permissions/android.hardware.sensor.heartrate.xml \
permissions/android.hardware.wifi.xml recovery-resource.dat sensors/sensor_def_lenok.conf wifi/

cd ../lib/
sudo rm libwpa_client.so hw/*lenok.so

cd ../vendor/lib/
sudo rm -rf ../firmware hw/ libAKM8963.so libdiag.so libdsutils.so libidl.so libmdmdetect.so libq3d.so libqmi_cci.so libqmi_client_qmux.so \
libqmi_common_so.so libqmi_csi.so libqmi_encdec.so libqmiservices.so libsensor1.so libsensor_reg.so libsensor_user_cal.so libxg.so

cd ../../../../






echo
echo "***** Patching lenok's system... *****"
echo
apktool d -f -o ./extract/lenok-framework-res/ ./extract/lenok/framework/framework-res.apk
apktool d -f -r -o ./extract/lenok-OEMSetup/ ./extract/lenok/priv-app/OEMSetup/OEMSetup.apk
apktool d -f -o ./extract/lenok-services/ ./extract/lenok/framework/services.jar

sudo patch -p0 -l < ./patch/dory.patch
# Disable checking certs for shared system apps
# framework-res.apk is app with shared user id, so system checks it anyway. Let's avoid this
patch -p0 -l < ./patch/shared-certs.patch
sudo sed -i "/\b\(ro.build.expect.bootloader\|ro.expect.recovery_id\)\b/d" ./extract/lenok/build.prop
cp ./patch/product_image.png ./extract/lenok-OEMSetup/res/drawable-hdpi/

apktool b -c ./extract/lenok-OEMSetup/
cd ./extract/lenok-OEMSetup/dist/
zipalign -fpt 4 ./OEMSetup.apk ./OEMSetup-aligned.apk
mv ./OEMSetup-aligned.apk ./OEMSetup.apk
cd ../../../
sudo sh -c "(cat ./extract/lenok-OEMSetup/dist/OEMSetup.apk > ./extract/lenok/priv-app/OEMSetup/OEMSetup.apk)"

apktool b -c ./extract/lenok-framework-res/
cd ./extract/lenok-framework-res/dist/
zipalign -fpt 4 ./framework-res.apk ./framework-res-aligned.apk
mv ./framework-res-aligned.apk ./framework-res.apk
cd ../../../
sudo sh -c "(cat ./extract/lenok-framework-res/dist/framework-res.apk > ./extract/lenok/framework/framework-res.apk)"

apktool b -c ./extract/lenok-services/
cd ./extract/lenok-services/dist/
zipalign -fpt 4 ./services.jar ./services-aligned.jar
mv ./services-aligned.jar ./services.jar
cd ../../../
sudo sh -c "(cat ./extract/lenok-services/dist/services.jar > ./extract/lenok/framework/services.jar)"

cd ./extract/
rm -rf ./lenok-*/
# Remove useless patch'es backup file (it thinks that somethink can go wrong)
sudo rm ./lenok/build.prop.orig

sudo cp -a ./dory/bin/batteryd ./lenok/bin/
sudo cp -a ./dory/etc/audioservice.conf ./lenok/etc/
sudo cp -a ./dory/etc/regulatory_info.png ./lenok/etc/
sudo cp -ar ./dory/etc/sensors/ ./lenok/etc/
# WARNING!!! FIX ME!!!
sudo cp -a ./dory/lib/libhardware_legacy.so ./lenok/lib/
#
sudo cp -a ./dory/lib/libinvensense_hal.so ./lenok/lib/
sudo cp -a ./dory/lib/libmllite.so ./lenok/lib/
sudo cp -a ./dory/lib/libmplmpu.so ./lenok/lib/
sudo cp -a ./dory/lib/hw/audio.primary.dory.so ./lenok/lib/hw/
sudo cp -a ./dory/lib/hw/lights.dory.so ./lenok/lib/hw/
sudo cp -a ./dory/lib/hw/lis3dsh_tilt.so ./lenok/lib/hw/
sudo cp -a ./dory/lib/hw/power.dory.so ./lenok/lib/hw/
sudo cp -a ./dory/lib/hw/sensors.dory.so ./lenok/lib/hw/
sudo cp -a ./dory/lib/hw/sensors.invensense.so ./lenok/lib/hw/
sudo cp -a ./dory/media/bootanimation.zip ./lenok/media/
sudo cp -ar ./dory/vendor/firmware/ ./lenok/vendor/
cd ../






echo
echo "***** Making system image... *****"
echo
# You can grab file_contexts from boot image for now (as I've done)
sudo ./prebuilt/mksquashfs ./extract/lenok/ system4dory.img -comp gzip -b 131072 -no-exports -noappend -android-fs-config \
-context-file file_contexts -mount-point /system
sudo chmod 777 system4dory.img

echo
echo "***** Done! *****"
