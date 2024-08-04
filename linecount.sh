#!/bin/bash

# Initialize counters
total_lines=0
total_words=0

# Find all .swift files and use xargs to process them in batches
find . -name '*.swift' -print0 | xargs -0 -n 1 bash -c '{
    for file; do
        lines=$(wc -l < "$file")
        words=$(wc -w < "$file")
        echo $lines $words
    done
}' _ | while read lines words; do
    total_lines=$((total_lines + lines))
    total_words=$((total_words + words))
done

# Print results
echo "Total Lines: $total_lines"
echo "Total Words: $total_words"

