#!/bin/sh

security find-generic-password -gs "$1" 2>&1 >/dev/null | cut -d":" -f 2 | tr -d \ \"
