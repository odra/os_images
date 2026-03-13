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
    local build_dir=${1}
    if [ -z ${build_dir+x} ]; then
        echo "provide a build_dir"
        exit 1
    fi
	
    local distro=${2}
    if [ -z ${distro+x} ]; then
        echo "provide a builder distro"
        exit 1
    fi

    local image_name=${3}
    if [ -z ${image_name+x} ]; then
        echo "provide a builder distro image name"
        exit 1
    fi

    local opts=""
    if [ "${image_name##*.}" = "oci" ]; then
        opts="--oci-archive"
    fi

    ${AIB_BIN} build-builder --distro=${distro} ${opts} ${build_dir}/outputs/${image_name}
}

aib::build() {
    local build_dir=${1}
    if [ -z ${build_dir+x} ]; then
        echo "provide a build_dir"
        exit 1
    fi

    local distro=${2}
    if [ -z ${distro+x} ]; then
        echo "provide a builder distro"
        exit 1
    fi

    local target=${3}
    if [ -z ${target+x} ]; then
        echo "provide a platform target"
        exit 1
    fi

    local manifest=${4}
    if [ -z ${manifest+x} ]; then
        echo "provide a manifest path"
        exit 1
    fi

    local oci_image=${5}
    if [ -z ${oci_image+x} ]; then
        echo "provide a oci image name"
        exit 1
    fi

    local extras="${6}"
	
    ${AIB_BIN} build \
    ${extras} \
    --target ${target} \
    --distro ${distro} \
    ${manifest} \
    ${opts} \
    --oci-archive \
    ${AIB_BUILD_DIR}/outputs/${oci_image}
}

aib::to_disk_image() {
    local build_dir=${1}
    if [ -z ${build_dir+x} ]; then
        echo "provide a build_dir"
        exit 1
    fi
        
    local oci_image_builder=${2}
    if [ -z ${oci_image_builder+x} ]; then
        echo "provide an oci image builder name"
        exit 1
    fi

    local oci_image=${3}
    if [ -z ${oci_image+x} ]; then
        echo "provide an oci image name"
        exit 1
    fi

    local disk_image_path=${4}
    if [ -z ${disk_image_path+x} ]; then
       echo "provide a disk image path"
       exit 1
    fi

    ${AIB_BIN} --verbose to-disk-image \
    --oci-archive \
    --build-container=${oci_image_builder} \
    ${build_dir}/outputs/${oci_image} \
    ${build_dir}/outputs/${disk_image_path}
}

aib::oci_import() {
    local build_dir=${1}
    if [ -z ${build_dir+x} ]; then
        echo "provide a build_dir"
        exit 1
    fi

    local oci_archive=${2}
    if [ -z ${oci_archive+x} ]; then
        echo "provide an oci archive file name"
        exit 1
    fi

    local image_name=${3}
    if [ -z ${image_name+x} ]; then
        echo "provide an image name"
        exit 1
    fi

    local img=quay.io/fedora/fedora:latest
    oci_cmd="skopeo copy oci-archive:/outputs/${oci_archive} containers-storage:${image_name}"

    podman --log-level=error run \
	-it --rm --privileged --security-opt label=type:unconfined_t \
	-v ${build_dir}/containers-storage:/var/lib/containers/storage \
	-v ${build_dir}/outputs:/outputs \
	${img} \
    bash -c "dnf install podman skopeo -y && ${oci_cmd} && podman images"
}
