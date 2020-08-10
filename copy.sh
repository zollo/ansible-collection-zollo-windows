MODULE_NAME=$1
rm -rf ~/github/community.windows/tests/integration/targets/$1/
cp ~/github/ansible-collection-windows-server/plugins/modules/${1}* ~/github/community.windows/plugins/modules/
cp -r ~/github/ansible-collection-windows-server/tests/integration/targets/${1}/ ~/github/community.windows/tests/integration/targets/${1}/