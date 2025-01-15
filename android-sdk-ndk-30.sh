#!/bin/sh
set -o errexit # exit on any command failure

INSTALL_EMULATOR=0
INSTALL_JAVA=1

# 3 means only error messages
# 2 means error and info messages
# 1 means error and info and warning messages
# 0 means error and info and warning and debug messages
LOGLEVEL=2

################################################################
### DEPENDENCY CHECK
################################################################

# have <program> returns 1 or 0
have() {
  which $1 >/dev/null 2>&1 && echo 1 || echo 0
}

# log(loglevel, msg)
log() {
  msg_loglevel="$1"
  msg="$2"
  if [ $msg_loglevel -lt $LOGLEVEL ]; then
    return
  fi
  echo "$msg"
}
# error:3 info:2 warning:1 debug:0
error()   { log 3 "$1"; }
info()    { log 2 "$1"; }
warning() { log 1 "$1"; }
debug()   { log 0 "$1"; }

HAVE_CURL=$(have curl)
debug "HAVE_CURL: $HAVE_CURL"
HAVE_WGET=$(have wget)
debug "HAVE_WGET: $HAVE_WGET"

HAVE_UNZIP=$(have unzip)
debug "HAVE_UNZIP: $HAVE_UNZIP"
HAVE_TAR=$(have tar)
debug "HAVE_TAR: $HAVE_TAR"

HAVE_B3SUM=$(have b3sum)
debug "HAVE_B3SUM: $HAVE_B3SUM"
HAVE_B2SUM=$(have b2sum)
debug "HAVE_B2SUM: $HAVE_B2SUM"
HAVE_SHA256SUM=$(have sha256sum)
debug "HAVE_SHA256SUM: $HAVE_SHA256SUM"

HAVE_JAVA=$(have java)
debug "HAVE_JAVA: $HAVE_JAVA"

fail=0

# atleast one of them required, SHOWSTOPPER
if [ $HAVE_CURL -eq 0 -a $HAVE_WGET -eq 0 ]; then
  error 'curl or wget required'
  fail=1
fi
# atleast one of them required, SHOWSTOPPER
if [ $HAVE_UNZIP -eq 0 -a $HAVE_TAR -eq 0 ]; then
  error 'unzip or tar required'
  fail=1
fi

if [ $fail -ne 0 ]; then
  exit 1
fi

################################################################
### functions
################################################################
#fail(msg)
fail() { error "$1"; exit 1; }

download_with_wget() { wget -O "$1" "$2"; }
download_with_curl() { curl -Lo "$1" "$2"; }
# download(path, url)
download() {
  path="$1"
  url="$2"

  # assert
  if [ $HAVE_CURL -eq 0 -a $HAVE_WGET -eq 0 ]; then
    fail 'this looks like a bug, @download'
  fi

  if [ $HAVE_CURL -ne 0 ]; then
    download_with_curl "$path" "$url"
    debug '@download download_with_curl'
  elif [ $HAVE_WGET -ne 0 ]; then
    download_with_wget "$path" "$url"
    debug '@download download_with_wget'
  fi
}

extract_with_unzip() { unzip -q "$1"; }
extract_with_tar() { tar xf "$1"; }
# extract(filetype:[zip, tar], path)
extract() {
  filetype="$1"
  path="$2"
  is_zip=$(test "$filetype == zip" && echo 1 || echo 0)

  # assert
  if [ $HAVE_TAR -eq 0 -a $HAVE_UNZIP -eq 0 ]; then
    fail "this looks like a bug, @extract"
  fi

  if [ $is_zip -ne 0 ]; then
    if [ $HAVE_UNZIP -ne 0 ]; then
      extract_with_unzip "$path"
      debug '@extract(zip) extract_with_unzip'
    elif [ $HAVE_TAR -ne 0 ]; then
      extract_with_tar "$path"
      debug '@extract(zip) extract_with_tar'
    fi
  else
    if [ $HAVE_TAR -eq 0 ]; then
      fail "this looks like a bug, @extract(tar)"
    fi

    extract_with_tar "$path"
    debug '@extract(tar) extract_with_tar'
  fi
}

