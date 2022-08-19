#!/bin/bash

# Set script exicution dir
cd "$(dirname "$0")"

# Check if current hostname matches test file
if [ $(hostnamectl status --static) == "$(cat ${1})" ]; then
    exit 0
else
    exit 1
fi