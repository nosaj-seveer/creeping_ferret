# 🎯 Advanced XSS Scanner with Multi-Crawler Integration

A comprehensive Cross-Site Scripting (XSS) vulnerability scanner that combines multiple web crawling tools with advanced scanning capabilities. This tool integrates **Katana** and **ParamSpider** for maximum URL discovery coverage, then performs targeted XSS testing with customizable attack vectors.

## 🌟 Features

### 🕷️ Multi-Crawler Support
- **Katana Integration**: Fast, modern web crawler for active discovery
- **ParamSpider Integration**: Archive-based parameter discovery from Wayback Machine
- **Flexible Execution**: Choose individual crawlers or combine both for maximum coverage
- **Smart Deduplication**: Automatically removes duplicate URLs across crawlers

### 🎯 Advanced XSS Testing
- **Cookie-Based Attacks**: Target specific cookies with `-attackcookie` flag
- **Parameter-Specific Testing**: Focus on specific GET parameters with `-param` flag
- **WAF Detection & Bypass**: Built-in Web Application Firewall detection
- **Multi-threaded Scanning**: Configurable thread count for performance optimization
- **Custom Headers Support**: Add custom HTTP headers for authenticated testing

### 🔧 User Experience
- **Interactive Prompts**: Step-by-step guidance with continue/stop options
- **Multiple Verbosity Levels**: Silent, Verbose, and Debug modes
- **Color-Coded Output**: Easy-to-read results with visual indicators
- **Progress Tracking**: Real-time scanning progress and statistics
- **Automated Cleanup**: Optional cleanup of temporary files

## 📋 Prerequisites

### Required Tools
```bash
# Install Katana
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Install ParamSpider
pip3 install paramspider
# OR from source:
git clone https://github.com/devanshbatham/ParamSpider
cd ParamSpider
pip3 install -r requirements.txt
```

### Required Files
- `main.py` - Your XSS scanner script (must be in the same directory)
- `crawl_and_scan.sh` - This enhanced crawler script

## 🚀 Installation

1. **Clone or download the script:**
```bash
wget https://your-repo/crawl_and_scan.sh
chmod +x crawl_and_scan.sh
```

2. **Ensure your XSS scanner (`main.py`) is in the same directory:**
```bash
ls -la
# Should show: crawl_and_scan.sh main.py
```

3. **Verify tool installations:**
```bash
katana -version
paramspider --help
```

## 💡 Usage

### Basic Usage
```bash
# Interactive mode (recommended for beginners)
./crawl_and_scan.sh

# Verbose mode with target URL
./crawl_and_scan.sh 1 https://example.com

# Silent mode for automation
./crawl_and_scan.sh 0 https://example.com
```

### Verbosity Levels
- **0** - Silent mode (minimal output, good for automation)
- **1** - Verbose mode (default, interactive prompts)
- **2** - Debug mode (detailed logging and troubleshooting)

### Crawler Options

#### 1. Katana Only (Fast Active Crawling)
- Best for: Modern SPAs, JavaScript-heavy sites
- Speed: Fast
- Coverage: Current site structure

#### 2. ParamSpider Only (Archive-Based Discovery)
- Best for: Historical parameter discovery
- Speed: Medium
- Coverage: Archived URLs with parameters

#### 3. Both Crawlers (Recommended)
- Best for: Maximum coverage
- Speed: Slower but comprehensive
- Coverage: Current + historical URLs

#### 4. ParamSpider First, Then Katana
- Best for: Parameter-focused testing
- Speed: Medium
- Coverage: Archives first, then current structure

## 🔧 Advanced Configuration

### XSS Scanner Options

#### Basic Scan
```bash
# Choose option 1 in interactive mode
# Simple XSS testing with default payloads
```

#### WAF Detection
```bash
# Choose option 2 in interactive mode
# Includes Web Application Firewall detection and bypass attempts
```

#### Custom Threading
```bash
# Choose option 3 in interactive mode
# Specify number of threads (1-10) for performance tuning
```

#### Advanced Attack Options
```bash
# Choose option 4 in interactive mode
# Configure cookie attacks, parameter targeting, WAF detection, and threading
```

#### Full Custom Configuration
```bash
# Choose option 5 in interactive mode
# Manual command-line options configuration
```

### Cookie-Based Attacks
Target specific cookies for XSS testing:
```bash
# During advanced configuration, specify:
Cookie name: session_id
# This adds: -attackcookie "session_id" to the scanner
```

