#! /bin/bash

while true; do
	./check.sh | tail -n 1 | cut -d ' ' -f3
done

