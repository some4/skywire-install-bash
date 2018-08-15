#!/bin/bash

# Install a Skywire node

# Exit script if ANY command fails to avoid failed/partial
# installation
set -e

# CHECK for permission
if [ "$EUID" -ne 0 ]
then
    echo "Please run as Super User"
    exit
fi