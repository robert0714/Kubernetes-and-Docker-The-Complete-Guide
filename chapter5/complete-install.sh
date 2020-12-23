#!/bin/bash
clear

./go.sh
source ~/.profile
./install-kind.sh
./create-cluster.sh
