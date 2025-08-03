#!/bin/bash

# XSS Scanner with Katana & ParamSpider Integration
# Usage: ./crawl_and_scan.sh [verbosity_level] [target_url]
# Verbosity: 0=Silent, 1=Verbose (default), 2=Debug

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Verbosity levels: 0=Silent, 1=Verbose, 2=Debug
VERBOSITY=${1:-1}

# Logging functions
log_silent() {
    if [ $VERBOSITY -ge 0 ]; then
        echo -e "$1"
    fi
}

log_verbose() {
    if [ $VERBOSITY -ge 1 ]; then
        echo -e "$1"
    fi
}

log_debug() {
    if [ $VERBOSITY -ge 2 ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Function to prompt for continuation
prompt_continue() {
    local message="$1"
    if [ $VERBOSITY -ge 1 ]; then
        echo ""
        echo -e "${YELLOW}$message${NC}"
        read -p "Continue? (Y/n): " continue_choice
        continue_choice=${continue_choice:-Y}
        if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
            log_silent "${BLUE}Scan stopped by user${NC}"
            exit 0
        fi
    fi
}

# Function to extract domain from URL
extract_domain() {
    local url="$1"
    echo "$url" | sed -E 's|https?://||' | sed -E 's|/.*||' | sed -E 's|:.*||'
}

# Show banner only in verbose/debug mode
if [ $VERBOSITY -ge 1 ]; then
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}    XSS Scanner with Multi-Tool Crawler${NC}"
    echo -e "${BLUE}    Katana + ParamSpider Integration${NC}"
    echo -e "${BLUE}    Verbosity Level: $VERBOSITY${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo ""
fi

log_debug "Script started with verbosity level: $VERBOSITY"

# Check if required tools are installed
log_debug "Checking for required tools..."

# Check katana
if ! command -v katana &> /dev/null; then
    log_silent "${RED}Error: katana is not installed or not in PATH${NC}"
    log_silent "${YELLOW}Install katana with: go install github.com/projectdiscovery/katana/cmd/katana@latest${NC}"
    exit 1
fi
log_debug "✓ katana found: $(which katana)"

# Check paramspider
if ! command -v paramspider &> /dev/null; then
    log_silent "${RED}Error: paramspider is not installed or not in PATH${NC}"
    log_silent "${YELLOW}Install paramspider with: pip3 install paramspider${NC}"
    log_silent "${YELLOW}Or from source: git clone https://github.com/devanshbatham/ParamSpider${NC}"
    exit 1
fi
log_debug "✓ paramspider found: $(which paramspider)"

# Check if main.py exists
log_debug "Checking for main.py..."
if [ ! -f "main.py" ]; then
    log_silent "${RED}Error: main.py not found in current directory${NC}"
    exit 1
fi
log_debug "✓ main.py found: $(pwd)/main.py"

# Get target URL from user
if [ $VERBOSITY -ge 1 ]; then
    echo -e "${GREEN}Enter the target URL to scan:${NC}"
    read -p "URL: " target_url
else
    # Silent mode - get URL from command line or prompt once
    if [ -z "$2" ]; then
        read -p "URL: " target_url
    else
        target_url="$2"
    fi
fi

log_debug "User input URL: $target_url"

# Validate URL format
if [[ ! $target_url =~ ^https?:// ]]; then
    log_silent "${RED}Error: Please enter a valid URL starting with http:// or https://${NC}"
    exit 1
fi

# Extract domain for ParamSpider
target_domain=$(extract_domain "$target_url")
log_verbose "${BLUE}Target URL: ${target_url}${NC}"
log_verbose "${BLUE}Target Domain: ${target_domain}${NC}"
log_debug "URL validation passed, domain extracted: $target_domain"

# Ask which crawlers to use
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}      CRAWLER SELECTION${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
    echo -e "${GREEN}Select crawling method:${NC}"
    echo -e "${YELLOW}1. Katana only (fast web crawling)${NC}"
    echo -e "${YELLOW}2. ParamSpider only (archive-based discovery)${NC}"
    echo -e "${YELLOW}3. Both Katana + ParamSpider (recommended)${NC}"
    echo -e "${YELLOW}4. ParamSpider first, then Katana${NC}"
    read -p "Choose option (1-4, default: 3): " crawler_choice
    crawler_choice=${crawler_choice:-3}
else
    crawler_choice=3  # Default to both crawlers in silent mode
fi

log_debug "Crawler choice selected: $crawler_choice"

# Validate crawler choice
if ! [[ "$crawler_choice" =~ ^[1-4]$ ]]; then
    log_verbose "${YELLOW}Invalid choice, using default: Both crawlers${NC}"
    crawler_choice=3
fi

# Clean up previous results
log_verbose "${BLUE}Cleaning up previous results...${NC}"
log_debug "Removing old result files"
rm -f katana.txt paramspider.txt combined.txt xss.txt
rm -rf results/  # ParamSpider creates a results directory

# Initialize flags for what to run
run_katana=false
run_paramspider=false
paramspider_first=false

case $crawler_choice in
    1)
        run_katana=true
        log_verbose "${BLUE}Selected: Katana crawler only${NC}"
        ;;
    2)
        run_paramspider=true
        log_verbose "${BLUE}Selected: ParamSpider only${NC}"
        ;;
    3)
        run_katana=true
        run_paramspider=true
        log_verbose "${BLUE}Selected: Both Katana + ParamSpider${NC}"
        ;;
    4)
        run_katana=true
        run_paramspider=true
        paramspider_first=true
        log_verbose "${BLUE}Selected: ParamSpider first, then Katana${NC}"
        ;;
