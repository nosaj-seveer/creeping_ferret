# Creeping Ferret 🦫

A fast and intelligent XSS (Cross-Site Scripting) vulnerability scanner designed for security researchers and penetration testers.

## ⚡ Features

- **Smart Character Reflection Detection** - Tests for character reflection before payload injection
- **WAF Detection & Bypass** - Automatically detects and adapts to Web Application Firewalls
- **Multi-threaded Scanning** - Concurrent scanning with configurable thread limits
- **Payload Filtering** - Dynamically filters payloads based on character reflection
- **Multiple Input Methods** - Single URL, file input, or stdin pipe support
- **Session Management** - HTTP session reuse for improved performance
- **Custom Headers** - Support for custom HTTP headers and authentication
- **Security Hardened** - Built with security best practices (no command injection vulnerabilities)

## 🚀 Quick Start

### Installation

```bash
git clone https://github.com/nosaj-seveer/creeping_ferret.git
cd creeping_ferret
pip install -r requirements.txt
```

### Basic Usage

```bash
# Scan a single URL
python main.py -u "http://example.com/search.php?q=test"

# Scan multiple URLs from file
python main.py -f urls.txt

# Pipe URLs from other tools
cat urls.txt | python main.py --pipe -o results.txt
```

## 📋 Requirements

- Python 3.6+
- Dependencies listed in `requirements.txt`
- Files required in the same directory:
  - `main.py` (main scanner)
  - `payloads.json` (XSS payloads database)
  - `requirements.txt` (dependencies)

## 🛠 Usage Examples

### Single URL Scanning
```bash
python main.py -u "http://example.com/search.php?q=test"
```

### File-based Scanning
```bash
python main.py -f urls.txt
```

### Custom Headers
```bash
python main.py -u "http://example.com/search.php?q=test" -H "User-Agent:Mozilla/5.0,Cookie:session=abc123"
```

### WAF Detection
```bash
python main.py -u "http://example.com/search.php?q=test" --waf
```

### Multi-threaded Scanning
```bash
python main.py -f urls.txt -t 5
```

### Save Results to File
```bash
python main.py -f urls.txt -o results.txt
```

### Pipeline with Other Tools
```bash
# Integration with subfinder, httpx, and katana
subfinder -d example.com | httpx -silent | katana -silent | grep "=" | python main.py --pipe -o results.txt
```

## 📝 Command Line Options

| Option | Description |
|--------|-------------|
| `-u URL` | Scan a single URL |
| `-f FILE` | Scan URLs from file |
| `-o FILE` | Save results to output file |
| `-t THREADS` | Number of concurrent threads (max 10) |
| `-H HEADERS` | Custom HTTP headers (comma-separated) |
| `--waf` | Enable WAF detection |
| `-w WAF_NAME` | Use specific WAF payloads |
| `--pipe` | Read URLs from stdin |
| `--crawl` | (Not implemented - placeholder) |

## 📁 Input File Format

The URL file should contain one URL per line with GET parameters:

```
http://example.com/search.php?q=test
http://example.com/page.php?id=1&name=test
http://example.com/product.php?category=electronics
```

## 🔍 How It Works

1. **Parameter Identification** - Extracts GET parameters from URLs
2. **Character Reflection Testing** - Tests if special characters are reflected in responses
3. **Payload Filtering** - Filters payloads based on which characters are reflecting
4. **Injection Testing** - Tests filtered payloads against each parameter
5. **Vulnerability Reporting** - Reports successful XSS injections with proof-of-concept URLs

## 📊 Sample Output

```
[+] SCANNING 3 URLs WITH 5 THREADS
[+] TESTING http://example.com/search.php?q=test
[+] 1 parameters identified: q
[+] Testing parameter: q
[+] Character '<' is reflecting in the response
[+] Character '>' is reflecting in the response
[+] Character '"' is reflecting in the response
[+] VULNERABLE: http://example.com/search.php?q=test
PARAMETER: q
PAYLOAD: <script>alert('XSS')</script>
PROOF: http://example.com/search.php?q=<script>alert('XSS')</script>
[+] FOUND 1 VULNERABLE URLs
[+] SCAN COMPLETED
```

## 🛡️ WAF Detection & Bypass

Creeping Ferret can detect and adapt to common Web Application Firewalls:

- Cloudflare
- Akamai
- Incapsula
- Sucuri
- Barracuda
- F5 BIG-IP
- AWS CloudFront

When a WAF is detected, the scanner automatically uses WAF-specific payloads that are more likely to bypass filtering.

## 🔧 Custom Payloads

You can add custom payloads to `payloads.json`:

```json
{
  "Payload": "<custom>alert('test')</custom>",
  "Attribute": ["<", ">", "(", ")", "'"],
  "waf": "custom_waf_name",
  "count": 0
}
```

## 🤝 Integration with Other Tools

Creeping Ferret works well with:

- **Katana** - Web crawler for URL discovery
- **Subfinder** - Subdomain discovery
- **httpx** - HTTP toolkit for filtering live URLs
- **nuclei** - Additional vulnerability scanning

Example workflow:
```bash
subfinder -d example.com | httpx -silent | katana -silent | grep "=" | python main.py --pipe -o results.txt
```

## 🐛 Troubleshooting

### Common Issues

**"No module named 'colorama'"**
```bash
pip install colorama
```

**"No valid URLs found"**
- Ensure URLs in the file have GET parameters (contain '=' character)
- Check URL format (must start with http:// or https://)

**"Connection timeout"**
- Target site may be slow or blocking requests
- Try reducing thread count: `-t 1`

**"No character reflection found"**
- Target may be filtering/encoding input
- Try different payloads or manual testing

**SSL Certificate errors**
- SSL verification is disabled by default for testing
- This is normal for security testing tools

## 🔧 Performance Tips

- Start with single-threaded scanning (`-t 1`) for debugging
- Use 3-5 threads for balanced performance
- Large URL lists may take significant time
- Consider splitting large files into smaller batches

## ⚖️ Legal Disclaimer

- Only test systems you own or have explicit permission to test
- Respect rate limits and don't overwhelm target servers
- Follow responsible disclosure if vulnerabilities are found
- Comply with local laws and regulations

## 🔄 Recent Updates

- ✅ **Security Hardened** - Removed command injection vulnerabilities
- ✅ **Input Validation** - URLs are properly validated before scanning
- ✅ **Safe File Operations** - Using secure file handling practices
- ✅ **Request Timeouts** - Added 10-second timeout to prevent hanging
- ✅ **Thread Safety** - Added locks for shared result list
- ✅ **Improved Error Handling** - Specific exception catching
- ✅ **Performance Optimized** - HTTP session reuse and rate limiting
- ✅ **Code Quality** - PEP 8 compliance and cleaner structure

## 📄 License

This tool is for educational and authorized testing purposes only. Use responsibly and in accordance with applicable laws and regulations.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

---

**⚠️ Warning**: This tool is designed for security testing purposes. Always ensure you have proper authorization before testing any web applications.