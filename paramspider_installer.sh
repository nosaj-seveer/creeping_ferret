#!/bin/bash

# ParamSpider Auto-Installer for Ubuntu (Modern Versions)
# Handles externally-managed-environment issues in Ubuntu 22.04+
# Usage: ./install_paramspider.sh [installation_method]
# Methods: pipx, venv, source, force

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Installation methods
INSTALL_METHOD=${1:-"auto"}

# Display banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   ParamSpider Auto-Installer for Ubuntu${NC}"
echo -e "${BLUE}   Handles externally-managed environments${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to display status
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Function to check if externally managed environment exists
check_externally_managed() {
    if [ -f "/usr/lib/python3*/EXTERNALLY-MANAGED" ] 2>/dev/null || 
       python3 -c "import sys; exit(0 if sys.version_info >= (3,11) else 1)" 2>/dev/null; then
        return 0  # Externally managed
    else
        return 1  # Not externally managed
    fi
}

# Function to test ParamSpider installation
test_paramspider() {
    log_info "Testing ParamSpider installation..."
    
    if command_exists paramspider; then
        local version_output
        version_output=$(paramspider --help 2>&1 | head -n 5)
        if [ $? -eq 0 ]; then
            log_success "ParamSpider is working correctly!"
            echo -e "${GREEN}Command: paramspider --help${NC}"
            echo -e "${YELLOW}$version_output${NC}"
            return 0
        else
            log_error "ParamSpider command exists but not working properly"
            return 1
        fi
    else
        log_error "ParamSpider command not found in PATH"
        return 1
    fi
}

# Function to install via pipx (Recommended for GitHub packages)
install_via_pipx() {
    log_info "Installing ParamSpider via pipx from GitHub..."
    
    # Check if pipx is installed
    if ! command_exists pipx; then
        log_info "Installing pipx..."
        sudo apt update
        sudo apt install -y pipx
        
        # Ensure pipx is in PATH
        pipx ensurepath
        
        # Source the new PATH
        if [ -f ~/.bashrc ]; then
            export PATH="$HOME/.local/bin:$PATH"
        fi
        
        log_success "pipx installed successfully"
    else
        log_info "pipx is already installed"
    fi
    
    # Install ParamSpider from GitHub
    log_info "Installing ParamSpider from GitHub with pipx..."
    pipx install git+https://github.com/devanshbatham/ParamSpider.git
    
    # Ensure PATH is updated
    pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"
    
    log_success "ParamSpider installed via pipx from GitHub"
    return 0
}

# Function to install via virtual environment
install_via_venv() {
    log_info "Installing ParamSpider via virtual environment..."
    
    local venv_dir="$HOME/.security-tools-venv"
    
    # Create virtual environment
    log_info "Creating virtual environment at $venv_dir..."
    python3 -m venv "$venv_dir"
    
    # Activate virtual environment and install from GitHub
    log_info "Installing ParamSpider from GitHub in virtual environment..."
    source "$venv_dir/bin/activate"
    pip install git+https://github.com/devanshbatham/ParamSpider.git
    deactivate
    
    # Create global symlink
    log_info "Creating global symlink..."
    sudo ln -sf "$venv_dir/bin/paramspider" /usr/local/bin/paramspider
    
    # Make it executable
    sudo chmod +x /usr/local/bin/paramspider
    
    log_success "ParamSpider installed via virtual environment"
    return 0
}

# Function to install from source
install_from_source() {
    log_info "Installing ParamSpider from source..."
    
    local install_dir="$HOME/security-tools"
    local paramspider_dir="$install_dir/ParamSpider"
    
    # Create tools directory
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Clone repository
    log_info "Cloning ParamSpider repository..."
    if [ -d "ParamSpider" ]; then
        log_warning "ParamSpider directory exists, updating..."
        cd ParamSpider
        git pull
    else
        git clone https://github.com/devanshbatham/ParamSpider.git
        cd ParamSpider
    fi
    
    # Create virtual environment for dependencies
    log_info "Setting up dependencies..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    deactivate
    
    # Create wrapper script
    log_info "Creating wrapper script..."
    cat > paramspider_wrapper.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/venv/bin/activate"
python3 "$SCRIPT_DIR/paramspider.py" "$@"
deactivate
EOF
    
    chmod +x paramspider_wrapper.sh
    
    # Create global symlink
    sudo ln -sf "$paramspider_dir/paramspider_wrapper.sh" /usr/local/bin/paramspider
    
    log_success "ParamSpider installed from source"
    return 0
}

