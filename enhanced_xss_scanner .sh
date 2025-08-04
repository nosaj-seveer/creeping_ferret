#!/bin/bash

# Enhanced XSS Scanner with Multiple Output Formats
# Version: 2.1
# Author: Security Research Team

VERSION="2.1"
SCRIPT_NAME="Enhanced XSS Scanner"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
THREADS=3
MAX_THREADS=10
TIMEOUT=10
DELAY=0
VERBOSE=false
OUTPUT_FILE=""
OUTPUT_FORMAT="txt"
USE_COLOR=true
WAF_DETECTION=false
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
PROXY=""
PIPE_MODE=false

# Arrays for results
declare -a VULNERABLE_URLS=()
declare -a SCAN_RESULTS=()

# Payload file
PAYLOAD_FILE="payloads.json"

# Usage function
usage() {
    echo -e "${CYAN}$SCRIPT_NAME v$VERSION${NC}"
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  -u URL              Scan a single URL"
    echo "  -f FILE             Scan URLs from file"
    echo "  -o FILE             Output file"
    echo "  --format FORMAT     Output format: txt, json, html (default: txt)"
    echo "  -t THREADS          Number of concurrent processes (default: 3, max: 10)"
    echo "  -H HEADER           Custom HTTP header (can be used multiple times)"
    echo "  --waf               Enable WAF detection"
    echo "  -w WAF_NAME         Use specific WAF payloads"
    echo "  --pipe              Read URLs from stdin"
    echo "  -v, --verbose       Enable verbose output"
    echo "  --timeout SECONDS   HTTP request timeout (default: 10)"
    echo "  --delay SECONDS     Delay between requests (default: 0)"
    echo "  --user-agent UA     Custom User-Agent string"
    echo "  --proxy PROXY       Use HTTP proxy (format: http://proxy:port)"
    echo "  --no-color          Disable colored output"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -u \"http://example.com/search.php?q=test\" --format html -o report.html"
    echo "  $0 -f urls.txt --format json -o results.json"
    echo "  cat urls.txt | $0 --pipe --format txt -o scan_results.txt"
    echo ""
    echo "Output Formats:"
    echo "  txt   - Plain text format (default)"
    echo "  json  - JSON format for automated processing"
    echo "  html  - HTML report with styling"
}