verify_with_b3sum() { echo "$1" | b3sum -c >/dev/null 2>&1 && return 0 || return 1; }
verify_with_b2sum() { echo "$1" | b2sum -c >/dev/null 2>&1 && return 0 || return 1; }
verify_with_sha256sum() { echo "$1" | sha256sum -c >/dev/null 2>&1 && return 0 || return 1; }
# verify(b3, b2, sha256)
verify() {
  if [ $HAVE_B3SUM -ne 0 ]; then
    return $(verify_with_b3sum "$1")
  elif [ $HAVE_B2SUM -ne 0 ]; then
    return $(verify_with_b2sum "$2")
  elif [ $HAVE_SHA256SUM -ne 0 ]; then
    return $(verify_with_sha256sum "$3")
  fi

  warning 'cannot verify files because of not installed programs'
  return 1
}

# package    | linux      | windows      | mac
# --------------------------------------------------------------------
# ndk/btools | linux      | windows      | darwin
# emulator   | linux_x64  | windows_x64  | darwin_x64 / darwin_aarch64

ANDROID_HOME=${ANDROID_HOME:-/tmp/android}

################################################################
# platform
################################################################

HASH_B3='49f774a52f72f1021a894e646be8bafa36ef77a8e08604f91c89e28b76812368  platform-30_r03.zip'
HASH_B2='c56da775bb507e0967902895f3c54bee27ef6bec5cf4a709a1874228b1843ac12ec2e57681d39b01da811a9a009e444b77fa3f675c043b6c9788420fdfc23640  platform-30_r03.zip'
HASH_SHA256='f3f5b75744dbf6ee6ed3e8174a71e513bfee502d0bc3463ea97e517bff68d84e  platform-30_r03.zip'

test -f platform-30_r03.zip || download platform-30_r03.zip https://dl.google.com/android/repository/platform-30_r03.zip
verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
extract zip platform-30_r03.zip
mkdir -p $ANDROID_HOME/platforms
mv android-11 $ANDROID_HOME/platforms/android-30
info 'installed platform android-30'

################################################################
# ndk
# dependencies: patcher:v4
################################################################

HASH_B3='e19388afb36c5820f558b297637922a447602fc2939cfdf24b589cfaae2a2a8e  3534162-studio.sdk-patcher.zip'
HASH_B2='859cf58d74b764ff5aba16f8229eb36df2c76a8e0c23c0cfa8a7a481640382ed6333493a57bbb9ca23d22f4747e6a9c0c2aee43e1e147186824bddf712577b5e  3534162-studio.sdk-patcher.zip'
HASH_SHA256='18f9b8f27ea656e06b05d8f14d881df8e19803c9221c0be3e801632bcef18bed  3534162-studio.sdk-patcher.zip'

test -f 3534162-studio.sdk-patcher.zip || download 3534162-studio.sdk-patcher.zip https://dl.google.com/android/repository/3534162-studio.sdk-patcher.zip
verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
extract zip 3534162-studio.sdk-patcher.zip
mkdir -p $ANDROID_HOME/patcher
mv sdk-patcher $ANDROID_HOME/patcher/v4

HASH_B3='cc234ddf4ee41a12697f4836a78b58fe780e98bdcd5ecdc97b682db29e7fdbd5  android-ndk-r25b-linux.zip'
HASH_B2='08da0fffe3eeb709a93f31af2b4ddc706137fc26dabdaae62e221b8a77295e2ff6918883b5b5b70f3b13ef0bd1d75ca170c009dfcf48f22006f3160d226c87c4  android-ndk-r25b-linux.zip'
HASH_SHA256='403ac3e3020dd0db63a848dcaba6ceb2603bf64de90949d5c4361f848e44b005  android-ndk-r25b-linux.zip'

