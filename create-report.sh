#!/bin/bash

WDIR=/usr/local/lastcontrol

chmod +x $WDIR/scripts/*
run-parts $WDIR/scripts