esac

# Function to run ParamSpider
run_paramspider_scan() {
    log_verbose "${ORANGE}Starting parameter discovery with ParamSpider...${NC}"
    
    # Ask for ParamSpider options in verbose mode
    local paramspider_options=""
    if [ $VERBOSITY -ge 1 ]; then
        echo -e "${GREEN}ParamSpider options:${NC}"
        echo -e "${YELLOW}  -l <level>  : Level of extraction (1-3, default: 1)${NC}"
        echo -e "${YELLOW}  -e <ext>    : Extensions to exclude (e.g., css,js,png)${NC}"
        echo -e "${YELLOW}  -o <output> : Output format (json/simple, default: simple)${NC}"
        read -p "Additional ParamSpider options (press Enter for defaults): " paramspider_options
    fi
    
    # Build ParamSpider command
    local paramspider_cmd="paramspider -d \"$target_domain\" $paramspider_options"
    
    if [ $VERBOSITY -ge 1 ]; then
        log_verbose "${YELLOW}Command: $paramspider_cmd${NC}"
        echo ""
    fi
    log_debug "Executing ParamSpider: $paramspider_cmd"
    
    # Run ParamSpider
    if [ $VERBOSITY -eq 0 ]; then
        eval $paramspider_cmd > /dev/null 2>&1
    else
        eval $paramspider_cmd
    fi
    
    # ParamSpider creates results in results/ directory
    local paramspider_result_file="results/${target_domain}.txt"
    
    if [ -f "$paramspider_result_file" ]; then
        cp "$paramspider_result_file" paramspider.txt
        local param_count=$(wc -l < paramspider.txt)
        log_verbose "${GREEN}✓ ParamSpider completed: $param_count URLs found${NC}"
        log_debug "ParamSpider found $param_count URLs"
        
        # Show sample URLs
        if [ $VERBOSITY -ge 1 ] && [ $param_count -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Sample ParamSpider URLs:${NC}"
            head -3 paramspider.txt | while read line; do
                echo -e "${ORANGE}  🕷️  $line${NC}"
            done
            if [ $param_count -gt 3 ]; then
                echo -e "${YELLOW}  ... and $(($param_count - 3)) more${NC}"
            fi
        fi
    else
        log_verbose "${YELLOW}⚠️  ParamSpider didn't generate expected output file${NC}"
        log_debug "Expected file not found: $paramspider_result_file"
        touch paramspider.txt  # Create empty file to avoid errors
    fi
}

# Function to run Katana
run_katana_scan() {
    log_verbose "${BLUE}Starting web crawling with Katana...${NC}"
    
    # Ask for crawl depth
    local crawl_depth=2
    if [ $VERBOSITY -ge 1 ]; then
        echo -e "${GREEN}Enter crawl depth (1-5, default: 2):${NC}"
        read -p "Depth: " crawl_depth
    fi
    crawl_depth=${crawl_depth:-2}
    log_debug "Crawl depth set to: $crawl_depth"
    
    # Validate depth
    if ! [[ "$crawl_depth" =~ ^[1-5]$ ]]; then
        log_verbose "${YELLOW}Invalid depth, using default: 2${NC}"
        crawl_depth=2
    fi
    
    # Ask for additional katana options
    local katana_options=""
    if [ $VERBOSITY -ge 1 ]; then
        echo -e "${GREEN}Additional katana options (optional, press Enter to skip):${NC}"
        echo -e "${YELLOW}Examples: -jc (JavaScript crawling), -aff (all file formats)${NC}"
        read -p "Options: " katana_options
    else
        katana_options="-silent"  # Default silent options for katana
    fi
    
    log_debug "Katana options: $katana_options"
    
    # Build katana command
    local katana_cmd="katana -u \"$target_url\" -d $crawl_depth $katana_options -o katana.txt"
    
    if [ $VERBOSITY -ge 1 ]; then
        log_verbose "${YELLOW}Command: $katana_cmd${NC}"
        echo ""
    fi
    log_debug "Executing Katana: $katana_cmd"
    
    # Run katana crawler
    if eval $katana_cmd; then
        local katana_count=$(wc -l < katana.txt 2>/dev/null || echo 0)
        log_verbose "${GREEN}✓ Katana completed: $katana_count URLs found${NC}"
        log_debug "Katana found $katana_count URLs"
        
        # Show sample URLs
        if [ $VERBOSITY -ge 1 ] && [ $katana_count -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Sample Katana URLs:${NC}"
            head -3 katana.txt | while read line; do
                echo -e "${BLUE}  🌐 $line${NC}"
            done
            if [ $katana_count -gt 3 ]; then
                echo -e "${YELLOW}  ... and $(($katana_count - 3)) more${NC}"
            fi
        fi
    else
        log_silent "${RED}✗ Katana crawling failed${NC}"
        log_debug "Katana exit code: $?"
        touch katana.txt  # Create empty file to avoid errors
    fi
}

# Execute crawlers based on selection
if [ "$paramspider_first" = true ]; then
    # Run ParamSpider first, then Katana
    run_paramspider_scan
    prompt_continue "ParamSpider completed. Ready to run Katana?"
    run_katana_scan
elif [ "$run_paramspider" = true ] && [ "$run_katana" = true ]; then
    # Run both simultaneously (original order)
    run_katana_scan
    prompt_continue "Katana completed. Ready to run ParamSpider?"
    run_paramspider_scan
elif [ "$run_katana" = true ]; then
    # Katana only
    run_katana_scan
elif [ "$run_paramspider" = true ]; then
    # ParamSpider only
    run_paramspider_scan
fi

# Combine results from multiple crawlers
log_verbose "${PURPLE}Combining and processing crawler results...${NC}"
log_debug "Combining results from available crawlers"

# Create combined file
touch combined.txt

# Add Katana results if available
if [ -f katana.txt ] && [ -s katana.txt ]; then
    cat katana.txt >> combined.txt
    katana_count=$(wc -l < katana.txt)
    log_debug "Added $katana_count URLs from Katana"
fi

# Add ParamSpider results if available
if [ -f paramspider.txt ] && [ -s paramspider.txt ]; then
    cat paramspider.txt >> combined.txt
    paramspider_count=$(wc -l < paramspider.txt)
    log_debug "Added $paramspider_count URLs from ParamSpider"
fi

# Remove duplicates and empty lines
if [ -s combined.txt ]; then
    sort combined.txt | uniq > combined_unique.txt
    mv combined_unique.txt combined.txt
    total_unique=$(wc -l < combined.txt)
    log_verbose "${GREEN}✓ Combined results: $total_unique unique URLs${NC}"
    log_debug "Total unique URLs after deduplication: $total_unique"
else
    log_silent "${RED}No URLs found by any crawler. Check your target URL and try again.${NC}"
    log_debug "No URLs found by crawlers"
    exit 1
fi

# Show crawler statistics
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}        CRAWLER STATISTICS${NC}"
    echo -e "${PURPLE}======================================${NC}"
    
    if [ -f katana.txt ]; then
        katana_count=$(wc -l < katana.txt 2>/dev/null || echo 0)
        echo -e "${BLUE}🌐 Katana URLs: $katana_count${NC}"
    fi
    
    if [ -f paramspider.txt ]; then
        paramspider_count=$(wc -l < paramspider.txt 2>/dev/null || echo 0)
        echo -e "${ORANGE}🕷️  ParamSpider URLs: $paramspider_count${NC}"
    fi
    
    echo -e "${GREEN}🔗 Total Unique URLs: $total_unique${NC}"
    echo ""
fi

prompt_continue "URL discovery completed. Ready to filter for parameters?"

# Filter URLs with parameters only
log_verbose "${BLUE}Filtering URLs with GET parameters...${NC}"
log_debug "Filtering URLs containing '=' character"
grep "=" combined.txt > filtered_params.txt 2>/dev/null || true

if [ ! -s filtered_params.txt ]; then
    log_verbose "${YELLOW}Warning: No URLs with GET parameters found${NC}"
    log_verbose "${BLUE}Total URLs found: $total_unique${NC}"
    log_verbose "${BLUE}URLs with parameters: 0${NC}"
    
    if [ $VERBOSITY -ge 1 ]; then
        echo ""
        echo -e "${YELLOW}Sample URLs found:${NC}"
        head -5 combined.txt
        echo ""
        echo -e "${YELLOW}Do you want to continue anyway? (y/N):${NC}"
        read -p "Continue: " continue_scan
        if [[ ! $continue_scan =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Scan cancelled by user${NC}"
            exit 0
        fi
    else
        log_silent "${YELLOW}No URLs with parameters found, continuing with all URLs${NC}"
    fi
    # Use all URLs if no parameters found
    cp combined.txt filtered_params.txt
    log_debug "Using all URLs since no parameters found"
else
    log_debug "Filtered to URLs with parameters"
fi

param_urls=$(wc -l < filtered_params.txt)
log_verbose "${GREEN}✓ Found $param_urls URLs with potential XSS parameters${NC}"
log_debug "URLs to be tested: $param_urls"

# Use filtered results as final input
mv filtered_params.txt final_urls.txt

# Show sample URLs to be tested
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${BLUE}Sample URLs to be tested:${NC}"
    head -3 final_urls.txt | while read line; do
        echo -e "${YELLOW}  🎯 $line${NC}"
    done
    if [ $param_urls -gt 3 ]; then
        echo -e "${YELLOW}  ... and $(($param_urls - 3)) more${NC}"
    fi
    echo ""
fi

# Prompt before starting scan configuration
prompt_continue "URL filtering completed. Ready to configure XSS scanning options?"

# Ask for scan options
scanner_cmd="python3 main.py -f final_urls.txt -o xss.txt"

if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}       XSS SCANNER CONFIGURATION${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
    
    echo -e "${GREEN}XSS Scanner Options:${NC}"
    echo -e "${YELLOW}1. Basic scan${NC}"
    echo -e "${YELLOW}2. With WAF detection${NC}"
    echo -e "${YELLOW}3. Custom threads${NC}"
    echo -e "${YELLOW}4. Advanced options (cookies, specific params)${NC}"
    echo -e "${YELLOW}5. Full custom configuration${NC}"
    read -p "Choose option (1-5, default: 1): " scan_option
    scan_option=${scan_option:-1}
else
    scan_option=1  # Default to basic scan in silent mode
fi

log_debug "Scan option selected: $scan_option"

# Initialize additional options
attack_cookie=""
attack_param=""
custom_options=""

# Build scanner command based on verbosity and options
case $scan_option in
    2)
        scanner_cmd="$scanner_cmd --waf"
        log_verbose "${BLUE}Enabled: WAF detection${NC}"
        log_debug "Added --waf flag"
        ;;
    3)
        if [ $VERBOSITY -ge 1 ]; then
            read -p "Number of threads (1-10, default: 5): " threads
        else
            threads=5
        fi
        threads=${threads:-5}
        if [[ "$threads" =~ ^[1-9]$|^10$ ]]; then
            scanner_cmd="$scanner_cmd -t $threads"
            log_verbose "${BLUE}Using $threads threads${NC}"
            log_debug "Set threads to: $threads"
        else
            log_verbose "${YELLOW}Invalid thread count, using default${NC}"
            log_debug "Invalid thread count provided: $threads"
        fi
        ;;
    4)
        echo ""
        echo -e "${CYAN}Advanced Attack Configuration:${NC}"
        echo ""
        
        # Cookie attack option
        echo -e "${GREEN}Cookie Attack Configuration:${NC}"
        read -p "Attack specific cookie? (y/N): " attack_cookie_choice
        if [[ $attack_cookie_choice =~ ^[Yy]$ ]]; then
            read -p "Enter cookie name to attack: " attack_cookie
            if [ ! -z "$attack_cookie" ]; then
                scanner_cmd="$scanner_cmd -attackcookie \"$attack_cookie\""
                log_verbose "${BLUE}Will attack cookie: $attack_cookie${NC}"
                log_debug "Added cookie attack for: $attack_cookie"
            fi
        fi
        
        echo ""
        # Parameter attack option
        echo -e "${GREEN}Parameter Attack Configuration:${NC}"
        read -p "Attack specific GET parameter? (y/N): " attack_param_choice
        if [[ $attack_param_choice =~ ^[Yy]$ ]]; then
            read -p "Enter parameter name to attack: " attack_param
            if [ ! -z "$attack_param" ]; then
                scanner_cmd="$scanner_cmd -param \"$attack_param\""
                log_verbose "${BLUE}Will attack parameter: $attack_param${NC}"
                log_debug "Added parameter attack for: $attack_param"
            fi
        fi
        
        echo ""
        # WAF detection option
        read -p "Enable WAF detection? (y/N): " waf_choice
        if [[ $waf_choice =~ ^[Yy]$ ]]; then
            scanner_cmd="$scanner_cmd --waf"
            log_verbose "${BLUE}Enabled: WAF detection${NC}"
            log_debug "Added --waf flag"
        fi
        
        # Threads option
        read -p "Custom thread count (1-10, default: 5): " threads
        threads=${threads:-5}
        if [[ "$threads" =~ ^[1-9]$|^10$ ]]; then
            scanner_cmd="$scanner_cmd -t $threads"
            log_verbose "${BLUE}Using $threads threads${NC}"
            log_debug "Set threads to: $threads"
        fi
        ;;
    5)
        echo ""
        echo -e "${CYAN}Full Custom Configuration:${NC}"
        echo -e "${YELLOW}Available options:${NC}"
        echo -e "${YELLOW}  --waf                    : Enable WAF detection${NC}"
        echo -e "${YELLOW}  -t <threads>            : Number of threads (1-10)${NC}"
        echo -e "${YELLOW}  -H <headers>            : Custom headers${NC}"
        echo -e "${YELLOW}  -attackcookie <name>    : Attack specific cookie${NC}"
        echo -e "${YELLOW}  -param <name>           : Attack specific parameter${NC}"
        echo ""
        read -p "Enter custom options: " custom_options
        if [ ! -z "$custom_options" ]; then
            scanner_cmd="$scanner_cmd $custom_options"
            log_debug "Custom options added: $custom_options"
        fi
        ;;