# Function to force install (not recommended)
install_force() {
    log_warning "Using force installation method (not recommended)..."
    log_warning "This may break your system Python environment!"
    
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
    
    log_info "Force installing ParamSpider from GitHub..."
    pip3 install git+https://github.com/devanshbatham/ParamSpider.git --break-system-packages
    
    log_success "ParamSpider force installed"
    return 0
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on Ubuntu
    if ! command_exists lsb_release || ! lsb_release -d | grep -q "Ubuntu"; then
        log_warning "This script is designed for Ubuntu, but will attempt to continue..."
    fi
    
    # Check Python 3
    if ! command_exists python3; then
        log_error "Python 3 is not installed"
        log_info "Installing Python 3..."
        sudo apt update
        sudo apt install -y python3 python3-pip python3-venv
    else
        log_success "Python 3 is available: $(python3 --version)"
    fi
    
    # Check git (needed for source installation)
    if ! command_exists git; then
        log_info "Installing git..."
        sudo apt update
        sudo apt install -y git
    fi
    
    # Check pip
    if ! python3 -m pip --version >/dev/null 2>&1; then
        log_info "Installing pip..."
        sudo apt update
        sudo apt install -y python3-pip
    fi
    
    log_success "Prerequisites check completed"
}

# Function to display installation options
show_installation_options() {
    echo -e "${PURPLE}Available Installation Methods:${NC}"
    echo -e "${YELLOW}1. pipx${NC}     - Recommended for modern Ubuntu (22.04+)"
    echo -e "${YELLOW}2. venv${NC}     - Virtual environment with global symlink"
    echo -e "${YELLOW}3. source${NC}   - Install from GitHub source"
    echo -e "${YELLOW}4. force${NC}    - Force pip install (not recommended)"
    echo -e "${YELLOW}5. auto${NC}     - Automatically choose best method"
    echo ""
}

# Function to auto-detect best installation method (FIXED)
auto_detect_method() {
    local ubuntu_version
    local selected_method
    
    ubuntu_version=$(detect_ubuntu_version)
    
    # Use stderr for logging to avoid polluting the return value
    log_info "Detected Ubuntu version: $ubuntu_version" >&2
    
    if check_externally_managed; then
        log_info "Detected externally-managed Python environment" >&2
        if command_exists pipx; then
            selected_method="pipx"
        else
            selected_method="pipx"  # Will install pipx first
        fi
    else
        log_info "Standard Python environment detected" >&2
        selected_method="venv"
    fi
    
    # Only echo the method name (this is what gets returned)
    echo "$selected_method"
}

# Function to clean up previous installations
cleanup_previous_installations() {
    log_info "Checking for previous installations..."
    
    # Remove old symlinks
    if [ -L "/usr/local/bin/paramspider" ]; then
        log_info "Removing old symlink..."
        sudo rm -f /usr/local/bin/paramspider
    fi
    
    # Check pipx installation
    if command_exists pipx && pipx list | grep -q paramspider; then
        log_info "Found existing pipx installation"
        read -p "Remove existing pipx installation? (y/N): " remove_pipx
        if [[ $remove_pipx =~ ^[Yy]$ ]]; then
            pipx uninstall paramspider
            log_success "Removed existing pipx installation"
        fi
    fi
    
    log_success "Cleanup completed"
}

# Function to add PATH modifications
setup_path() {
    local shell_rc="$HOME/.bashrc"
    
    # Detect shell
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$FISH_VERSION" ]; then
        shell_rc="$HOME/.config/fish/config.fish"
    fi
    
    log_info "Setting up PATH in $shell_rc..."
    
    # Add pipx path if not already present
    if ! grep -q "pipx ensurepath" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# Added by ParamSpider installer" >> "$shell_rc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        log_success "Added PATH configuration to $shell_rc"
    else
        log_info "PATH already configured"
    fi
    
    # Export for current session
    export PATH="$HOME/.local/bin:$PATH"
}

# Function to create test script
create_test_script() {
    log_info "Creating test script..."
    
    cat > test_paramspider.sh << 'EOF'
#!/bin/bash
echo "Testing ParamSpider installation..."
echo "Command: paramspider --help"
echo "=========================="
paramspider --help
echo ""
echo "Command: paramspider -d httpbin.org"
echo "=========================="
paramspider -d httpbin.org
if [ -f "results/httpbin.org.txt" ]; then
    echo "Success! Found results file:"
    wc -l results/httpbin.org.txt
    head -3 results/httpbin.org.txt
else
    echo "No results file generated - this might be normal if no parameters were found"
fi
EOF
    
    chmod +x test_paramspider.sh
    log_success "Created test_paramspider.sh"
}

