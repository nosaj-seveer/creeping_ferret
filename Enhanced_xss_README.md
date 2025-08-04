# Creeping Ferret 🦫

An enhanced bash-based XSS (Cross-Site Scripting) vulnerability scanner designed for security researchers and penetration testers.

## ⚡ Features

- **Bash-Native Implementation** - Fast and lightweight shell script
- **Smart Character Reflection Detection** - Tests for character reflection before payload injection
- **WAF Detection & Bypass** - Automatically detects and adapts to Web Application Firewalls
- **Multi-process Scanning** - Concurrent scanning with configurable process limits
- **Payload Filtering** - Dynamically filters payloads based on character reflection
- **Multiple Input Methods** - Single URL, file input, or stdin pipe support
- **Custom Headers** - Support for custom HTTP headers and authentication
- **Minimal Dependencies** - Uses standard Unix tools (curl, grep, awk, etc.)
- **JSON Payload Database** - Extensible payload system with WAF-specific payloads

## 🚀 Quick Start

### Prerequisites

- bash (4.0+)
- curl
- jq (for JSON parsing)
- Standard Unix utilities (grep, awk, sed, etc.)

### Installation

```bash
git clone https://github.com/nosaj-seveer/creeping_ferret.git
cd creeping_ferret
chmod +x enhanced_xss_scanner.sh
```

### Basic Usage

```bash
# Scan a single URL
./enhanced_xss_scanner.sh -u "http://example.com/search.php?q=test"

# Scan multiple URLs from file
./enhanced_xss_scanner.sh -f urls.txt

# Pipe URLs from other tools
cat urls.txt | ./enhanced_xss_scanner.sh --pipe -o results.txt
```

## 📋 Requirements

- **bash** 4.0 or higher
- **curl** for HTTP requests
- **jq** for JSON payload parsing
- **payloads.json** - XSS payloads database
- Standard Unix utilities (grep, awk, sed, sort, etc.)

## 🛠 Usage Examples

### Single URL Scanning
```bash
./enhanced_xss_scanner.sh -u "http://example.com/search.php?q=test"
```

### File-based Scanning
```bash
./enhanced_xss_scanner.sh -f urls.txt
```

### Custom Headers
```bash
./enhanced_xss_scanner.sh -u "http://example.com/search.php?q=test" -H "User-Agent: Mozilla/5.0" -H "Cookie: session=abc123"
```

### WAF Detection
```bash
./enhanced_xss_scanner.sh -u "http://example.com/search.php?q=test" --waf
```

### Multi-process Scanning
```bash
./enhanced_xss_scanner.sh -f urls.txt -t 5
```

### Save Results to File
```bash
./enhanced_xss_scanner.sh -f urls.txt -o results.txt
```

### Pipeline with Other Tools
```bash
# Integration with subfinder, httpx, and katana
subfinder -d example.com | httpx -silent | katana -silent | grep "=" | ./enhanced_xss_scanner.sh --pipe -o results.txt
```

### Verbose Output
```bash
./enhanced_xss_scanner.sh -u "http://example.com/search.php?q=test" -v
```

## 📝 Command Line Options