### Parameter-Specific Testing
Focus on specific GET parameters:
```bash
# During advanced configuration, specify:
Parameter name: search
# This adds: -param "search" to the scanner
```

## 📊 Output Files

The script generates several output files for analysis:

| File | Description | Source |
|------|-------------|---------|
| `katana.txt` | URLs discovered by Katana | Katana crawler |
| `paramspider.txt` | URLs discovered by ParamSpider | ParamSpider |
| `combined.txt` | Merged and deduplicated URLs | Both crawlers |
| `final_urls.txt` | Filtered URLs with parameters | Combined results |
| `xss.txt` | Vulnerable URLs found | XSS scanner |
| `results/` | ParamSpider detailed results | ParamSpider output |

## 📈 Example Workflow

### 1. Interactive Scan
```bash
./crawl_and_scan.sh 1
```
1. Enter target URL: `https://example.com`
2. Choose crawler: `3` (Both Katana + ParamSpider)
3. Configure Katana depth: `2`
4. Configure ParamSpider options: (press Enter for defaults)
5. Choose scan type: `4` (Advanced options)
6. Configure cookie attack: `session_id`
7. Configure parameter attack: `search`
8. Enable WAF detection: `y`
9. Set threads: `5`
10. Review configuration and start scan

### 2. Automated Scan
```bash
./crawl_and_scan.sh 0 https://example.com
```
- Runs silently with default options
- Uses both crawlers
- Basic XSS scanning
- Minimal output

### 3. Debug Mode
```bash
./crawl_and_scan.sh 2 https://example.com
```
- Detailed logging
- Full command output
- Troubleshooting information

## 🛡️ Security Considerations

### Ethical Usage
- Only test applications you own or have explicit permission to test
- Obtain proper authorization before scanning
- Follow responsible disclosure practices
- Respect rate limits and server resources

### Rate Limiting
- Use appropriate thread counts to avoid overwhelming targets
- Consider using delays between requests for sensitive targets
- Monitor server responses for rate limiting indicators

### Legal Compliance
- Ensure compliance with local laws and regulations
- Obtain written permission for penetration testing
- Document all testing activities
- Follow your organization's security testing policies

## 🔍 Troubleshooting

### Common Issues

#### Tool Not Found
```bash
Error: katana is not installed or not in PATH
```
**Solution:** Install missing tools using the installation commands above.

#### No URLs Found
```bash
No URLs found by katana. Check your target URL and try again.
```
**Solutions:**
- Verify the target URL is accessible
- Check if the site requires authentication
- Try increasing crawl depth
- Use ParamSpider for archived URLs

#### Scanner Fails
```bash
XSS scan failed with exit code: 1
```
**Solutions:**
- Check if `main.py` exists and is executable
- Verify Python dependencies are installed
- Review scanner command-line arguments
- Check file permissions

#### Permission Denied
```bash
Permission denied: ./crawl_and_scan.sh
```
**Solution:**
```bash
chmod +x crawl_and_scan.sh
```

### Debug Mode
Enable debug mode for detailed troubleshooting:
```bash
./crawl_and_scan.sh 2 https://example.com
```

## 📝 Customization

### Adding New Crawlers
To integrate additional crawlers, modify the script:

1. Add crawler detection in the tool check section
2. Create a new crawler function (e.g., `run_newcrawler_scan()`)
3. Add crawler option in the selection menu
4. Update the result combination logic

### Custom XSS Payloads
Modify your `main.py` scanner to include:
- Custom XSS payload lists
- Advanced encoding techniques
- Context-aware payload selection
- Custom validation patterns

### Integration with CI/CD
For automated security testing:

```bash
# Create a wrapper script
#!/bin/bash
./crawl_and_scan.sh 0 $TARGET_URL
if [ -s xss.txt ]; then
    echo "XSS vulnerabilities found!"
    exit 1
fi
echo "No XSS vulnerabilities detected."
exit 0
```

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- Additional crawler integrations
- Enhanced XSS payload techniques
- Better WAF bypass methods
- Performance optimizations
- Output format improvements

## 📄 License

This tool is provided for educational and authorized security testing purposes only. Users are responsible for complying with applicable laws and obtaining proper authorization before use.

## 🔗 References

- [Katana GitHub](https://github.com/projectdiscovery/katana)
- [ParamSpider GitHub](https://github.com/devanshbatham/ParamSpider)
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [Web Application Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

---

**⚠️ Disclaimer:** This tool is for authorized security testing only. Unauthorized use against systems you don't own or lack permission to test is illegal and unethical. Always obtain proper authorization and follow responsible disclosure practices.