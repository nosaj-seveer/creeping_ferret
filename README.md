# XSS Scanner - Fixed Version

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Make sure all files are in the same directory:
   - `main.py` (the main scanner)
   - `payloads.json` (XSS payloads database)
   - `requirements.txt` (dependencies)

## Usage

### Single URL Scan
```bash
python main.py -u "http://example.com/search.php?q=test"
```

### File-based Scan
```bash
python main.py -f urls.txt
```

### With Custom Headers
```bash
python main.py -u "http://example.com/search.php?q=test" -H "User-Agent:Mozilla/5.0,Cookie:session=abc123"
```

### With WAF Detection
```bash
python main.py -u "http://example.com/search.php?q=test" --waf
```

### Multi-threaded Scan
```bash
python main.py -f urls.txt -t 5
```

### Save Results to File
```bash
python main.py -f urls.txt -o results.txt
```

### Pipe Input
```bash
cat urls.txt | python main.py --pipe -o results.txt
```

## Command Line Options

- `-u URL`: Scan a single URL
- `-f FILE`: Scan URLs from file
- `-o FILE`: Save results to output file
- `-t THREADS`: Number of concurrent threads (max 10)
- `-H HEADERS`: Custom HTTP headers (comma-separated)
- `--waf`: Enable WAF detection
- `-w WAF_NAME`: Use specific WAF payloads
- `--pipe`: Read URLs from stdin
- `--crawl`: (Not implemented - placeholder)

## Input File Format

The URL file should contain one URL per line with GET parameters:
```
http://example.com/search.php?q=test
http://example.com/page.php?id=1&name=test
http://example.com/product.php?category=electronics
```

## Output

The scanner will:
1. Test each parameter for character reflection
2. Filter payloads based on reflected characters
3. Test filtered payloads against each parameter
4. Report any successful XSS injections

### Sample Output
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

## Key Improvements Made

### Security Fixes
- ✅ **Removed command injection vulnerabilities** - No more `subprocess` calls with user input
- ✅ **Added input validation** - URLs are properly validated before scanning
- ✅ **Safe file operations** - Using `with open()` instead of shell commands
- ✅ **Request timeouts** - Added 10-second timeout to prevent hanging
- ✅ **Thread safety** - Added locks for shared result list

### Bug Fixes
- ✅ **Fixed constructor calls** - Corrected parameter order and handling
- ✅ **Fixed empty parameter handling** - No longer exits on empty params
- ✅ **Improved error handling** - Specific exception catching instead of bare except
- ✅ **Fixed bubble sort issues** - Replaced with Python's built-in sorting
- ✅ **Thread limit enforcement** - Properly enforced max thread limit

### Code Quality Improvements
- ✅ **Built-in replacements** - No longer depends on missing custom modules
- ✅ **Fallback payloads** - Works even without payloads.json file
- ✅ **Better logging** - More informative output messages
- ✅ **Cleaner code structure** - Simplified complex functions
- ✅ **PEP 8 compliance** - Better variable naming and code formatting

### Functional Improvements
- ✅ **Enhanced WAF detection** - Simple but effective WAF fingerprinting
- ✅ **Smarter payload filtering** - Payloads filtered based on character reflection
- ✅ **Session reuse** - HTTP session reuse for better performance
- ✅ **Rate limiting protection** - Limited character testing to prevent flooding
- ✅ **Graceful degradation** - Works even if colorama is not installed

## Troubleshooting

### Common Issues

1. **"No module named 'colorama'"**
   ```bash
   pip install colorama
   ```

2. **"No valid URLs found"**
   - Ensure URLs in the file have GET parameters (contain '=' character)
   - Check URL format (must start with http:// or https://)

3. **"Connection timeout"**
   - Target site may be slow or blocking requests
   - Try reducing thread count: `-t 1`

4. **"No character reflection found"**
   - Target may be filtering/encoding input
   - Try different payloads or manual testing

5. **SSL Certificate errors**
   - SSL verification is disabled by default for testing
   - This is normal for security testing tools

### Performance Tips

- Start with single-threaded scanning (`-t 1`) for debugging
- Use 3-5 threads for balanced performance
- Large URL lists may take significant time
- Consider splitting large files into smaller batches

## Legal and Ethical Use

⚠️ **IMPORTANT**: This tool is for authorized security testing only!

- Only test systems you own or have explicit permission to test
- Respect rate limits and don't overwhelm target servers
- Follow responsible disclosure if vulnerabilities are found
- Comply with local laws and regulations

## WAF Support

The scanner can detect and adapt to common Web Application Firewalls:

- Cloudflare
- Akamai
- Incapsula
- Sucuri
- Barracuda
- F5 BIG-IP
- AWS CloudFront

When WAF is detected, the scanner automatically uses WAF-specific payloads that are more likely to bypass filtering.

## Advanced Usage

### Custom Payload Development

You can add custom payloads to `payloads.json`:

```json
{
  "Payload": "<custom>alert('test')</custom>",
  "Attribute": ["<", ">", "(", ")", "'"],
  "waf": "custom_waf_name",
  "count": 0
}
```

### Integration with Other Tools

The scanner works well with:
- **Katana** (web crawler) - pipe crawled URLs
- **Subfinder** - discover subdomains first
- **httpx** - filter live URLs before scanning
- **nuclei** - additional vulnerability scanning

Example workflow:
```bash
# Discover subdomains and crawl
subfinder -d example.com | httpx -silent | katana -silent | grep "=" | python main.py --pipe -o results.txt
```
