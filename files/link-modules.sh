#!/bin/bash

set -euo pipefail

for file in ../software/*/*/module; do
        #echo ${file}
        modulename=$(basename $(dirname $(dirname "${file}")))
        moduleversion=$(basename $(dirname "${file}")).lua
        mkdir -p "${modulename}"
        ln -f --relative -s "${file}" "${modulename}"/"${moduleversion}"
done

find . -type l -print0 | while IFS= read -r -d $'\0' file
do
        if [[ ! -e "${file}" ]] ; then
            rm "${file}"
        fi
done