esac

# Show final configuration and prompt to continue
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}         SCAN CONFIGURATION${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${BLUE}Target URLs: $param_urls${NC}"
    echo -e "${BLUE}Scanner Command: ${scanner_cmd}${NC}"
    if [ ! -z "$attack_cookie" ]; then
        echo -e "${BLUE}Cookie Target: $attack_cookie${NC}"
    fi
    if [ ! -z "$attack_param" ]; then
        echo -e "${BLUE}Parameter Target: $attack_param${NC}"
    fi
    echo ""
fi

prompt_continue "Configuration complete. Ready to start XSS scanning?"

# Add verbosity control to scanner based on script verbosity
if [ $VERBOSITY -eq 0 ]; then
    # For silent mode, we'll redirect output
    scanner_cmd="$scanner_cmd > /dev/null 2>&1"
    log_debug "Scanner will run in silent mode"
elif [ $VERBOSITY -eq 2 ]; then
    # Debug mode - keep all output
    log_debug "Scanner will run with full output"
fi

log_verbose "${BLUE}Starting XSS scan...${NC}"
if [ $VERBOSITY -ge 1 ]; then
    log_verbose "${YELLOW}Command: $scanner_cmd${NC}"
    echo ""
fi
log_debug "Executing scanner: $scanner_cmd"

# Run XSS scanner with progress indication
if [ $VERBOSITY -ge 1 ]; then
    echo -e "${CYAN}🔍 Scanning in progress...${NC}"
    echo -e "${CYAN}(This may take several minutes depending on the number of URLs)${NC}"
    echo ""
fi

if eval $scanner_cmd; then
    log_verbose "${GREEN}✓ XSS scan completed${NC}"
    log_debug "Scanner exit code: 0"
else
    scan_exit_code=$?
    log_silent "${RED}✗ XSS scan failed with exit code: $scan_exit_code${NC}"
    log_debug "Scanner exit code: $scan_exit_code"
    
    # Prompt to continue even if scanner failed
    if [ $VERBOSITY -ge 1 ]; then
        echo ""
        read -p "Scanner failed. Check results anyway? (Y/n): " check_results
        check_results=${check_results:-Y}
        if [[ ! $check_results =~ ^[Yy]$ ]]; then
            exit $scan_exit_code
        fi
    else
        exit $scan_exit_code
    fi
fi

# Prompt before showing results
prompt_continue "Scanning completed. Ready to view results?"

# Show results
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}           SCAN RESULTS${NC}"
    echo -e "${BLUE}======================================${NC}"
