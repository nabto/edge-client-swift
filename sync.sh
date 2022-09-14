#!/bin/bash

FILE=`pwd`/dist/NabtoEdgeClient.xcframework.zip
CHANGELOG=`pwd`/CHANGELOG.md

if [ ! -f $FILE ]; then
    echo "Could not find framework zip file $FILE"
    exit 1
fi

if [ ! -f $CHANGELOG ]; then
    echo "Could not find changelog $CHANGELOG"
    exit 1
fi

SPEC=NabtoEdgeClientSwift.podspec
VERSION=`cat $SPEC | grep -E 's\.version.*\=' | awk '{ print $3 }' | sed 's/\"//g'`
if [ -z $VERSION ]; then
    echo "Could not get pod version"
    exit 1
fi

grep -q $VERSION CHANGELOG.md
if [ $? != "0" ]; then
    echo "Missing documentation of version $VERSION in changelog"
    exit 1
fi

DIR=`mktemp -d`
cd $DIR

SUBDIR="ios/nabto-client-swift/$VERSION"
mkdir -p $SUBDIR
cp $FILE $SUBDIR
cp $CHANGELOG $SUBDIR

S3URL="s3://downloads.nabto.com/assets/edge"
tree ios
echo "Synchronizing the above to [$S3URL] - are you sure?"
read -p "Press enter to continue or ^C to abort..."
aws s3 sync . $S3URL --profile prod
rm -rf $DIR
