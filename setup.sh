#!/bin/bash

echo "Setting up XSS Scanner..."

# Check if virtual environment exists
if [ ! -d "xss-scanner-env" ]; then
    echo "Creating virtual environment..."
    python3 -m venv xss-scanner-env
fi

# Activate virtual environment
echo "Activating virtual environment..."
source xss-scanner-env/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install requests colorama urllib3

echo "Setup complete!"
echo ""
echo "To use the scanner:"
echo "1. Activate environment: source xss-scanner-env/bin/activate"
echo "2. Run scanner: python main.py -u 'http://example.com/test.php?id=1'"
echo "3. Deactivate when done: deactivate"
