#!/bin/bash


docker run --rm -v "$(pwd):/app/mounted" -u "$(id -u):$(id -g)" -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY igen:latest