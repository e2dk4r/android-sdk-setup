which wget >/dev/null || (echo wget not installed && exit 1)
which unzip >/dev/null || (echo unzip not installed && exit 1)
which sha256sum >/dev/null || (echo sha256sum not installed && exit 1)

# package    | linux      | windows      | mac
# --------------------------------------------------------------------
# ndk/btools | linux      | windows      | darwin
# emulator   | linux_x64  | windows_x64  | darwin_x64 / darwin_aarch64

ANDROID_HOME=/tmp/android

################################################################
# platform
################################################################
test -f platform-30_r03.zip || wget -q -o platform-30_r03.zip https://dl.google.com/android/repository/platform-30_r03.zip
echo 'f3f5b75744dbf6ee6ed3e8174a71e513bfee502d0bc3463ea97e517bff68d84e  platform-30_r03.zip' | sha256sum -c
unzip -q platform-30_r03.zip
mkdir -p $ANDROID_HOME/platforms
mv android-11 $ANDROID_HOME/platforms/android-30
echo 'installed platform android-30'

################################################################
# ndk
# dependencies: patcher:v4
################################################################
test -f 3534162-studio.sdk-patcher.zip || wget -q -o 3534162-studio.sdk-patcher.zip https://dl.google.com/android/repository/3534162-studio.sdk-patcher.zip
echo '18f9b8f27ea656e06b05d8f14d881df8e19803c9221c0be3e801632bcef18bed  3534162-studio.sdk-patcher.zip' | sha256sum -c
unzip -q 3534162-studio.sdk-patcher.zip
mkdir -p $ANDROID_HOME/patcher
mv sdk-patcher $ANDROID_HOME/patcher/v4

test -f android-ndk-r25b-linux.zip || wget -q -o android-ndk-r25b-linux.zip https://dl.google.com/android/repository/android-ndk-r25b-linux.zip
echo '403ac3e3020dd0db63a848dcaba6ceb2603bf64de90949d5c4361f848e44b005  android-ndk-r25b-linux.zip' | sha256sum -c
unzip -q android-ndk-r25b-linux.zip
mkdir -p $ANDROID_HOME/ndk
mv android-ndk-r25b $ANDROID_HOME/ndk/25.1.8937393
echo 'installed ndk 25.1.8937393'

################################################################
# build tools
# dependencies: patcher:v4
################################################################
test -f build-tools_r30-linux.zip || wget -q -o build-tools_r30-linux.zip https://dl.google.com/android/repository/build-tools_r30-linux.zip
echo 'ed3b7f9b2d15e90a12c2e739adb749d7d834e2f953e677380206bd14db135c6c  build-tools_r30-linux.zip' | sha256sum -c
unzip -q build-tools_r30-linux.zip
mkdir -p $ANDROID_HOME/build-tools
mv android-11 $ANDROID_HOME/build-tools/30.0.0
echo 'installed build-tools 30.0.0'

################################################################
# emulator
# optional
################################################################
#test -f emulator-linux_x64-9189900.zip || wget -q -o emulator-linux_x64-9189900.zip https://dl.google.com/android/repository/emulator-linux_x64-9189900.zip
#echo '5d18602e9a4e39eb88d01a243fe0df061dcec945042e385dafa4de4a848d29ce  emulator-linux_x64-9189900.zip' | sha256sum -c
#unzip -q emulator-linux_x64-9189900.zip
#mv $ANDROID_HOME/emulator 
#echo 'installed emulator'

################################################################
# POST INSTALL
################################################################
echo 'NOTE: do not forget to add ANDROID_HOME=/tmp/android to your environment'
which java >/dev/null || echo 'NOTE: java not installed. you probably need jdk'
