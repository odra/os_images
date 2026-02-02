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
aib::build_builder() {
	local distro=${1}
	if [ -z ${distro+x} ]; then
		echo "provide a builder distro"
		exit 1
	fi

	${AIB_BIN} build-builder --distro ${distro}
}

aib::build() {
	local distro=${1}
	if [ -z ${distro+x} ]; then
		echo "provide a builder distro"
		exit 1
	fi

	local target=${2}
	if [ -z ${target+x} ]; then
		echo "provide a platform target"
		exit 1
	fi

	local manifest=${3}
	if [ -z ${manifest+x} ]; then
		echo "provide a manifest path"
		exit 1
	fi

	local oci_image=${4}
	if [ -z ${oci_image+x} ]; then
		echo "provide a oci image name"
		exit 1
	fi

	local extras="${5}"
	
	${AIB_BIN} build \
		${extras} \
		--target ${target} \
		--distro ${distro} \
		${manifest} \
		${oci_image}
}

aib::oci_to_disk_image() {
	local oci_image=${1}
	if [ -z ${oci_image+x} ]; then
		echo "provide a oci image name"
		exit 1
	fi

	local disk_image_path=${2}
	if [ -z ${disk_image_path+x} ]; then
		echo "provide a disk image path"
		exit 1
	fi

	${AIB_BIN} to-disk-image ${oci_image} ${disk_image_path}
}