# Main installation function
main() {
    echo -e "${CYAN}Starting ParamSpider installation...${NC}"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Determine installation method
    local method="$INSTALL_METHOD"
    
    if [ "$method" = "auto" ]; then
        method=$(auto_detect_method)
        log_info "Auto-selected installation method: $method"
    elif [ "$method" = "" ] || [ "$method" = "interactive" ]; then
        show_installation_options
        read -p "Choose installation method (1-5): " choice
        case $choice in
            1) method="pipx" ;;
            2) method="venv" ;;
            3) method="source" ;;
            4) method="force" ;;
            5) method=$(auto_detect_method) ;;
            *) method="pipx" ;;
        esac
    fi
    
    echo ""
    log_info "Using installation method: $method"
    echo ""
    
    # Cleanup previous installations
    cleanup_previous_installations
    echo ""
    
    # Install based on method
    case $method in
        "pipx")
            install_via_pipx
            ;;
        "venv")
            install_via_venv
            ;;
        "source")
            install_from_source
            ;;
        "force")
            install_force
            ;;
        *)
            log_error "Unknown installation method: $method"
            exit 1
            ;;
    esac
    
    echo ""
    
    # Setup PATH
    setup_path
    echo ""
    
    # Test installation
    if test_paramspider; then
        log_success "ParamSpider installation completed successfully!"
    else
        log_error "Installation completed but ParamSpider is not working correctly"
        echo ""
        log_info "Troubleshooting steps:"
        echo -e "${YELLOW}1. Restart your terminal or run: source ~/.bashrc${NC}"
        echo -e "${YELLOW}2. Check if paramspider is in PATH: which paramspider${NC}"
        echo -e "${YELLOW}3. Try running: /usr/local/bin/paramspider --help${NC}"
        echo -e "${YELLOW}4. Check the troubleshooting guide${NC}"
        exit 1
    fi
    
    echo ""
    
    # Create test script
    create_test_script
    
    # Final instructions
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}           INSTALLATION COMPLETE!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "${CYAN}1. Restart your terminal or run:${NC} source ~/.bashrc"
    echo -e "${CYAN}2. Test the installation:${NC} paramspider --help"
    echo -e "${CYAN}3. Run the test script:${NC} ./test_paramspider.sh"
    echo -e "${CYAN}4. Use with XSS scanner:${NC} ./crawl_and_scan.sh"
    echo ""
    echo -e "${YELLOW}Usage Examples:${NC}"
    echo -e "${CYAN}paramspider -d example.com${NC}"
    echo -e "${CYAN}paramspider -d example.com -l 2${NC}"
    echo -e "${CYAN}paramspider -d example.com -o simple${NC}"
    echo ""
    echo -e "${YELLOW}Integration with XSS Scanner:${NC}"
    echo -e "${CYAN}./crawl_and_scan.sh 1 https://example.com${NC}"
    echo ""
    
    if [ "$method" = "force" ]; then
        echo -e "${RED}WARNING: You used force installation which may have affected your system Python environment.${NC}"
        echo -e "${RED}Consider using pipx or venv method for future installations.${NC}"
        echo ""
    fi
}

# Handle command line arguments
case "$1" in
    "--help"|"-h")
        echo -e "${BLUE}ParamSpider Auto-Installer for Ubuntu${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC} $0 [method]"
        echo ""
        show_installation_options
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "${CYAN}$0${NC}          # Interactive mode"
        echo -e "${CYAN}$0 auto${NC}     # Auto-detect best method"
        echo -e "${CYAN}$0 pipx${NC}     # Install via pipx"
        echo -e "${CYAN}$0 venv${NC}     # Install via virtual environment"
        echo -e "${CYAN}$0 source${NC}   # Install from source"
        echo ""
        exit 0
        ;;
    "--test")
        if test_paramspider; then
            echo -e "${GREEN}ParamSpider is working correctly!${NC}"
            exit 0
        else
            echo -e "${RED}ParamSpider installation test failed!${NC}"
            exit 1
        fi
        ;;
    "--uninstall")
        log_info "Uninstalling ParamSpider..."
        
        # Remove pipx installation
        if command_exists pipx && pipx list | grep -q paramspider; then
            pipx uninstall paramspider
            log_success "Removed pipx installation"
        fi
        
        # Remove symlinks
        if [ -L "/usr/local/bin/paramspider" ]; then
            sudo rm -f /usr/local/bin/paramspider
            log_success "Removed global symlink"
        fi
        
        # Remove source installation
        if [ -d "$HOME/security-tools/ParamSpider" ]; then
            rm -rf "$HOME/security-tools/ParamSpider"
            log_success "Removed source installation"
        fi
        
        # Remove virtual environment
        if [ -d "$HOME/.security-tools-venv" ]; then
            rm -rf "$HOME/.security-tools-venv"
            log_success "Removed virtual environment"
        fi
        
        log_success "ParamSpider uninstallation completed"
        exit 0
        ;;
esac

# Run main installation
main