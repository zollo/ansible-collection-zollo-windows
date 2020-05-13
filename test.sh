#!/usr/bin/env bash
COLLECTION_NAMESPACE=joezollo
COLLECTION_NAME=windows_server
COLLECTION_BASE_PATH=/etc/ansible/collections/ansible_collections/
COLLECTION_PATH=$COLLECTION_BASE_PATH/$COLLECTION_NAMESPACE/$COLLECTION_NAME
MODULE_NAME=$1
TEST_TYPE=module
mkdir -p $COLLECTION_PATH
cp -r * $COLLECTION_PATH
cd $COLLECTION_PATH
# run validate-modules
if [ $TEST_TYPE == 'module' ]
then
    ansible-test sanity --color -v \
        --docker --test validate-modules --base-branch "master" plugins/modules/${MODULE_NAME}.ps1 plugins/modules/${MODULE_NAME}.py
fi

# ansible-test sanity --docker default
# ansible-test sanity --color -v \
#     --docker --base-branch "master" --allow-disabled
# ansible-test sanity --list-tests --allow-disabled
# ansible-test sanity --docker validate-modules --arg-spec plugins/modules/win_dns_zone.ps1 plugins/modules/win_dns_zone.py
# ansible-test sanity --docker default plugins/modules/win_dns_zone.py
# ansible-test sanity --docker --test validate-modules plugins/modules/win_dns_zone.py
# ansible-test windows-integration -v shippable/