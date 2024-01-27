#!/bin/bash

set -euo pipefail

for file in ../software/*/*/module; do
        #echo ${file}
        mkdir -p $(basename $(dirname $(dirname ${file})))
        ln -f --relative -s ${file} $(basename $(dirname $(dirname ${file})))/$(basename $(dirname ${file})).lua
done