#! /usr/bin/env bash

SLEEP_INTERVAL="${SLEEP_INTERVAL:-60}"

while true
do
  /hetzner-dyndns.sh
  sleep "$SLEEP_INTERVAL"
done