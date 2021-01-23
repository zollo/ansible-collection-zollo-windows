#!/usr/bin/env bash

# Makefile for Ansible Collection (zollo.windows)
SHELL:=/bin/bash
IMG=zollo/ansible-ci:latest
CI_PWD:=$(shell pwd)
CL_ROOT=/tmp/ansible/ansible_collections
CL_PATH=${CL_ROOT}/${CL_NAMESPACE}/${CL_NAME}
CL_NAMESPACE=zollo
CL_NAME=windows

test:
	docker pull ${IMG}
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${CI_PWD}:${CL_PATH}" \
		-e "T=${T}" \
		-w "${CL_PATH}" \
		${IMG} tests/utils/test.sh

console:
	docker pull ${IMG}
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${CI_PWD}:${CL_PATH}" \
		-e "T=${T}" \
		-w "${CL_PATH}" \
		${IMG}

build:
	docker pull ${IMG}
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${CI_PWD}:${CL_PATH}" \
		-w "${CL_PATH}" \
		${IMG} ansible-galaxy collection build --output-path ./artifact --force
