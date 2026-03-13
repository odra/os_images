# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
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
  exit 1
fi

aib::oci_import ${AIB_BUILD_DIR} ${AIB_PREFIX}-builder-latest-${oci_arch}.oci localhost/${AIB_PREFIX}-builder:latest-${oci_arch}
