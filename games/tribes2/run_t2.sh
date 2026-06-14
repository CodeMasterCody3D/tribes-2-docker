#!/bin/bash
./tribes2.dynamic -nologin "$@"
cp console.log /home/loki/.loki/tribes2/console.log
