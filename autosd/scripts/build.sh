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

aib::build_builder ${AIB_DISTRO}
aib::build ${AIB_DISTRO} ${AIB_TARGET} ${AIB_MANIFEST} ${AIB_OCI_IMAGE} "--define-file vars.yml --define-file vars-devel.yml"
aib::oci_to_disk_image ${AIB_OCI_IMAGE} ${AIB_BUILD_DIR}/${AIB_DISK_IMAGE}
