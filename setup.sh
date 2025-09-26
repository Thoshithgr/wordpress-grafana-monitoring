#!/bin/bash

echo "=========================================="
echo "WordPress + Grafana Monitoring Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Consider using a non-root user with sudo privileges."
fi

echo
print_status "Step 1: Checking system requirements..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo
    echo "Installing Docker..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed successfully!"
    print_warning "Please log out and log back in for group changes to take effect, then run this script again."
    exit 0
else
    print_success "Docker is already installed ✓"
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose plugin is not available!"
    echo "Please install Docker Compose plugin or use docker-compose if available."
    exit 1
else
    print_success "Docker Compose is available ✓"
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running!"
    echo "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    if ! docker info &> /dev/null; then
        print_error "Failed to start Docker daemon. Please check your Docker installation."
        exit 1
    fi
    print_success "Docker daemon started ✓"
else
    print_success "Docker daemon is running ✓"
fi

echo
print_status "Step 2: Creating required directories..."
if [ ! -d "grafana/provisioning/datasources" ]; then
    mkdir -p grafana/provisioning/datasources
    print_success "Created grafana directories"
else
    print_success "Grafana directories already exist"
fi

echo
print_status "Step 3: Setting proper permissions..."
# Set proper permissions for the current user
sudo chown -R $USER:$USER .
chmod +x setup.sh

echo
print_status "Step 4: Stopping any existing containers..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

echo
print_status "Step 5: Pulling required images..."
docker compose pull || docker-compose pull

echo
print_status "Step 6: Starting all services..."
docker compose up -d || docker-compose up -d

echo
print_status "Step 7: Waiting for services to start..."
sleep 30

echo
print_status "Step 8: Checking container status..."
docker compose ps || docker-compose ps

echo
print_status "Step 9: Checking service health..."

# Function to check if service is responding
check_service() {
    local url=$1
    local name=$2
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s $url > /dev/null 2>&1; then
            print_success "$name is responding ✓"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    print_warning "$name is not responding yet"
    return 1
}

echo -n "Checking WordPress"
check_service "http://localhost:8080" "WordPress"

echo -n "Checking Grafana"
check_service "http://localhost:3000" "Grafana"

echo -n "Checking Prometheus"
check_service "http://localhost:9090" "Prometheus"

echo
echo "=========================================="
print_success "Setup Complete! 🎉"
echo "=========================================="
echo
echo -e "${BLUE}Service URLs:${NC}"
echo "WordPress:   http://localhost:8080"
echo "Grafana:     http://localhost:3000 (admin/admin123)"
echo "Prometheus:  http://localhost:9090"
echo "cAdvisor:    http://localhost:8081"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Setup WordPress at http://localhost:8080"
echo "2. Login to Grafana at http://localhost:3000"
echo "3. Import dashboard templates (see README.md)"
echo "4. Configure monitoring alerts (optional)"
echo
echo -e "${GREEN}Useful commands:${NC}"
echo "• View logs: docker compose logs -f [service-name]"
echo "• Stop services: docker compose down"
echo "• Restart services: docker compose restart"
echo "• Update services: docker compose pull && docker compose up -d"
echo

# Optional: Open WordPress in browser (if GUI is available)
if command -v xdg-open &> /dev/null; then
    read -p "Open WordPress in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open http://localhost:8080
    fi
fi
