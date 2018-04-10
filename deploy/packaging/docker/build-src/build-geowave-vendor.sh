#-------------------------------------------------------------------------------
# Copyright (c) 2013-2017 Contributors to the Eclipse Foundation
# 
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License,
# Version 2.0 which accompanies this distribution and is available at
# http://www.apache.org/licenses/LICENSE-2.0.txt
#-------------------------------------------------------------------------------
#!/bin/bash
#
# GeoWave Vendor-specific Build Script
#

# This script runs with a volume mount to $WORKSPACE, this ensures that any signal failure will leave all of the files $WORKSPACE editable by the host  
trap 'chmod -R 777 $WORKSPACE' EXIT
trap 'chmod -R 777 $WORKSPACE && exit' ERR

GEOWAVE_VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive -f $WORKSPACE/pom.xml exec:exec $BUILD_ARGS "$@" | sed -e 's/"//g' -e 's/-SNAPSHOT//g')
# Set a default version
VENDOR_VERSION=apache
ACCUMULO_API="$(mvn -q -Dexec.executable="echo" -Dexec.args='${accumulo.api}' --non-recursive -f $WORKSPACE/pom.xml exec:exec $BUILD_ARGS "$@")"

if [[ ! -z "$BUILD_ARGS" ]]; then
	VENDOR_VERSION=$(echo "$BUILD_ARGS" | grep -oi "vendor.version=\w*" | sed "s/vendor.version=//g")
fi
echo "---------------------------------------------------------------"
echo "  Building GeoWave Vendor-specific with the following settings"
echo "---------------------------------------------------------------"
echo "GEOWAVE_VERSION=${GEOWAVE_VERSION}"
echo "VENDOR_VERSION=${VENDOR_VERSION}"
echo "BUILD_ARGS=${BUILD_ARGS} ${@}"
echo "ACCUMULO_API=${ACCUMULO_API}"
echo "---------------------------------------------------------------"

# Clean any classes generated by a previous vendor build to avoid binary incompatibilities    
mvn clean
mkdir -p $WORKSPACE/deploy/target

GEOSERVER_VERSION="$(mvn -q -Dexec.executable="echo" -Dexec.args='${geoserver.version}' --non-recursive -f $WORKSPACE/pom.xml exec:exec $BUILD_ARGS)"
echo $GEOSERVER_VERSION > $WORKSPACE/deploy/target/geoserver_version.txt

GEOWAVE_VERSION_STR="$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive -f $WORKSPACE/pom.xml exec:exec)"
GEOWAVE_VERSION="$(echo ${GEOWAVE_VERSION_STR} | sed -e 's/"//g' -e 's/-SNAPSHOT//g')"

echo $GEOWAVE_VERSION > $WORKSPACE/deploy/target/version.txt
if [[ "$GEOWAVE_VERSION_STR" =~ "-SNAPSHOT" ]]
then
  #its a dev/latest build
  echo "dev" > $WORKSPACE/deploy/target/build-type.txt
  echo "latest" > $WORKSPACE/deploy/target/version-url.txt
else
  #its a release
  echo "release" > $WORKSPACE/deploy/target/build-type.txt
  echo $GEOWAVE_VERSION_STR > $WORKSPACE/deploy/target/version-url.txt
fi

# Build each of the "fat jar" artifacts and rename to remove any version strings in the file name
mvn -q package -am -pl deploy -P geotools-container-singlejar -Dgeotools.finalName=geowave-geoserver-${GEOWAVE_VERSION}-${VENDOR_VERSION} $BUILD_ARGS "$@"

mvn -q package -am -pl services/rest -P rest-services-war -Drestservices.finalName=geowave-restservices-${GEOWAVE_VERSION}-${VENDOR_VERSION} $BUILD_ARGS "$@"

mvn -q package -am -pl deploy -P accumulo-container-singlejar -Daccumulo.finalName=geowave-accumulo-${GEOWAVE_VERSION}-${VENDOR_VERSION} $BUILD_ARGS "$@"

mvn -q package -am -pl deploy -P hbase-container-singlejar -Dhbase.finalName=geowave-hbase-${GEOWAVE_VERSION}-${VENDOR_VERSION} $BUILD_ARGS "$@"

mvn -q package -am -pl deploy -P geowave-tools-singlejar -Dtools.finalName=geowave-tools-${GEOWAVE_VERSION}-${VENDOR_VERSION} $BUILD_ARGS "$@"

# Build Accumulo API Jars
if [[ "$ACCUMULO_API" != "1.7" ]]; then
  mvn -q package -am -pl deploy -P geowave-tools-singlejar -Dtools.finalName=geowave-tools-${GEOWAVE_VERSION}-${VENDOR_VERSION}-accumulo1.7 $BUILD_ARGS "$@" -Daccumulo.version=1.7.2 -Daccumulo.api=1.7
  mvn -q package -am -pl deploy -P accumulo-container-singlejar -Daccumulo.finalName=geowave-accumulo-${GEOWAVE_VERSION}-${VENDOR_VERSION}-accumulo1.7 $BUILD_ARGS "$@" -Daccumulo.version=1.7.2 -Daccumulo.api=1.7
  mvn -q package -am -pl services/rest -P rest-services-war -Drestservices.finalName=geowave-restservices-${GEOWAVE_VERSION}-${VENDOR_VERSION}-accumulo1.7 $BUILD_ARGS "$@" -Daccumulo.version=1.7.2 -Daccumulo.api=1.7
  mvn -q package -am -pl deploy -P geotools-container-singlejar -Dgeotools.finalName=geowave-geoserver-${GEOWAVE_VERSION}-${VENDOR_VERSION}-accumulo1.7 $BUILD_ARGS "$@" -Daccumulo.version=1.7.2 -Daccumulo.api=1.7
else
  echo "Skipping Accumulo API Build"
fi