| Option | Description |
|--------|-------------|
| `-u URL` | Scan a single URL |
| `-f FILE` | Scan URLs from file |
| `-o FILE` | Save results to output file |
| `-t PROCESSES` | Number of concurrent processes (default: 3, max: 10) |
| `-H HEADER` | Custom HTTP header (can be used multiple times) |
| `--waf` | Enable WAF detection |
| `-w WAF_NAME` | Use specific WAF payloads |
| `--pipe` | Read URLs from stdin |
| `-v, --verbose` | Enable verbose output |
| `--timeout SECONDS` | HTTP request timeout (default: 10) |
| `--delay SECONDS` | Delay between requests (default: 0) |
| `--user-agent UA` | Custom User-Agent string |
| `--proxy PROXY` | Use HTTP proxy (format: http://proxy:port) |
| `--no-color` | Disable colored output |
| `-h, --help` | Show help message |

## 📁 Input File Format

The URL file should contain one URL per line with GET parameters:

```
http://example.com/search.php?q=test
http://example.com/page.php?id=1&name=test
http://example.com/product.php?category=electronics
```

## 🔍 How It Works

1. **URL Parsing** - Extracts GET parameters from URLs using bash parameter expansion
2. **Character Reflection Testing** - Uses curl to test if special characters are reflected
3. **Payload Filtering** - Uses jq to filter payloads based on reflected characters
4. **Concurrent Testing** - Spawns background processes for parallel scanning
5. **WAF Detection** - Analyzes HTTP headers and response patterns
6. **Result Aggregation** - Collects and formats vulnerability reports

## 📊 Sample Output

```bash
[+] Creeping Ferret XSS Scanner v2.0
[+] Scanning 3 URLs with 5 processes
[+] Loading payloads from payloads.json...
[+] Loaded 247 payloads

[INFO] Testing: http://example.com/search.php?q=test
[INFO] Parameters found: q
[INFO] Testing parameter: q
[+] Character '<' reflected in response
[+] Character '>' reflected in response  
[+] Character '"' reflected in response
[!] Filtering 247 payloads to 89 based on reflection

[VULN] XSS FOUND!
URL: http://example.com/search.php?q=test
Parameter: q
Payload: <script>alert('XSS')</script>
PoC: http://example.com/search.php?q=<script>alert('XSS')</script>

[+] Scan completed: 1/3 URLs vulnerable
[+] Results saved to results.txt
```

## 🛡️ WAF Detection & Bypass

The scanner can detect and adapt to common Web Application Firewalls:

- **Cloudflare** - Detects via CF-RAY header
- **Akamai** - Detects via Server header patterns
- **Incapsula** - Detects via X-Iinfo header
- **Sucuri** - Detects via X-Sucuri-ID header
- **Barracuda** - Detects via response patterns
- **F5 BIG-IP** - Detects via Server header
- **AWS CloudFront** - Detects via X-Amz-Cf-Id header

WAF-specific payloads are automatically selected when a WAF is detected.

## 🔧 Payload Configuration

The `payloads.json` file structure:

```json
[
  {
    "Payload": "<script>alert('XSS')</script>",
    "Attribute": ["<", ">", "(", ")", "'"],
    "waf": "generic",
    "description": "Basic script tag"
  },
  {
    "Payload": "javascript:alert('XSS')",
    "Attribute": [":", "(", ")", "'"],
    "waf": "cloudflare",
    "description": "JavaScript protocol handler"
  }
]
```

### Adding Custom Payloads

```bash
# Add a new payload to the JSON file
jq '. += [{"Payload": "<custom>alert(1)</custom>", "Attribute": ["<", ">", "(", ")"], "waf": "custom", "description": "Custom payload"}]' payloads.json > temp.json && mv temp.json payloads.json
```

## 🤝 Integration with Other Tools

### Common Workflows

```bash
# Subdomain discovery + XSS scanning
subfinder -d target.com | httpx -silent | katana -silent | grep "=" | ./enhanced_xss_scanner.sh --pipe

# With waybackurls for historical URLs
waybackurls target.com | grep "=" | ./enhanced_xss_scanner.sh --pipe -t 10

# With gau (Get All URLs)
gau target.com | grep "=" | ./enhanced_xss_scanner.sh --pipe --delay 1

# Filter live URLs first
cat urls.txt | httpx -silent | ./enhanced_xss_scanner.sh --pipe -o results.txt
```

### Output Formats

The scanner can output results in different formats:

```bash
# JSON output
./enhanced_xss_scanner.sh -f urls.txt -o results.json --format json

# CSV output  
./enhanced_xss_scanner.sh -f urls.txt -o results.csv --format csv

# Plain text (default)
./enhanced_xss_scanner.sh -f urls.txt -o results.txt
```

## 🐛 Troubleshooting

### Common Issues

**"jq: command not found"**
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# CentOS/RHEL
sudo yum install jq
```

**"curl: command not found"**
```bash
# Most systems have curl, but if not:
sudo apt-get install curl  # Ubuntu/Debian
brew install curl          # macOS
```

**"No valid URLs found"**
- Ensure URLs contain GET parameters (with '=' character)
- Check URL format (must start with http:// or https://)
- Verify file permissions and existence

**"Connection timeout"**
- Increase timeout: `--timeout 30`
- Reduce concurrent processes: `-t 1`
- Add delay between requests: `--delay 2`

**"Permission denied"**
```bash
chmod +x enhanced_xss_scanner.sh
```

## 🔧 Performance Optimization

### Memory Usage
- The script uses minimal memory as it processes URLs sequentially
- Large payload files are streamed through jq rather than loaded entirely

### Speed Optimization
```bash
# Fast scan (more processes, less delay)
./enhanced_xss_scanner.sh -f urls.txt -t 10 --delay 0

# Careful scan (fewer processes, more delay)
./enhanced_xss_scanner.sh -f urls.txt -t 2 --delay 2

# Stealth scan (single process, longer delay)
./enhanced_xss_scanner.sh -f urls.txt -t 1 --delay 5
```

### Resource Limits
- Maximum concurrent processes: 10
- Default timeout: 10 seconds
- Process monitoring to prevent resource exhaustion

## 🔒 Security Features

- **Input Validation** - All URLs and parameters are validated
- **Safe Shell Execution** - Proper quoting and escaping
- **Process Limits** - Prevents resource exhaustion
- **Timeout Protection** - Prevents hanging connections
- **Error Handling** - Graceful failure handling

## ⚖️ Legal & Ethical Usage

**IMPORTANT**: This tool is for authorized security testing only.

- ✅ Only test systems you own or have explicit written permission to test
- ✅ Respect rate limits and server resources
- ✅ Follow responsible disclosure practices
- ✅ Comply with local laws and regulations
- ❌ Do not use for malicious purposes
- ❌ Do not overwhelm target servers
- ❌ Do not test without proper authorization

## 🔄 Version History

### v2.0 (Current)
- ✅ **Bash Rewrite** - Complete rewrite in bash for better performance
- ✅ **WAF Detection** - Automatic WAF detection and bypass
- ✅ **JSON Payloads** - Structured payload database with jq parsing
- ✅ **Process Management** - Better concurrent process handling
- ✅ **Error Handling** - Improved error detection and reporting
- ✅ **Output Formats** - Multiple output format support

### v1.0
- ✅ Basic XSS scanning functionality
- ✅ Character reflection testing
- ✅ Multi-threaded scanning
- ✅ File and stdin input support

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Test thoroughly** - Ensure changes don't break existing functionality
2. **Follow shell best practices** - Use proper quoting and error handling
3. **Update documentation** - Keep README and comments current
4. **Add payload sources** - Credit sources for new payloads

### Development Setup

```bash
# Clone and setup development environment
git clone https://github.com/nosaj-seveer/creeping_ferret.git
cd creeping_ferret

# Install development dependencies
sudo apt-get install shellcheck  # For shell script linting

# Run tests
./test_scanner.sh
```

## 📄 License

This tool is provided for educational and authorized security testing purposes only. Users are responsible for compliance with applicable laws and regulations.

---

**⚠️ Disclaimer**: This tool is designed for legitimate security testing. Always ensure proper authorization before testing web applications. The authors are not responsible for misuse of this tool.