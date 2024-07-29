#!/bin/bash

PYTHON_VERSION="3.11"
VENV_DIR="venv"

# Check if Python 3.11 is installed
if python3.11 --version &> /dev/null; then
    echo "Python 3.11 is already installed."
else
    echo "Installing Python 3.11..."
    # Install Python 3.11 (adjust the installation method as per your system)
    # Example for Ubuntu/Debian:
    sudo apt-get install python3.11
    # Example for macOS with Homebrew:
    # brew install python@3.11
fi

# Create a virtual environment
echo "Creating virtual environment..."
python3.11 -m venv $VENV_DIR

# Update venv activate script (venv/bin/activate)
echo "Updating virtual environment activation script..."

# Create a backup of the original activate script
cp $VENV_DIR/bin/activate $VENV_DIR/bin/activate.bak

# Update the activate script to include the desired modifications
# For example, adding a custom message when activating the venv
echo 'echo "Virtual environment activated!"' >> $VENV_DIR/bin/activate

echo "Virtual environment setup complete."
# To activate the virtual environment, run:
# source $VENV_DIR/bin/activate