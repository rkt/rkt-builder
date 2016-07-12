# rkt-builder

This repository holds scripts and releases for the rkt-in-rkt builder ACI.

## Usage

### Building a new rkt-in-rkt builder ACI

To build the builder ACI image, first update the version variable `IMG_VERSION` in `acbuild.sh`, and execute:

    $ sudo ./acbuild.sh

The rkt project key must be used to sign the generated image. `$RKTSUBKEYID` is the key ID of the rkt Yubikey. Connect the key and run `gpg2 --card-status` to get the ID.

The public key for GPG signing can be found at [CoreOS Application Signing Key](https://coreos.com/security/app-signing-key) and is assumed as trusted.

    $ gpg2 -u $RKTSUBKEYID'!' --armor --output rkt-builder.aci.asc --detach-sign rkt-builder.aci

Commit any changes to `acbuild.sh`, and push them.

Add a signed tag:

    $ GIT_COMMITTER_NAME="CoreOS Application Signing Key" GIT_COMMITTER_EMAIL="security@coreos.com" git tag -u $RKTSUBKEYID'!' -s v1.0.0 -m "rkt-builder v1.0.0"`

Push the tag to GitHub:

    $ git push --tags

### Building rkt-in-rkt

    $ git clone github.com/coreos/rkt
    $ cd rkt
    $ sudo rkt run \
        --volume src-dir,kind=host,source="$(pwd)" \
        --volume build-dir,kind=host,source="$(pwd)/release-build" \
        --interactive \
        coreos.com/rkt/builder:v1.0.0

## Overview

This repository consists of two scripts:

- `acbuild.sh`: This script builds the rkt-in-rkt builder ACI.
- `build.sh`: This script is added to the rkt-in-rkt builder ACI as `/scripts/build.sh`, and is defined as the entrypoint.

The built rkt-in-rkt ACI declares the following volumes:

- `src-dir`: Points to the directory holding the rkt source code.
- `build-dir`: Points to the output directory where the build artifacts are being placed.