fi

log_debug "Checking results in xss.txt"
if [ -f xss.txt ] && [ -s xss.txt ]; then
    vuln_count=$(wc -l < xss.txt)
    log_silent "${RED}🚨 VULNERABILITIES FOUND:${NC}"
    log_silent "${GREEN}Total vulnerable URLs: $vuln_count${NC}"
    
    if [ $VERBOSITY -eq 0 ]; then
        # Silent mode - just show count
        log_silent "Vulnerable URLs saved to xss.txt"
    elif [ $VERBOSITY -eq 1 ]; then
        # Verbose mode - show first few URLs
        echo ""
        log_verbose "${YELLOW}First 5 vulnerable URLs:${NC}"
        head -5 xss.txt | while read vuln_url; do
            echo -e "${RED}  ⚠️  $vuln_url${NC}"
        done
        if [ $vuln_count -gt 5 ]; then
            echo -e "${YELLOW}  ... and $(($vuln_count - 5)) more (check xss.txt)${NC}"
        fi
        
        # Prompt to show more results
        if [ $vuln_count -gt 5 ]; then
            echo ""
            read -p "Show all vulnerable URLs? (y/N): " show_all
            if [[ $show_all =~ ^[Yy]$ ]]; then
                echo ""
                echo -e "${YELLOW}All vulnerable URLs:${NC}"
                cat xss.txt | while read vuln_url; do
                    echo -e "${RED}  ⚠️  $vuln_url${NC}"
                done
            fi
        fi
    else
        # Debug mode - show all URLs
        echo ""
        log_debug "All vulnerable URLs:"
        cat xss.txt | while read vuln_url; do
            echo -e "${RED}  ⚠️  $vuln_url${NC}"
        done
    fi
    
    log_debug "Found $vuln_count vulnerabilities"
