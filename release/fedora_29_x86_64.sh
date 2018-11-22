#!/bin/sh

REPO_ROOT=${HOME}/repo
RPM_DIR=${REPO_ROOT}/release/fedora/29/x86_64
SRPM_DIR=${REPO_ROOT}/release/fedora/29/Source
MOCK_CONFIG=fedora-29-x86_64

export REPO_ROOT RPM_DIR SRPM_DIR MOCK_CONFIG

(
    sh release/build_packages.sh
)