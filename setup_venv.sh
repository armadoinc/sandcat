#!/bin/bash

# Setup script for Caldera project virtual environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_info "Setting up Caldera project virtual environment..."

# Check Python version
print_status "Checking Python version..."
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
MAJOR_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
MINOR_VERSION=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

if [[ $MAJOR_VERSION -lt 3 ]] || [[ $MAJOR_VERSION -eq 3 && $MINOR_VERSION -lt 8 ]]; then
    print_error "Python 3.8 or higher is required (found: $PYTHON_VERSION)"
    exit 1
fi

print_status "Python $PYTHON_VERSION detected"

# Check for Python 3.13+ compatibility issues and auto-fix
if [[ $MAJOR_VERSION -eq 3 && $MINOR_VERSION -ge 13 ]]; then
    print_warning "Python 3.13+ detected - this version is not yet fully supported by Caldera dependencies"
    print_warning "Several core dependencies (including lxml) do not support Python 3.13"
    print_info "For detailed information: https://github.com/armadoinc/sandcat/issues/1"
    echo
    print_status "Automatically installing Python 3.11 for compatibility..."
    
    # Try to install Python 3.11 using available package managers
    if command -v brew &> /dev/null; then
        print_status "Installing Python 3.11 via Homebrew..."
        brew install python@3.11 &> /dev/null || {
            print_error "Failed to install Python 3.11 via Homebrew"
            exit 1
        }
        PYTHON_CMD="/usr/local/opt/python@3.11/bin/python3.11"
        if [ ! -f "$PYTHON_CMD" ]; then
            PYTHON_CMD="/opt/homebrew/opt/python@3.11/bin/python3.11"
        fi
    elif command -v pyenv &> /dev/null; then
        print_status "Installing Python 3.11.9 via pyenv..."
        pyenv install 3.11.9 || {
            print_error "Failed to install Python 3.11.9 via pyenv"
            exit 1
        }
        PYTHON_CMD="$(pyenv root)/versions/3.11.9/bin/python3"
    else
        print_error "Neither brew nor pyenv found. Please install one of them first:"
        print_error "  • Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        print_error "  • pyenv: curl https://pyenv.run | bash"
        exit 1
    fi
    
    # Verify the Python 3.11 installation
    if [ ! -f "$PYTHON_CMD" ]; then
        print_error "Python 3.11 installation failed - executable not found at $PYTHON_CMD"
        exit 1
    fi
    
    print_status "Using Python 3.11: $PYTHON_CMD"
    # Override the python3 command for the rest of the script
    alias python3="$PYTHON_CMD"
    
    # Re-check version
    PYTHON_VERSION=$($PYTHON_CMD --version | cut -d' ' -f2)
    print_status "Now using Python $PYTHON_VERSION"
fi

# Set project root (current directory since script is in root)
PROJECT_ROOT="$(pwd)"

print_info "Working in project root: $PROJECT_ROOT"

# Check if we're in the correct Caldera directory
if [ ! -f "requirements.txt" ] || [ ! -d "app" ] || [ ! -f "README.md" ]; then
    print_error "Must run from Caldera project root directory"
    print_error "Expected files/directories: requirements.txt, app/, README.md"
    exit 1
fi

# Create virtual environment
print_status "Creating virtual environment..."
if [ -d "venv" ]; then
    print_warning "Virtual environment already exists"
    read -p "Do you want to recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing existing virtual environment..."
        rm -rf venv
        # Use the correct Python command (may be overridden for 3.11)
        ${PYTHON_CMD:-python3} -m venv venv
    else
        print_info "Using existing virtual environment"
    fi
else
    # Use the correct Python command (may be overridden for 3.11)
    ${PYTHON_CMD:-python3} -m venv venv
fi

# Clear any proxy settings that might interfere with pip
print_status "Clearing proxy settings..."
unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY ftp_proxy FTP_PROXY all_proxy ALL_PROXY

# Disable problematic plugins that depend on lxml
print_status "Disabling lxml-dependent plugins..."
if [ -f "conf/default.yml" ] && grep -q "^- debrief" conf/default.yml; then
    sed -i '' 's/^- debrief/#- debrief  # disabled due to lxml compilation issues (see https:\/\/github.com\/armadoinc\/sandcat\/issues\/1)/' conf/default.yml
    print_warning "Disabled debrief plugin in conf/default.yml due to lxml compilation issues (see https://github.com/armadoinc/sandcat/issues/1)"
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip and install essential tools
print_status "Upgrading pip and installing build tools..."
python -m pip install --upgrade pip wheel setuptools



# Install main requirements
print_status "Installing main requirements..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    print_error "requirements.txt not found in project root"
    exit 1
fi

# Install development requirements if available
if [ -f "requirements-dev.txt" ]; then
    print_status "Installing development requirements..."
    pip install -r requirements-dev.txt
else
    print_warning "requirements-dev.txt not found - skipping development dependencies"
fi

# Verify core Caldera dependencies
print_status "Verifying Caldera dependencies..."
python -c "
import sys
try:
    import aiohttp
    import jinja2
    import yaml
    import cryptography
    print('✓ Core dependencies verified')
except ImportError as e:
    print(f'✗ Missing dependency: {e}')
    sys.exit(1)
" || {
    print_error "Failed to verify core dependencies"
    exit 1
}

# Display environment info
print_status "Environment setup complete!"
echo
print_info "Virtual environment location: $PROJECT_ROOT/venv"
print_info "Python version: $(python --version)"
print_info "Pip version: $(pip --version)"



echo
echo "To use the environment:"
echo "   Activate:   source venv/bin/activate"
echo "   Deactivate: deactivate"
echo
echo "To start Caldera:"
echo "   python -m app --insecure" 