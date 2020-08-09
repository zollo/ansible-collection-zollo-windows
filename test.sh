#!/usr/bin/env bash
COLLECTION_NAMESPACE=joezollo
COLLECTION_NAME=windows-server
COLLECTION_BASE_PATH=~/.ansible
COLLECTION_PATH=$COLLECTION_BASE_PATH/ansible_collections/$COLLECTION_NAMESPACE/$COLLECTION_NAME
MODULE_NAME=$1
TEST_TYPE=$2
rm -rf $COLLECTION_PATH
mkdir -p $COLLECTION_PATH
cp -r * $COLLECTION_PATH
cd $COLLECTION_PATH
# run validate-modules
if [ $TEST_TYPE == 'module' ]; then
    echo "Running Module Tests"
    echo "Testing Module: $MODULE_NAME"
    ansible-test sanity --color -v \
        --docker default \
        --base-branch "master" plugins/modules/${MODULE_NAME}.ps1 plugins/modules/${MODULE_NAME}.py
fi

if [ $TEST_TYPE == 'sanity' ]; then
    echo "Running All Tests"
    ansible-test sanity --color -v --docker default --base-branch "master" --changed
fi

if [ $TEST_TYPE == 'windows-integration' ]; then
    echo "Running Windows Integration Tests"
    version="2019"
    provider="aws"
    target=""
    COVERAGE="-coverage-check"
    CHANGED="--changed"
    UNSTABLE="--allow-unstable-changed"

    ansible-test windows-integration --color -v --retry-on-error "${target}" \
        ${COVERAGE:+"$COVERAGE"} ${CHANGED:+"$CHANGED"} ${UNSTABLE:+"$UNSTABLE"} \
        --windows "${version}" --docker default --remote-terminate always --remote-stage "${stage}" \
        --remote-provider "${provider}"

    ansible-test windows-integration --color -v --retry-on-error shippable/windows/group2/ \
        --coverage-check --changed --allow-unstable-changed --windows "${version}" --docker default \
        --remote-terminate always --remote-stage "${stage}" \
        --remote-provider default
fi