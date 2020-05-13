#!/usr/bin/env bash
MODULE_NAME=win_dns_zone
COLLECTION_PATH=/etc/ansible/collections/ansible_collections/joezollo/windows_server
export SHIPPABLE_BUILD_DIR=/tmp/shippable
export COMMIT_MESSAGE="Test Commit"
mkdir -p $COLLECTION_PATH
mkdir -p /tmp/shippable
cp -r * $COLLECTION_PATH
cd $COLLECTION_PATH
# bash tests/utils/shippable/timing.sh tests/utils/shippable/shippable.sh sanity/1
# ansible-test sanity --docker default
ansible-test sanity --docker default plugins/modules/win_dns_zone.ps1 plugins/modules/win_dns_zone.py
# ansible-test sanity --docker default plugins/modules/win_dns_zone.py

# ansible-test sanity --test validate-modules plugins/modules/win_dns_zone.py
# ansible-test sanity --test validate-modules plugins/modules/win_dns_zone.py

# ansible-test sanity --docker --test validate-modules plugins/modules/win_dns_zone.py
# ansible-test windows-integration -v shippable/