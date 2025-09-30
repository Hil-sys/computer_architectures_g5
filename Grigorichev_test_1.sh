#!/bin/bash

print_usage() {
    echo "Usage: $0 <log_directory> <threshold_percent> <files_to_archive>"
    echo "  <log_directory>     - Path to the log directory (must exist)"
    echo "  <threshold_percent> - Threshold percentage (positive integer 1-100)"
    echo "  <files_to_archive>  - Number of old files to archive (positive integer)"
    exit 1
}

if [ $# -ne 3 ]; then
    echo "Error: Exactly 3 arguments required"
    print_usage
fi

log_dir="$1"
threshold="$2"
files_count="$3"

if [ ! -d "$log_dir" ]; then
    echo "Error: Directory '$log_dir' does not exist or is not a directory"
    exit 1
fi

if ! [[ "$threshold" =~ ^[0-9]+$ ]] || [ "$threshold" -le 0 ]; then
    echo "Error: Threshold must be a positive integer"
    exit 1
fi

if ! [[ "$files_count" =~ ^[0-9]+$ ]] || [ "$files_count" -le 0 ]; then
    echo "Error: Files count must be a positive integer"
    exit 1
fi

if [ "$threshold" -gt 100 ]; then
    echo "Error: Threshold cannot exceed 100%"
    exit 1
fi

total_space=$(df "$log_dir" | awk 'NR==2 {print $2}')
if [ -z "$total_space" ] || [ "$total_space" -eq 0 ]; then
    echo "Error: Cannot determine total disk space"
    exit 1
fi

echo "Arguments validation successful:"
echo "  Log directory: $log_dir"
echo "  Threshold: $threshold%"
echo "  Files to archive: $files_count"
