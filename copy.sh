MODULE_NAME=$1
DEST_PATH=~/github/community.windows
SRC_PATH=~/github/ansible-collection-windows-server
cp $SRC_PATH/plugins/modules/${1}* $DEST_PATH/plugins/modules/
cp -r $SRC_PATH/tests/integration/targets/${1}/ $DEST_PATH/tests/integration/targets/