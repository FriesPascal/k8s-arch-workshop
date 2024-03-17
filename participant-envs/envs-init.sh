#!/bin/env bash
for i in {0..10}; do
    sed "s/PARTICIPANT/clt-$i/g" participant.yaml | kubectl apply -f -
done