else
    log_silent "${GREEN}✅ No XSS vulnerabilities found${NC}"
    log_debug "No vulnerabilities detected"
fi

# File summary
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}           FILE SUMMARY${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    if [ -f katana.txt ]; then
        katana_count=$(wc -l < katana.txt 2>/dev/null || echo 0)
        echo -e "${BLUE}  🌐 katana.txt - $katana_count URLs${NC}"
    fi
    
    if [ -f paramspider.txt ]; then
        paramspider_count=$(wc -l < paramspider.txt 2>/dev/null || echo 0)
        echo -e "${ORANGE}  🕷️  paramspider.txt - $paramspider_count URLs${NC}"
    fi
    
    if [ -f combined.txt ]; then
        combined_count=$(wc -l < combined.txt 2>/dev/null || echo 0)
        echo -e "${PURPLE}  🔗 combined.txt - $combined_count unique URLs${NC}"
    fi
    
    echo -e "${YELLOW}  🎯 final_urls.txt - $param_urls URLs tested${NC}"
    
    if [ -f xss.txt ]; then
        vuln_count=$(wc -l < xss.txt 2>/dev/null || echo 0)
        if [ $vuln_count -gt 0 ]; then
            echo -e "${RED}  🚨 xss.txt - $vuln_count vulnerabilities${NC}"
        else
            echo -e "${GREEN}  ✅ xss.txt - No vulnerabilities${NC}"
        fi
    fi
    
    # Final action prompt
    echo ""
    echo -e "${GREEN}Scan Actions:${NC}"
    echo -e "${YELLOW}1. View crawler results: ls -la *.txt${NC}"
    if [ -f xss.txt ] && [ -s xss.txt ]; then
        echo -e "${YELLOW}2. View XSS results: cat xss.txt${NC}"
        echo -e "${YELLOW}3. Copy results: cp xss.txt ~/Desktop/xss_results_$(date +%Y%m%d_%H%M%S).txt${NC}"
    fi
    echo -e "${YELLOW}4. Clean up: rm -f *.txt results/${NC}"
    echo ""
fi

log_debug "Script execution completed"
log_silent "${BLUE}🎯 Multi-crawler XSS scan completed successfully!${NC}"

# Final prompt for additional actions
if [ $VERBOSITY -ge 1 ]; then
    echo ""
    read -p "Run another scan? (y/N): " run_again
    if [[ $run_again =~ ^[Yy]$ ]]; then
        echo ""
        log_verbose "${CYAN}Restarting scanner...${NC}"
        exec "$0" "$VERBOSITY"
    fi
    
    echo ""
    read -p "Clean up temporary files? (y/N): " cleanup
    if [[ $cleanup =~ ^[Yy]$ ]]; then
        log_verbose "${CYAN}Cleaning up temporary files...${NC}"
        rm -f katana.txt paramspider.txt combined.txt final_urls.txt
        rm -rf results/
        log_verbose "${GREEN}✓ Cleanup completed${NC}"
    fi
fi