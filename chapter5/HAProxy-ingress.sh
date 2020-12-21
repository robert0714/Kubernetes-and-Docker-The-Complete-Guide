#!/bin/bash

worker1=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' cluster01-worker)
worker2=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' cluster01-worker2)
worker3=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' cluster01-worker3)