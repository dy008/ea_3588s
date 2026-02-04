#!/bin/bash

set -euxo pipefail

#==================================================================#
#                        init build env                            #
#==================================================================#
WORKDIR=$(pwd)
OUTPUT_DIR="${WORKDIR}/output"
mkdir -p "${OUTPUT_DIR}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates
apt-get install -y --no-install-recommends \
  acl aptly aria2 axel bc binfmt-support binutils-aarch64-linux-gnu bison bsdextrautils \
  btrfs-progs build-essential busybox ca-certificates ccache clang coreutils cpio \
  crossbuild-essential-arm64 cryptsetup curl debian-archive-keyring debian-keyring debootstrap \
  device-tree-compiler dialog dirmngr distcc dosfstools dwarves e2fsprogs expect f2fs-tools fakeroot \
  fdisk file flex gawk gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi gdisk git gnupg gzip htop \
  imagemagick jq kmod lib32ncurses-dev lib32stdc++6 libbison-dev libc6-dev-armhf-cross libc6-i386 \
  libcrypto++-dev libelf-dev libfdt-dev libfile-fcntllock-perl libfl-dev libfuse-dev \
  libgcc-12-dev-arm64-cross libgmp3-dev liblz4-tool libmpc-dev libncurses-dev libncurses5 \
  libncurses5-dev libncursesw5-dev libpython2.7-dev libpython3-dev libssl-dev libusb-1.0-0-dev \
  linux-base lld llvm locales lsb-release lz4 lzma lzop make mtools ncurses-base ncurses-term \
  nfs-kernel-server ntpdate openssl p7zip p7zip-full parallel parted patch patchutils pbzip2 pigz \
  pixz pkg-config pv python2 python2-dev python3 python3-dev python3-distutils python3-pip \
  python3-setuptools python-is-python3 qemu-user-static rar rdfind rename rsync sed squashfs-tools \
  swig tar tree u-boot-tools udev unzip util-linux uuid uuid-dev uuid-runtime vim wget whiptail \
  xfsprogs xsltproc xxd xz-utils zip zlib1g-dev zstd binwalk ripgrep
localedef -i zh_CN -f UTF-8 zh_CN.UTF-8 || true

#==================================================================#
#                        build uboot                               #
#==================================================================#
cd ${WORKDIR}/u-boot-v2017
./ea3588s.sh
md5sum ../rockdev/uboot.img

#==================================================================#
#                        build kernel                              #
#==================================================================#
cd ${WORKDIR}/kernel-5.10.226
./ea3588s.sh
md5sum ../rockdev/boot.img

#==================================================================#
#                        build rootfs                              #
#==================================================================#
if [ -z "${set_desktop}" ] || [ -z "${set_release}" ]; then
  echo "skip rootfs build"
  echo "Build completed successfully!"
  exit 0
fi

mkdir -p ${WORKDIR}/rootfs
cd ${WORKDIR}/rootfs
if [ "${set_desktop}" == "cli" ]; then
  BUILD_DESKTOP="BUILD_DESKTOP=no"
else
  BUILD_DESKTOP=" \
      BUILD_DESKTOP=yes \
      DESKTOP_APPGROUPS_SELECTED=remote_desktop \
      DESKTOP_ENVIRONMENT=${set_desktop} \
      DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base"
fi
git clone -q --single-branch \
  --depth=1 \
  --branch=main \
  https://github.com/armbian/build.git armbian.git
ls -alh ${WORKDIR}/rootfs/armbian.git
${WORKDIR}/rootfs/armbian.git
# BRANCH=edge    : newest kernel such as 6.10
# BRANCH=current : stable kernel such as 6.6
# BRANCH=legacy  : vendor kernel rockchip 5.10
./compile.sh RELEASE=${set_release} \
  BOARD=nanopct6 \
  BRANCH=current \
  BUILD_MINIMAL=no \
  BUILD_ONLY=default \
  HOST=armbian \
  ${BUILD_DESKTOP} \
  EXPERT=yes \
  KERNEL_CONFIGURE=no \
  COMPRESS_OUTPUTIMAGE="sha,img,xz" \
  VENDOR="Armbian" \
  SHARE_LOG=yes

ls -alh ${WORKDIR}/rootfs/armbian.git/output/images/
# extract rootfs
chmod +x ${WORKDIR}/tools/extract-rootfs-from-armbian.sh
${WORKDIR}/tools/extract-rootfs-from-armbian.sh ${WORKDIR}/rootfs/armbian.git/output/images/
ls -alh ${WORKDIR}/output/images/rootfs.img

