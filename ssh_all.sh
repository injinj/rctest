#!/bin/bash

hosts=$(cat hosts.txt)
for h in $hosts ; do
echo "----> ${h}"
ssh -t $h $*
done
