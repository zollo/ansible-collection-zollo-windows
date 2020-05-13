#!/usr/bin/env bash
COLLECTION_NAMESPACE=joezollo
COLLECTION_NAME=windows_server
COLLECTION_PATH=/etc/ansible/collections/ansible_collections/$COLLECTION_NAMESPACE/$COLLECTION_NAME
MODULE_NAME=win_dns_zone
mkdir -p $COLLECTION_PATH
cp -r * $COLLECTION_PATH
cd $COLLECTION_PATH

ansible-test sanity --color -v \
    --docker --test validate-modules --base-branch "master" plugins/modules/win_dns_zone.ps1 plugins/modules/win_dns_zone.py

# ansible-test sanity --docker default
# ansible-test sanity --color -v \
#     --docker --base-branch "master" --allow-disabled
# ansible-test sanity --list-tests --allow-disabled
# ansible-test sanity --docker validate-modules --arg-spec plugins/modules/win_dns_zone.ps1 plugins/modules/win_dns_zone.py
# ansible-test sanity --docker default plugins/modules/win_dns_zone.py
# ansible-test sanity --docker --test validate-modules plugins/modules/win_dns_zone.py
# ansible-test windows-integration -v shippable/