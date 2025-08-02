#!/bin/bash

# Simple XSS Scanner with Katana
# Usage: ./simple_crawl_scan.sh

echo "XSS Scanner with Katana Crawler"
echo "================================"

# Check if katana is installed
if ! command -v katana &> /dev/null; then
    echo "Error: katana not found. Install with:"
    echo "go install github.com/projectdiscovery/katana/cmd/katana@latest"
    exit 1
fi

# Get target URL
echo "Enter the website URL to scan:"
read -p "URL: " target_url

# Validate URL
if [[ ! $target_url =~ ^https?:// ]]; then
    echo "Error: Please enter a valid URL (http:// or https://)"
    exit 1
fi

echo "Target: $target_url"
echo ""

# Clean previous results
rm -f katana.txt xss.txt

# Run katana crawler
echo "Crawling website..."
katana -u "$target_url" -d 2 -jc -o katana.txt

# Check if URLs were found
if [ ! -f katana.txt ] || [ ! -s katana.txt ]; then
    echo "No URLs found. Exiting."
    exit 1
fi

# Filter URLs with parameters
grep "=" katana.txt > temp.txt 2>/dev/null || true
if [ -s temp.txt ]; then
    mv temp.txt katana.txt
    echo "Found $(wc -l < katana.txt) URLs with parameters"
else
    echo "No URLs with GET parameters found"
    echo "Total URLs: $(wc -l < katana.txt)"
    rm -f temp.txt
fi

echo ""
echo "Starting XSS scan..."

# Run XSS scanner
python3 main.py -f katana.txt -o xss.txt

echo ""
echo "Results:"
echo "--------"

if [ -f xss.txt ] && [ -s xss.txt ]; then
    echo "🚨 VULNERABILITIES FOUND:"
    cat xss.txt
else
    echo "✅ No XSS vulnerabilities detected"
fi

echo ""
echo "Files created:"
echo "- katana.txt (crawled URLs)"
echo "- xss.txt (vulnerable URLs)"
