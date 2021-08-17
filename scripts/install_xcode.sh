#!/bin/sh


OSX_VERSION=`sw_vers -productVersion | cut -d'.' -f1`
HOSTNAME=`hostname | cut -d'.' -f1 | tr '[a-z]' '[A-Z]'`

declare "XCODE_VERSION_FOR_MACOS_${OSX_VERSION}"
declare "XCODE_VERSION_FOR_HOST_${HOSTNAME}"
XCODE_OSX_VERSION="XCODE_VERSION_FOR_MACOS_${OSX_VERSION}"
XCODE_HOSTNAME_VERSION="XCODE_VERSION_FOR_HOST_${HOSTNAME}"

echo "Updating xcode version list"
xcversion update

if [[ -n ${!XCODE_HOSTNAME_VERSION} ]]; then
	echo "Installing Xcode ${!XCODE_HOSTNAME_VERSION} based on XCODE_VERSION_FOR_HOST_${HOSTNAME}"
	xcversion install ${!XCODE_HOSTNAME_VERSION}
elif [[ -n ${!XCODE_OSX_VERSION} ]]; then
	echo "Installing Xcode ${!XCODE_OSX_VERSION} based on XCODE_VERSION_FOR_MACOS_${OSX_VERSION}. XCODE_VERSION_FOR_HOST_${HOSTNAME} not found."
	xcversion install ${!XCODE_OSX_VERSION}
else
	echo "Installing Xcode ${XCODE_VERSION} based on XCODE_VERSION. XCODE_VERSION_FOR_MACOS_${OSX_VERSION} nor XCODE_VERSION_FOR_HOST_${HOSTNAME} exist."
	xcversion install ${XCODE_VERSION}
fi