# Logging functions
log_info() {
    if [[ $USE_COLOR == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    else
        echo "[INFO] $1"
    fi
}

log_success() {
    if [[ $USE_COLOR == true ]]; then
        echo -e "${GREEN}[+]${NC} $1"
    else
        echo "[+] $1"
    fi
}

log_warning() {
    if [[ $USE_COLOR == true ]]; then
        echo -e "${YELLOW}[!]${NC} $1"
    else
        echo "[!] $1"
    fi
}

log_error() {
    if [[ $USE_COLOR == true ]]; then
        echo -e "${RED}[-]${NC} $1" >&2
    else
        echo "[-] $1" >&2
    fi
}

log_vuln() {
    if [[ $USE_COLOR == true ]]; then
        echo -e "${RED}[VULN]${NC} $1"
    else
        echo "[VULN] $1"
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
}

# Load payloads from JSON file
load_payloads() {
    if [[ ! -f "$PAYLOAD_FILE" ]]; then
        log_warning "Payload file not found. Creating basic payload set..."
        create_default_payloads
    fi
    
    local payload_count
    payload_count=$(jq '. | length' "$PAYLOAD_FILE" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Invalid JSON in payload file"
        exit 1
    fi
    
    log_success "Loaded $payload_count payloads from $PAYLOAD_FILE"
}

# Create default payloads if file doesn't exist
create_default_payloads() {
    cat > "$PAYLOAD_FILE" << 'EOF'
[
  {
    "Payload": "<script>alert('XSS')</script>",
    "Attribute": ["<", ">", "(", ")", "'"],
    "waf": "generic",
    "description": "Basic script tag"
  },
  {
    "Payload": "<img src=x onerror=alert('XSS')>",
    "Attribute": ["<", ">", "=", "(", ")", "'"],
    "waf": "generic", 
    "description": "Image tag with onerror"
  },
  {
    "Payload": "javascript:alert('XSS')",
    "Attribute": [":", "(", ")", "'"],
    "waf": "cloudflare",
    "description": "JavaScript protocol"
  },
  {
    "Payload": "<svg onload=alert('XSS')>",
    "Attribute": ["<", ">", "=", "(", ")", "'"],
    "waf": "generic",
    "description": "SVG with onload"
  }
]
EOF
}

# Detect WAF
detect_waf() {
    local url="$1"
    local headers
    
    headers=$(curl -s -I -m "$TIMEOUT" "$url" 2>/dev/null)
    
    if echo "$headers" | grep -qi "cloudflare"; then
        echo "cloudflare"
    elif echo "$headers" | grep -qi "akamai"; then
        echo "akamai"
    elif echo "$headers" | grep -qi "incapsula"; then
        echo "incapsula"
    elif echo "$headers" | grep -qi "sucuri"; then
        echo "sucuri"
    else
        echo "generic"
    fi
}

# Test character reflection
test_character_reflection() {
    local url="$1"
    local param="$2"
    local chars=("'" '"' '<' '>' '(' ')' '{' '}' ';' ':' '=' '&')
    local reflected_chars=()
    
    for char in "${chars[@]}"; do
        local test_url="${url//$param=*/$param=$char}"
        local response
        
        response=$(curl -s -m "$TIMEOUT" "$test_url" 2>/dev/null)
        
        if [[ "$response" == *"$char"* ]]; then
            reflected_chars+=("$char")
            [[ $VERBOSE == true ]] && log_info "Character '$char' reflected in response"
        fi
        
        sleep "$DELAY"
    done
    
    printf '%s\n' "${reflected_chars[@]}"
}

# Filter payloads based on reflected characters
filter_payloads() {
    local reflected_chars="$1"
    local waf_type="$2"
    
    if [[ -z "$reflected_chars" ]]; then
        echo "[]"
        return
    fi
    
    # Convert reflected chars to jq array format
    local chars_array="["
    while IFS= read -r char; do
        chars_array+="\"$char\","
    done <<< "$reflected_chars"
    chars_array="${chars_array%,}]"
    
    # Filter payloads
    jq --argjson reflected "$chars_array" --arg waf "$waf_type" '
        map(select(
            (.waf == $waf or .waf == "generic") and
            (.Attribute | all(. as $attr | $reflected | index($attr)))
        ))
    ' "$PAYLOAD_FILE"
}

# Test XSS payload
test_payload() {
    local url="$1"
    local param="$2"
    local payload="$3"
    local encoded_payload
    
    # URL encode the payload
    encoded_payload=$(printf '%s' "$payload" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-)
    
    # Create test URL
    local test_url="${url//$param=*/$param=$encoded_payload}"
    
    # Send request
    local response
    response=$(curl -s -m "$TIMEOUT" -A "$USER_AGENT" "$test_url" 2>/dev/null)
    
    # Check if payload is reflected unescaped
    if [[ "$response" == *"$payload"* ]]; then
        return 0
    else
        return 1
    fi
}

# Scan single URL
scan_url() {
    local url="$1"
    local params
    local waf_type="generic"
    
    log_info "Testing: $url"
    
    # Extract parameters
    if [[ "$url" != *"="* ]]; then
        log_warning "No parameters found in URL: $url"
        return
    fi
    
    # WAF detection if enabled
    if [[ $WAF_DETECTION == true ]]; then
        waf_type=$(detect_waf "$url")
        [[ $VERBOSE == true ]] && log_info "Detected WAF: $waf_type"
    fi
    
    # Extract parameter names
    params=$(echo "$url" | grep -oP '(?<=[\?&])[^=]+(?==)' | sort -u)
    
    if [[ -z "$params" ]]; then
        log_warning "No valid parameters found"
        return
    fi
    
    log_info "Parameters found: $(echo "$params" | tr '\n' ' ')"
    
    # Test each parameter
    while IFS= read -r param; do
        [[ $VERBOSE == true ]] && log_info "Testing parameter: $param"
        
        # Test character reflection
        local reflected_chars
        reflected_chars=$(test_character_reflection "$url" "$param")
        
        if [[ -z "$reflected_chars" ]]; then
            [[ $VERBOSE == true ]] && log_warning "No character reflection found for parameter: $param"
            continue
        fi
        
        # Filter payloads
        local filtered_payloads
        filtered_payloads=$(filter_payloads "$reflected_chars" "$waf_type")
        
        local payload_count
        payload_count=$(echo "$filtered_payloads" | jq '. | length')
        
        [[ $VERBOSE == true ]] && log_info "Testing $payload_count filtered payloads"
        
        # Test each payload
        while IFS= read -r payload_obj; do
            local payload description
            payload=$(echo "$payload_obj" | jq -r '.Payload')
            description=$(echo "$payload_obj" | jq -r '.description')
            
            if test_payload "$url" "$param" "$payload"; then
                local poc_url="${url//$param=*/$param=$payload}"
                log_vuln "XSS FOUND!"
                log_vuln "URL: $url"
                log_vuln "Parameter: $param"
                log_vuln "Payload: $payload"
                log_vuln "Description: $description"
                log_vuln "PoC: $poc_url"
                
                # Store result
                local result="{\"url\":\"$url\",\"parameter\":\"$param\",\"payload\":\"$payload\",\"description\":\"$description\",\"poc\":\"$poc_url\",\"timestamp\":\"$(date -Iseconds)\"}"
                SCAN_RESULTS+=("$result")
                VULNERABLE_URLS+=("$url")
                
                break # Found vulnerability, move to next parameter
            fi
            
            sleep "$DELAY"
        done < <(echo "$filtered_payloads" | jq -c '.[]')
        
    done <<< "$params"
}

# Generate TXT output
generate_txt_output() {
    local output_file="$1"
    
    {
        echo "========================================="
        echo "$SCRIPT_NAME v$VERSION - Scan Results"
        echo "========================================="
        echo "Scan Date: $(date)"
        echo "Total URLs Scanned: $TOTAL_URLS"
        echo "Vulnerable URLs Found: ${#VULNERABLE_URLS[@]}"
        echo "========================================="
        echo ""
        
        if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
            echo "No vulnerabilities found."
        else
            for result in "${SCAN_RESULTS[@]}"; do
                echo "VULNERABILITY FOUND:"
                echo "URL: $(echo "$result" | jq -r '.url')"
                echo "Parameter: $(echo "$result" | jq -r '.parameter')"
                echo "Payload: $(echo "$result" | jq -r '.payload')"
                echo "Description: $(echo "$result" | jq -r '.description')"
                echo "Proof of Concept: $(echo "$result" | jq -r '.poc')"
                echo "Timestamp: $(echo "$result" | jq -r '.timestamp')"
                echo "----------------------------------------"
                echo ""
            done
        fi
    } > "$output_file"
}

# Generate JSON output
generate_json_output() {
    local output_file="$1"
    
    {
        echo "{"
        echo "  \"scan_info\": {"
        echo "    \"scanner\": \"$SCRIPT_NAME\","
        echo "    \"version\": \"$VERSION\","
        echo "    \"scan_date\": \"$(date -Iseconds)\","
        echo "    \"total_urls_scanned\": $TOTAL_URLS,"
        echo "    \"vulnerable_urls_found\": ${#VULNERABLE_URLS[@]}"
        echo "  },"
        echo "  \"vulnerabilities\": ["
        
        local first=true
        for result in "${SCAN_RESULTS[@]}"; do
            if [[ $first == true ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "    $result"
        done
        
        echo ""
        echo "  ]"
        echo "}"
    } > "$output_file"
}

# Generate HTML output
generate_html_output() {
    local output_file="$1"
    
    {
        cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>XSS Scan Results</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            color: #333;
            border-bottom: 3px solid #e74c3c;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .summary {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            border-left: 5px solid #3498db;
        }
        .summary h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        .vulnerability {
            background: #fff5f5;
            border: 1px solid #e74c3c;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            border-left: 5px solid #e74c3c;
        }
        .vulnerability h4 {
            color: #e74c3c;
            margin-top: 0;
        }
        .field {
            margin-bottom: 10px;
        }
        .field strong {
            color: #2c3e50;
            display: inline-block;
            width: 120px;
        }
        .payload {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 10px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            word-break: break-all;
            margin: 10px 0;
        }
        .poc-link {
            background: #3498db;
            color: white;
            padding: 8px 15px;
            text-decoration: none;
            border-radius: 4px;
            display: inline-block;
            margin-top: 10px;
        }
        .poc-link:hover {
            background: #2980b9;
        }
        .no-vulns {
            text-align: center;
            color: #27ae60;
            font-size: 18px;
            padding: 40px;
            background: #d5f4e6;
            border-radius: 8px;
            border: 1px solid #27ae60;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-box {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            display: block;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
EOF
        
        echo "            <h1>$SCRIPT_NAME v$VERSION</h1>"
        echo "            <p>XSS Vulnerability Scan Report</p>"
        echo "            <p><em>Generated on $(date)</em></p>"
        
        cat << 'EOF'
        </div>
        
        <div class="stats">
            <div class="stat-box">
                <span class="stat-number">
EOF
        echo "$TOTAL_URLS"
        cat << 'EOF'
                </span>
                <span>URLs Scanned</span>
            </div>
            <div class="stat-box">
                <span class="stat-number">
EOF
        echo "${#VULNERABLE_URLS[@]}"
        cat << 'EOF'
                </span>
                <span>Vulnerabilities Found</span>
            </div>
            <div class="stat-box">
                <span class="stat-number">
EOF
        if [[ $TOTAL_URLS -gt 0 ]]; then
            echo "scale=1; ${#VULNERABLE_URLS[@]} * 100 / $TOTAL_URLS" | bc
        else
            echo "0"
        fi
        cat << 'EOF'
%</span>
                <span>Success Rate</span>
            </div>
        </div>
        
        <div class="summary">
            <h3>Scan Summary</h3>
            <p><strong>Scanner:</strong> Enhanced XSS Scanner</p>
            <p><strong>Version:</strong> 
EOF
        echo "$VERSION"
        echo "            <p><strong>Total URLs Scanned:</strong> $TOTAL_URLS</p>"
        echo "            <p><strong>Vulnerable URLs:</strong> ${#VULNERABLE_URLS[@]}</p>"
        echo "            <p><strong>Scan Date:</strong> $(date)</p>"
        
        cat << 'EOF'
        </div>
        
        <h2>Vulnerability Details</h2>
EOF
        
        if [[ ${#SCAN_RESULTS[@]} -eq 0 ]]; then
            cat << 'EOF'
        <div class="no-vulns">
            <h3>🎉 No XSS vulnerabilities found!</h3>
            <p>All tested URLs appear to be secure against XSS attacks.</p>
        </div>
EOF
        else
            local count=1
            for result in "${SCAN_RESULTS[@]}"; do
                local url=$(echo "$result" | jq -r '.url')
                local parameter=$(echo "$result" | jq -r '.parameter')
                local payload=$(echo "$result" | jq -r '.payload')
                local description=$(echo "$result" | jq -r '.description')
                local poc=$(echo "$result" | jq -r '.poc')
                local timestamp=$(echo "$result" | jq -r '.timestamp')
                
                echo "        <div class=\"vulnerability\">"
                echo "            <h4>🚨 Vulnerability #$count</h4>"
                echo "            <div class=\"field\"><strong>URL:</strong> $url</div>"
                echo "            <div class=\"field\"><strong>Parameter:</strong> $parameter</div>"
                echo "            <div class=\"field\"><strong>Description:</strong> $description</div>"
                echo "            <div class=\"field\"><strong>Payload:</strong></div>"
                echo "            <div class=\"payload\">$(echo "$payload" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</div>"
                echo "            <div class=\"field\"><strong>Timestamp:</strong> $timestamp</div>"
                echo "            <a href=\"$(echo "$poc" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')\" class=\"poc-link\" target=\"_blank\">View Proof of Concept</a>"
                echo "        </div>"
                
                ((count++))
            done
        fi
        
        cat << 'EOF'
        
        <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #666;">
            <p>Report generated by Enhanced XSS Scanner - Use for authorized security testing only</p>
        </div>
    </div>
</body>
</html>
EOF
    } > "$output_file"
}

# Output results
output_results() {
    if [[ -z "$OUTPUT_FILE" ]]; then
        return
    fi
    
    case "$OUTPUT_FORMAT" in
        "txt")
            generate_txt_output "$OUTPUT_FILE"
            log_success "Results saved to $OUTPUT_FILE (TXT format)"
            ;;
        "json")
            generate_json_output "$OUTPUT_FILE"
            log_success "Results saved to $OUTPUT_FILE (JSON format)"
            ;;
        "html")
            generate_html_output "$OUTPUT_FILE"
            log_success "Results saved to $OUTPUT_FILE (HTML format)"
            ;;
        *)
            log_error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
}

# Main function
main() {
    local urls=()
    local single_url=""
    local url_file=""
    local custom_headers=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u)
                single_url="$2"
                shift 2
                ;;
            -f)
                url_file="$2"
                shift 2
                ;;
            -o)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -t)
                THREADS="$2"
                if [[ $THREADS -gt $MAX_THREADS ]]; then
                    THREADS=$MAX_THREADS
                    log_warning "Thread count limited to $MAX_THREADS"
                fi
                shift 2
                ;;
            -H)
                custom_headers+=("$2")
                shift 2
                ;;
            --waf)
                WAF_DETECTION=true
                shift
                ;;
            --pipe)
                PIPE_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --delay)
                DELAY="$2"
                shift 2
                ;;
            --user-agent)
                USER_AGENT="$2"
                shift 2
                ;;
            --no-color)
                USE_COLOR=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(txt|json|html)$ ]]; then
        log_error "Invalid output format: $OUTPUT_FORMAT. Supported formats: txt, json, html"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Load payloads
    load_payloads
    
    # Collect URLs
    if [[ $PIPE_MODE == true ]]; then
        while IFS= read -r line; do
            [[ -n "$line" && "$line" == *"="* ]] && urls+=("$line")
        done
    elif [[ -n "$single_url" ]]; then
        urls+=("$single_url")
    elif [[ -n "$url_file" ]]; then
        if [[ ! -f "$url_file" ]]; then
            log_error "URL file not found: $url_file"
            exit 1
        fi
        while IFS= read -r line; do
            [[ -n "$line" && "$line" == *"="* ]] && urls+=("$line")
        done < "$url_file"
    else
        log_error "No URLs provided. Use -u, -f, or --pipe"
        usage
        exit 1
    fi
    
    if [[ ${#urls[@]} -eq 0 ]]; then
        log_error "No valid URLs found with parameters"
        exit 1
    fi
    
    TOTAL_URLS=${#urls[@]}
    
    # Print banner
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$SCRIPT_NAME v$VERSION${NC}"
    echo -e "${CYAN}========================================${NC}"
    log_success "Scanning $TOTAL_URLS URLs"
    [[ $OUTPUT_FORMAT != "txt" ]] && log_info "Output format: $OUTPUT_FORMAT"
    [[ -n "$OUTPUT_FILE" ]] && log_info "Output file: $OUTPUT_FILE"
    
    # Scan URLs
    for url in "${urls[@]}"; do
        scan_url "$url"
    done
    
    # Output results
    output_results
    
    # Summary
    echo -e "${CYAN}========================================${NC}"
    log_success "Scan completed: ${#VULNERABLE_URLS[@]}/$TOTAL_URLS URLs vulnerable"
    echo -e "${CYAN}========================================${NC}"
}

# Run main function
main "$@"