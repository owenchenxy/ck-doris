#!/bin/bash

# Number of times to execute the command
num_executions=100

# Command to execute
command="python3 ck_write.py --num_threads 10 --total_entries 1000000 --entries_per_batch 1000"

for i in $(seq 1 $num_executions)
do
    echo "Execution $i/$num_executions"
    $command
    if [ $? -ne 0 ]; then
        echo "Execution $i failed with return code $?"
        break
    fi
done