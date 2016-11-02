#!/usr/bin/env bash
set -ex

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

IMG_NAME="coreos.com/rkt/builder"
VERSION="1.1.1"
ARCH=amd64
OS=linux

FLAGS=${FLAGS:-""}
ACI_FILE=rkt-builder-"${VERSION}"-"${OS}"-"${ARCH}".aci
BUILDDIR=/opt/build-rkt
SRC_DIR=/opt/rkt
ACI_GOPATH=/go

DEBIAN_SID_DEPS="ca-certificates gcc libc6-dev make automake wget git golang-go cpio squashfs-tools realpath autoconf file xz-utils patch bc locales libacl1-dev libssl-dev libsystemd-dev gnupg ruby ruby-dev rpm"

function acbuildend() {
    export EXIT=$?;
    acbuild --debug end && rm -rf rootfs && exit $EXIT;
}

echo "Generating debian sid tree"

mkdir rootfs
debootstrap --variant=minbase --components=main --include="${DEBIAN_SID_DEPS}" sid rootfs http://httpredir.debian.org/debian/
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
acbuild $FLAGS environment add OS_VERSION sid
acbuild $FLAGS environment add GOPATH $ACI_GOPATH
acbuild $FLAGS environment add BUILDDIR $BUILDDIR
acbuild $FLAGS environment add SRC_DIR $SRC_DIR
acbuild $FLAGS mount add build-dir $BUILDDIR
acbuild $FLAGS mount add src-dir $SRC_DIR
acbuild $FLAGS set-working-dir $SRC_DIR
acbuild $FLAGS copy-to-dir build.sh /scripts
acbuild $FLAGS run /bin/mkdir -- -p $ACI_GOPATH
acbuild $FLAGS run /bin/sh -- -c "GOPATH=${ACI_GOPATH} go get github.com/appc/spec/actool"
acbuild $FLAGS run /usr/bin/gem -- install fpm
acbuild $FLAGS set-exec /bin/bash /scripts/build.sh
acbuild write --overwrite $ACI_FILE
