#!/bin/bash
# No flags are forced — pass whatever you want via asgard-run, e.g.
#   ./asgard-run tribes2 -nologin -mod Classic
# (Use -nologin for offline play; without it the game tries the defunct
#  WON/Sierra login servers.)
./tribes2.dynamic "$@"
cp console.log /home/loki/.loki/tribes2/console.log 2>/dev/null || true
