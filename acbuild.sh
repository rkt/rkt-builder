#!/usr/bin/env bash
set -ex

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

machine="$(uname -m)"

case ${machine} in
x86_64)
    ACI_ARCH="amd64"
    DEBIAN_SID_DEPS_EXTRA="gcc-aarch64-linux-gnu libc6-dev-arm64-cross"
    ;;
i386|aarch64|aarch64_be|armv6l|armv7l|armv7b|ppc64|ppc64le|s390x)
    ACI_ARCH="${machine}"
    ;;
*)
    echo "Unknown machine: ${machine}" 1>&2
    exit 1
    ;;
esac

IMG_NAME="coreos.com/rkt/builder"
VERSION="1.3.0"
OS=linux
DEBIAN_VERSION=buster

FLAGS=${FLAGS:-""}
ACI_FILE=rkt-builder-"${VERSION}"-"${OS}"-"${ACI_ARCH}".aci
BUILDDIR=/opt/build-rkt
SRC_DIR=/opt/rkt
ACI_GOPATH=/go

DEBIAN_SID_DEPS_BASE="ca-certificates \
	gcc \
	libc6-dev \
	make \
	automake \
	wget \
	git \
	golang-go \
	cpio \
	squashfs-tools \
	realpath \
	autoconf \
	file \
	xz-utils \
	patch \
	bc \
	locales \
	libacl1-dev \
	libssl-dev \
	libsystemd-dev \
	gnupg \
	ruby \
	ruby-dev \
	rpm \
	python \
	python3 \
	zlib1g-dev \
	pkg-config \
	libglib2.0-dev \
	libpixman-1-dev \
	libcap-dev \
	libfdt-dev \
"

DEBIAN_SID_DEPS="${DEBIAN_SID_DEPS_BASE} ${DEBIAN_SID_DEPS_EXTRA}"

function acbuildend() {
    export EXIT=$?;
    acbuild --debug end && rm -rf rootfs && exit $EXIT;
}

echo "Generating debian ${DEBIAN_VERSION} tree"

mkdir rootfs
debootstrap --variant=minbase --components=main --include="${DEBIAN_SID_DEPS}" ${DEBIAN_VERSION} rootfs http://httpredir.debian.org/debian/
rm -rf rootfs/var/cache/apt/archives/*

echo "Version: v${VERSION}"
echo "Building ${ACI_FILE}"

acbuild begin ./rootfs
trap acbuildend EXIT

acbuild $FLAGS set-name $IMG_NAME
acbuild $FLAGS label add version $VERSION
acbuild $FLAGS set-user 0
acbuild $FLAGS set-group 0
echo '{ "set": ["@rkt/default-whitelist", "mlock"] }' | acbuild isolator add "os/linux/seccomp-retain-set" -
acbuild $FLAGS environment add OS_VERSION ${DEBIAN_VERSION}
acbuild $FLAGS environment add GOPATH $ACI_GOPATH
acbuild $FLAGS environment add BUILDDIR $BUILDDIR
acbuild $FLAGS environment add SRC_DIR $SRC_DIR
acbuild $FLAGS mount add build-dir $BUILDDIR
acbuild $FLAGS mount add src-dir $SRC_DIR
acbuild $FLAGS set-working-dir $SRC_DIR
acbuild $FLAGS copy-to-dir build.sh /scripts
acbuild $FLAGS run /bin/mkdir -- -p $ACI_GOPATH
acbuild $FLAGS run /bin/sh -- -c "GOPATH=${ACI_GOPATH} go get github.com/appc/spec/actool"
if [[ "${ACI_ARCH}" == "amd64" ]]; then
	acbuild $FLAGS run /usr/bin/gem -- install fpm
fi
acbuild $FLAGS set-exec /bin/bash /scripts/build.sh
acbuild write --overwrite $ACI_FILE