test -f android-ndk-r25b-linux.zip || download android-ndk-r25b-linux.zip https://dl.google.com/android/repository/android-ndk-r25b-linux.zip
verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
extract zip android-ndk-r25b-linux.zip
mkdir -p $ANDROID_HOME/ndk
mv android-ndk-r25b $ANDROID_HOME/ndk/25.1.8937393
echo 'installed ndk 25.1.8937393'

################################################################
# build tools
# dependencies: patcher:v4
################################################################

HASH_B3='131b894aae44b7097e1eaeeead15279fdbfca0a428ca032a8693ac0f19211583  build-tools_r30-linux.zip'
HASH_B2='e1c939df216b6e976cdaed51a635d40fc502a44713f3a26b74b9e1363b04269cbc39fd4f9be0d8ff99d0b046f94e83b156fdf3453d0a9274ef9f2a3e520a4e7c  build-tools_r30-linux.zip'
HASH_SHA256='ed3b7f9b2d15e90a12c2e739adb749d7d834e2f953e677380206bd14db135c6c  build-tools_r30-linux.zip'

test -f build-tools_r30-linux.zip || download build-tools_r30-linux.zip https://dl.google.com/android/repository/build-tools_r30-linux.zip
verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
extract zip build-tools_r30-linux.zip
mkdir -p $ANDROID_HOME/build-tools
mv android-11 $ANDROID_HOME/build-tools/30.0.0
echo 'installed build-tools 30.0.0'

################################################################
# emulator
################################################################

if [ $INSTALL_EMULATOR -ne 0 ]; then

  HASH_B3='92f824312e472578f687bb2e777b1c9e8d7b76d2b545e4a050f841f42f47bdcc  emulator-linux_x64-9189900.zip'
  HASH_B2='f51520ea8d36e1e67ada40fb08c932635a9c450545cbea7d3d4aa2f934a34e74729beae8370afc58613c67f7b0ed60605659aab96fc7e5fce95803406627fc1c  emulator-linux_x64-9189900.zip'
  HASH_SHA256='5d18602e9a4e39eb88d01a243fe0df061dcec945042e385dafa4de4a848d29ce  emulator-linux_x64-9189900.zip'

  test -f emulator-linux_x64-9189900.zip || download emulator-linux_x64-9189900.zip https://dl.google.com/android/repository/emulator-linux_x64-9189900.zip
  verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
  extract zip emulator-linux_x64-9189900.zip
  mv emulator $ANDROID_HOME/emulator 
  info 'installed emulator'

fi

################################################################
# java
################################################################

if [ $INSTALL_JAVA -ne 0 ]; then

  # see https://whichjdk.com/
  # Adoptium Eclipse Temurin 21

  HASH_B3='94b232b1702e07d5061f217595445ef6c1c1bc26830e8c2f8db165e741589d5c  OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz'
  HASH_B2='ed139c216a82ed9c258bc3b48fccee184f8facd4f53f607ed6db79b7fe01193a41d3097bece31b5bf53c6964c96ac5e4f473f27fbb57a3e24b58149f3bd3db3c  OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz'
  HASH_SHA256='3c654d98404c073b8a7e66bffb27f4ae3e7ede47d13284c132d40a83144bfd8c  OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz'

  test -f OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz || download OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz'
  verify "$HASH_B3" "$HASH_B2" "$HASH_SHA256" || (fail 'file corrupt')
  extract tar OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz
  mv jdk-21.0.5+11 $ANDROID_HOME/jdk-21.0.5+11
  ln -sf $ANDROID_HOME/jdk-21.0.5+11 $ANDROID_HOME/jdk
  export PATH="$ANDROID_HOME/jdk/bin:$PATH"
  export JAVA_HOME="$ANDROID_HOME/jdk"
  info 'installed jdk'

fi

################################################################
# POST INSTALL
################################################################
info 'to make environment persist, add this to your shellrc'
info "  export ANDROID_HOME='$ANDROID_HOME'"
if [ $INSTALL_JAVA -ne 0 ]; then
  info "  export JAVA_HOME=\"\$ANDROID_HOME/jdk\""
  info "  export PATH=\"\$ANDROID_HOME/jdk/bin:\$PATH\""
fi

