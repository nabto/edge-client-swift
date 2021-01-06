#!/bin/bash

set -e

CONFIG=Release

PROJECT_NAME=NabtoEdgeClient
BUILD_ROOT=`pwd`
BUILD=$BUILD_ROOT/build-$CONFIG
ARTIFACTS=$BUILD_ROOT/dist

rm -rf $ARTIFACTS

mkdir -p $BUILD
mkdir -p $ARTIFACTS

WORKSPACE=${PROJECT_NAME}/${PROJECT_NAME}.xcworkspace

# iOS
xcodebuild clean archive \
    -workspace $WORKSPACE \
    -scheme "${PROJECT_NAME}" \
    -archivePath $BUILD/ios.xcarchive \
    -configuration $CONFIG \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# iOS sim
xcodebuild clean archive \
    -workspace $WORKSPACE \
    -scheme "${PROJECT_NAME}" \
    -archivePath $BUILD/ios-sim.xcarchive \
    -configuration $CONFIG \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

PRODUCT_PATH=Products/Library/Frameworks/${PROJECT_NAME}.framework

xcodebuild -create-xcframework \
           -framework "$BUILD/ios.xcarchive/$PRODUCT_PATH" \
           -framework "$BUILD/ios-sim.xcarchive/$PRODUCT_PATH" \
           -output "$ARTIFACTS/$PROJECT_NAME.xcframework"

cd $ARTIFACTS

cd $ARTIFACTS
cp ../LICENSE ${PROJECT_NAME}.xcframework

zip -r ${PROJECT_NAME}.xcframework.zip ${PROJECT_NAME}.xcframework
