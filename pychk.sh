#!/bin/bash

# Get the Python version
python_version=$(python -V 2>&1)

# Extract the major and minor version
major_version=$(echo "$python_version" | awk '{print $2}' | cut -d. -f1)
minor_version=$(echo "$python_version" | awk '{print $2}' | cut -d. -f2)

# Check if the Python version is not equal to 3.11
if [ "$major_version" != "3" ] || [ "$minor_version" != "11" ]; then
    echo "Python version is not equal to 3.11"
else
    echo "Python version is equal to 3.11"
fi