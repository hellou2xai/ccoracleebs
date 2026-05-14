#!/bin/bash

# Find all matching files in the current directory
ls | grep -E '^p[0-9]+_[^/]+\.zip$' | while IFS= read -r file; do
  # Remove .zip extension to create a directory name
  dir="${file%.zip}"
  echo "Creating directory $dir and unzipping $file into it..."
  mkdir -p "$dir"
  unzip -d "$dir" "$file"
done