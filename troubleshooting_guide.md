# 🔧 XSS Scanner Troubleshooting Guide

A comprehensive troubleshooting guide for the Advanced XSS Scanner with Multi-Crawler Integration. This guide covers common installation issues, runtime errors, and configuration problems.

## 📋 Table of Contents

- [Installation Issues](#-installation-issues)
- [Tool Dependencies](#-tool-dependencies)
- [Runtime Errors](#-runtime-errors)
- [Configuration Problems](#-configuration-problems)
- [Performance Issues](#-performance-issues)
- [Output and Results](#-output-and-results)
- [Platform-Specific Issues](#-platform-specific-issues)
- [Advanced Troubleshooting](#-advanced-troubleshooting)

---

## 🛠️ Installation Issues

### Python Package Manager Errors

#### Error: `externally-managed-environment`
```bash
error: externally-managed-environment
× This environment is externally managed
╰─> To install Python packages system-wide, try apt install
    python3-xyz, where xyz is the package you are trying to
    install.
```

**Cause:** Modern Python distributions protect the system Python environment from direct pip installations.

**Solutions (Choose One):**

##### ✅ Option 1: Install via pipx (Recommended)
```bash
# Install pipx if not already installed
sudo apt update
sudo apt install pipx

# Install paramspider via pipx
pipx install paramspider

# Ensure pipx binaries are in PATH
pipx ensurepath

# Reload shell configuration
source ~/.bashrc

# Verify installation
paramspider --help
```

##### ✅ Option 2: Use Virtual Environment
```bash
# Create a virtual environment
python3 -m venv ~/security-tools-venv

# Activate it
source ~/security-tools-venv/bin/activate

# Install paramspider
pip install paramspider

# Create global symlink (optional)
sudo ln -s ~/security-tools-venv/bin/paramspider /usr/local/bin/paramspider

# To use: either keep venv activated or use the symlink
```

##### ✅ Option 3: Install from Source (Most Reliable)
```bash
# Clone the repository
cd ~/tools
git clone https://github.com/devanshbatham/ParamSpider
cd ParamSpider

# Create virtual environment for dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Make it globally accessible
sudo ln -s $(pwd)/paramspider.py /usr/local/bin/paramspider
chmod +x /usr/local/bin/paramspider

# Test installation
paramspider --help
```

##### ⚠️ Option 4: Force Install (Not Recommended)
```bash
pip3 install paramspider --break-system-packages
```

##### 📦 Option 5: Check Package Repositories
```bash
# Check if available in system repositories
apt search paramspider

# If available, install via package manager
sudo apt install paramspider
```

#### Error: `pip: command not found`
```bash
bash: pip: command not found
```

**Solutions:**
```bash
# Install pip for Python 3
sudo apt update
sudo apt install python3-pip

# Or use the Python module method
python3 -m pip install --user paramspider
```

#### Error: `python3-venv not available`
```bash
The virtual environment was not created successfully
```

**Solution:**
```bash
# Install python3-venv package
sudo apt install python3-venv

# Then retry virtual environment creation
python3 -m venv ~/security-tools-venv
```

---

## 🔧 Tool Dependencies

### Katana Installation Issues

#### Error: `katana: command not found`
```bash
Error: katana is not installed or not in PATH
```

**Solutions:**

##### Install Katana via Go
```bash
# Install Go if not already installed
sudo apt install golang-go

# Install katana
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Add Go bin to PATH (add to ~/.bashrc)
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
katana -version
```

##### Alternative: Download Binary
```bash
# Download latest release
wget https://github.com/projectdiscovery/katana/releases/latest/download/katana_linux_amd64.zip

# Extract and install
unzip katana_linux_amd64.zip
sudo mv katana /usr/local/bin/
chmod +x /usr/local/bin/katana

# Verify installation
katana -version
```

#### Error: `go: command not found`
```bash
bash: go: command not found
```

**Solution:**
```bash
# Install Go programming language
sudo apt update
sudo apt install golang-go

# Verify installation
go version

# Set Go environment variables (add to ~/.bashrc)
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc
```

### ParamSpider Installation Issues

#### Error: `ModuleNotFoundError: No module named 'requests'`
```bash
ModuleNotFoundError: No module named 'requests'
```

**Solution:**
```bash
# If using virtual environment
source ~/security-tools-venv/bin/activate
pip install requests

# If using system-wide installation
pip3 install requests --user

# Or install all dependencies from source
cd ParamSpider
pip install -r requirements.txt
```

#### Error: `Permission denied: paramspider.py`
```bash
bash: /usr/local/bin/paramspider: Permission denied
```

**Solution:**
```bash
# Fix permissions
sudo chmod +x /usr/local/bin/paramspider

# Or for source installation
chmod +x ~/tools/ParamSpider/paramspider.py
```

---

## ⚡ Runtime Errors

### Script Execution Issues

#### Error: `Permission denied: ./crawl_and_scan.sh`
```bash
bash: ./crawl_and_scan.sh: Permission denied
```

**Solution:**
```bash
# Make script executable
chmod +x crawl_and_scan.sh

# Verify permissions
ls -la crawl_and_scan.sh
```

#### Error: `main.py not found in current directory`
```bash
Error: main.py not found in current directory
```

**Solutions:**
```bash
# Ensure main.py is in the same directory
ls -la main.py

# If missing, create or move your XSS scanner script
cp /path/to/your/xss-scanner.py ./main.py

# Verify file exists and is readable
file main.py
```

#### Error: `No URLs found by katana`
```bash
No URLs found by katana. Check your target URL and try again.
```

**Troubleshooting Steps:**
1. **Verify URL accessibility:**
   ```bash
   curl -I https://target-url.com
   ```

2. **Check DNS resolution:**
   ```bash
   nslookup target-url.com
   ```

3. **Test with increased depth:**
   ```bash
   katana -u https://target-url.com -d 3 -o test.txt
   ```

4. **Try different katana options:**
   ```bash
   katana -u https://target-url.com -jc -aff -o test.txt
   ```

### Crawler-Specific Issues

#### ParamSpider: No Results from Archives
```bash
ParamSpider didn't generate expected output file
```

**Solutions:**
```bash
# Test ParamSpider manually
paramspider -d target-domain.com -l 2

# Check if domain has archived data
curl "http://web.archive.org/cdx/search/cdx?url=*.target-domain.com&output=text&fl=original&collapse=urlkey"

# Try different extraction levels
paramspider -d target-domain.com -l 3
```

#### Katana: JavaScript Rendering Issues
```bash
Katana not finding JavaScript-generated URLs
```

**Solutions:**
```bash
# Enable JavaScript crawling
katana -u https://target-url.com -jc

# Increase JavaScript wait time
katana -u https://target-url.com -jc -jwt 5

# Use headless mode
katana -u https://target-url.com -headless
```

---

## 🔧 Configuration Problems

### Scanner Configuration Issues

#### Error: `Invalid thread count`
```bash
Invalid thread count, using default
```

**Solution:**
```bash
# Use valid thread count (1-10)
# In interactive mode, enter: 5
# Or modify script to accept your preferred default
```

#### Error: `Scanner failed with exit code: 1`
```bash
XSS scan failed with exit code: 1
```

**Troubleshooting:**
```bash
# Run scanner manually to see error details
python3 main.py -f final_urls.txt -o xss.txt

# Check Python dependencies
python3 -c "import requests, urllib3, concurrent.futures"

# Verify input file exists and has content
cat final_urls.txt | head -5
```

### Path and Environment Issues

#### Error: `Tool not in PATH`
```bash
katana: command not found
paramspider: command not found
```

**Solutions:**
```bash
# Check current PATH
echo $PATH

# Find tool locations
which katana
which paramspider
find / -name "katana" 2>/dev/null
find / -name "paramspider*" 2>/dev/null

# Add tools to PATH temporarily
export PATH=$PATH:/path/to/tool/directory

# Add permanently to ~/.bashrc
echo 'export PATH=$PATH:/path/to/tool/directory' >> ~/.bashrc
source ~/.bashrc
```

---

## 🚀 Performance Issues

### Slow Crawling Performance

#### Problem: Katana taking too long
**Solutions:**
```bash
# Reduce crawl depth
katana -u https://target-url.com -d 1

# Limit concurrent requests
katana -u https://target-url.com -c 5

# Exclude certain file types
katana -u https://target-url.com -ef png,jpg,css,js

# Use faster strategy
katana -u https://target-url.com -strategy depth-first
```

#### Problem: ParamSpider timeout
**Solutions:**
```bash
# Reduce extraction level
paramspider -d target-domain.com -l 1

# Exclude large file extensions
paramspider -d target-domain.com -e pdf,zip,exe,dmg

# Use simpler output format
paramspider -d target-domain.com -o simple
```

### Memory Usage Issues

#### Problem: High memory consumption
**Solutions:**
```bash
# Reduce thread count
# In script: choose option 3, set threads to 2-3

# Process URLs in batches
split -l 100 final_urls.txt batch_
for file in batch_*; do
    python3 main.py -f $file -o xss_$file.txt
done

# Monitor memory usage
top -p $(pgrep -f "main.py")
```

---

## 📊 Output and Results

### Missing Output Files

#### Problem: `xss.txt not generated`
**Troubleshooting:**
```bash
# Check if scanner actually ran
ps aux | grep python3

# Look for error messages
python3 main.py -f final_urls.txt -o xss.txt 2>&1 | tee debug.log

# Verify input file has content
wc -l final_urls.txt

# Check file permissions
ls -la xss.txt
```

#### Problem: Empty result files
**Solutions:**
```bash
# Verify URLs have parameters
grep "=" final_urls.txt | head -5

# Test with a known vulnerable URL
echo "https://vulnerable-site.com/search?q=test" > test_urls.txt
python3 main.py -f test_urls.txt -o test_results.txt

# Check scanner payload configuration
grep -i payload main.py
```

### File Permission Issues

#### Problem: Cannot write output files
```bash
Permission denied: xss.txt
```

**Solutions:**
```bash
# Check directory permissions
ls -la .

# Change ownership if needed
sudo chown $USER:$USER .

# Create files with proper permissions
touch xss.txt katana.txt paramspider.txt
chmod 664 *.txt
```

---

## 💻 Platform-Specific Issues

### Ubuntu/Debian Issues

#### Problem: `apt-get update` fails
```bash
# Fix package sources
sudo apt update --fix-missing

# Clear package cache
sudo apt clean
sudo apt autoclean

# Update package lists
sudo apt update
```

#### Problem: Snap package conflicts
```bash
# If using snap-installed tools, they might not be in PATH
export PATH=$PATH:/snap/bin

# Or create symlinks
sudo ln -s /snap/bin/tool-name /usr/local/bin/tool-name
```

### WSL (Windows Subsystem for Linux) Issues

#### Problem: DNS resolution fails
```bash
# Add to /etc/wsl.conf
[network]
generateResolvConf = false

# Restart WSL and add DNS servers to /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

#### Problem: Network timeouts
```bash
# Increase timeout values in tools
katana -u https://target-url.com -timeout 30

# Use Windows network stack
export WSLENV=PATH/l:$WSLENV
```

### macOS Issues

#### Problem: Homebrew conflicts
```bash
# Use brew for Go installation
brew install go

# Install tools via go
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Fix PATH for homebrew
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
```

---

## 🔬 Advanced Troubleshooting

### Debug Mode Usage

Enable maximum verbosity for troubleshooting:
```bash
# Run with debug mode
./crawl_and_scan.sh 2 https://target-url.com

# Capture all output
./crawl_and_scan.sh 2 https://target-url.com 2>&1 | tee debug.log

# Analyze the debug log
grep -i error debug.log
grep -i fail debug.log
```

### Manual Tool Testing

Test each component individually:

#### Test Katana
```bash
# Basic test
katana -u https://httpbin.org -d 1 -o katana_test.txt

# JavaScript test
katana -u https://httpbin.org -jc -d 1 -o katana_js_test.txt

# Check output
cat katana_test.txt
```

#### Test ParamSpider
```bash
# Basic test
paramspider -d httpbin.org -o simple

# Check results
ls -la results/
cat results/httpbin.org.txt
```

#### Test XSS Scanner
```bash
# Create test URL file
echo "https://httpbin.org/get?param=test" > test_input.txt

# Run scanner
python3 main.py -f test_input.txt -o test_output.txt

# Check results
cat test_output.txt
```

### Network Troubleshooting

#### Test connectivity
```bash
# Basic connectivity
ping target-domain.com

# HTTP connectivity
curl -I https://target-domain.com

# Check for redirects
curl -L -I https://target-domain.com

# Test with different user agents
curl -H "User-Agent: Mozilla/5.0" https://target-domain.com
```

#### Proxy/VPN Issues
```bash
# Check proxy settings
env | grep -i proxy

# Test without proxy
unset http_proxy https_proxy

# Configure tools for proxy
katana -u https://target-url.com -proxy http://proxy:port
```

### Log Analysis

#### Script Debug Information
```bash
# Enable bash debugging
bash -x ./crawl_and_scan.sh 1 https://target-url.com

# Check system logs
journalctl -u networking
dmesg | grep -i network
```

#### Tool-Specific Logs
```bash
# Katana verbose output
katana -u https://target-url.com -verbose

# ParamSpider debug mode
paramspider -d target-domain.com -v

# Python script debugging
python3 -v main.py -f test.txt -o output.txt
```

---

## 🆘 Getting Help

### Before Seeking Help

1. **Run debug mode:**
   ```bash
   ./crawl_and_scan.sh 2 https://target-url.com 2>&1 | tee debug.log
   ```

2. **Test individual components:**
   - Test katana installation: `katana -version`
   - Test paramspider installation: `paramspider --help`
   - Test Python script: `python3 main.py --help`

3. **Check system requirements:**
   ```bash
   # System info
   uname -a
   lsb_release -a
   
   # Python version
   python3 --version
   
   # Go version (for katana)
   go version
   
   # Available memory
   free -h
   
   # Disk space
   df -h
   ```

### Common Command Reference

```bash
# Reset everything and start fresh
rm -f *.txt
rm -rf results/
./crawl_and_scan.sh 1

# Quick test with known working URL
./crawl_and_scan.sh 1 https://httpbin.org

# Manual tool verification
katana -u https://httpbin.org -d 1 -o test.txt && echo "Katana OK"
paramspider -d httpbin.org && echo "ParamSpider OK"
```

### Emergency Recovery

If the script is completely broken:
```bash
# Backup current state
cp crawl_and_scan.sh crawl_and_scan.sh.backup

# Reset file permissions
chmod +x crawl_and_scan.sh

# Clean temporary files
rm -f *.txt results/

# Reinstall tools
pipx uninstall paramspider
pipx install paramspider
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Test basic functionality
echo "https://httpbin.org/get?test=1" | python3 main.py -f /dev/stdin -o test.txt
```

---

**💡 Pro Tip:** Always start troubleshooting with the simplest test case (like `https://httpbin.org`) before moving to your actual target. This helps isolate whether the issue is with your setup or the target website.

**⚠️ Remember:** When troubleshooting, ensure you have proper authorization to test any target websites, and be mindful of rate limits and server resources.