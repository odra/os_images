# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source ${SCRIPT_DIR}/vars.sh
source ${SCRIPT_DIR}/aib.sh

if [ "$(arch)" = "x86_64" ]; then
    oci_arch="amd64"
elif [ "$(arch)" = "aarch64" ]; then
    oci_arch="arm64"
else
  echo "[ERR] Unsupported architecture: $(arch)"
fi

if [ -z "${AIB_OCI_IMAGE_BUILDER_SKIP}" ]; then  
    aib::build_builder ${AIB_BUILD_DIR} ${AIB_DISTRO} ${AIB_PREFIX}-builder-latest-${oci_arch}.oci
else
    echo '[INFO] Skipping aib::build_builder'
fi

if [ -z "${AIB_OCI_IMAGE_SKIP}" ]; then
    aib_builder_image=localhost/${AIB_PREFIX}-builder:latest-${oci_arch}
    aib_image=${AIB_PREFIX}-${AIB_TARGET}-latest-${oci_arch}.oci

    aib::build ${AIB_BUILD_DIR} ${AIB_DISTRO} ${AIB_TARGET} image.aib.yml ${aib_image} \
    "--define-file vars.yml --define-file vars-devel.yml --build-container ${aib_builder_image}"
else
    echo '[INFO] Skipping aib::build'
fi