# hack rootfs
mount ${WORKDIR}/output/images/rootfs.img /mnt
cp -a ${WORKDIR}/tools/hack-rootfs.sh /mnt/
cp -a ${WORKDIR}/tools/armbian_first_run.txt /mnt/boot/
chmod +x /mnt/hack-rootfs.sh
chroot /mnt sh -c "/hack-rootfs.sh"
sync
umount /mnt
mkdir -p ${WORKDIR}/release
mkdir -p ${WORKDIR}/ouput-temp/
cp -a ${WORKDIR}/template/* ${WORKDIR}/ouput-temp/
cp -a ${WORKDIR}/rockdev/uboot.img ${WORKDIR}/ouput-temp/
cp -a ${WORKDIR}/rockdev/boot.img ${WORKDIR}/ouput-temp/
mv ${WORKDIR}/output/images/rootfs.img ${WORKDIR}/ouput-temp/

# rootfs.img   : ${WORKDIR}/ouput-temp/rootfs.img
# uboot.img    : ${WORKDIR}/ouput-temp/uboot.img
# boot.img     : ${WORKDIR}/ouput-temp/boot.img
# RKDevTool    : ${WORKDIR}/tools/RKDevTool
# afptool      : ${WORKDIR}/tools/afptool
# rkImageMaker : ${WORKDIR}/tools/rkImageMaker
# template     : ${WORKDIR}/ouput-temp
mkdir -p ${WORKDIR}/release
mkdir -p ${WORKDIR}/output-updatable-image
# copy RKDevTool
cp -a ${WORKDIR}/tools/RKDevTool ${WORKDIR}/output-updatable-image/
mkdir -p ${WORKDIR}/output-updatable-image/RKDevTool/rockdev/image/
# copy template
cp -a ${WORKDIR}/ouput-temp/* \
  ${WORKDIR}/output-updatable-image/RKDevTool/rockdev/image/

chmod +x ${WORKDIR}/tools/afptool
chmod +x ${WORKDIR}/tools/rkImageMaker
cd ${WORKDIR}/output-updatable-image/RKDevTool/rockdev/image/
${WORKDIR}/tools/afptool -pack . temp.img
${WORKDIR}/tools/rkImageMaker -RK3588 MiniLoaderAll.bin temp.img update.img -os_type:androidos
find . -type f ! -name "update.img" -exec rm -f {} \;

export build_tag="EA_3588S_k5.10.226_${set_release}_${set_desktop}"
# generate update.img
cd ${WORKDIR}/output-updatable-image/
mksquashfs RKDevTool ${WORKDIR}/release/${build_tag}_update.img.squashfs &&
  rar a ${WORKDIR}/release/${build_tag}_update.img.rar RKDevTool
sha256sum ${WORKDIR}/release/${build_tag}_update.img.squashfs >${WORKDIR}/release/${build_tag}_update.img.squashfs.sha256
sha256sum ${WORKDIR}/release/${build_tag}_update.img.rar >${WORKDIR}/release/${build_tag}_update.img.rar.sha256

# rootfs.img   : ${WORKDIR}/ouput-temp/rootfs.img
# uboot.img    : ${WORKDIR}/ouput-temp/uboot.img
# boot.img     : ${WORKDIR}/ouput-temp/boot.img
# RKDevTool    : ${WORKDIR}/tools/RKDevTool
# afptool      : ${WORKDIR}/tools/afptool
# rkImageMaker : ${WORKDIR}/tools/rkImageMaker
# template     : ${WORKDIR}/ouput-temp

mkdir -p ${WORKDIR}/release
mkdir -p ${WORKDIR}/output-rockdev-image
# copy RKDevTool
cp -a ${WORKDIR}/tools/RKDevTool ${WORKDIR}/output-rockdev-image/
mkdir -p ${WORKDIR}/output-rockdev-image/RKDevTool/rockdev/image/
# copy template
cp -a ${WORKDIR}/ouput-temp/* \
  ${WORKDIR}/output-rockdev-image/RKDevTool/rockdev/image/

# generate rockdev.img
cd ${WORKDIR}/output-rockdev-image/
mksquashfs RKDevTool ${WORKDIR}/release/${build_tag}_rockdev.img.squashfs &&
  rar a ${WORKDIR}/release/${build_tag}_rockdev.img.rar RKDevTool
sha256sum ${WORKDIR}/release/${build_tag}_rockdev.img.squashfs > ${WORKDIR}/release/${build_tag}_rockdev.img.squashfs.sha256
sha256sum ${WORKDIR}/release/${build_tag}_rockdev.img.rar > ${WORKDIR}/release/${build_tag}_rockdev.img.rar.sha256

ls -alh ${WORKDIR}/release/

echo "Build completed successfully!"
exit 0
