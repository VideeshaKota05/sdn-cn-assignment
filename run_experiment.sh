#!/bin/bash

################################################################################
# Network Delay Measurement Tool - Mininet Automation Script
# 
# Purpose: Automate SDN experiment setup and RTT measurement
# Author: Kota Videesha (PES1UG24AM140)
# Date: 18 April 2025
#
# Usage: sudo ./run_experiment.sh [5|20]
#   - Requires sudo (for Mininet network operations)
#   - Argument: 5 for 5ms delay experiment, 20 for 20ms delay experiment
#
# Example:
#   sudo ./run_experiment.sh 5    # Run 5ms delay experiment
#   sudo ./run_experiment.sh 20   # Run 20ms delay experiment
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Function: Print colored output
################################################################################
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# Function: Check prerequisites
################################################################################
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if running as root/sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo privileges"
    fi
    print_success "Running with sudo privileges"
    
    # Check if Mininet is installed
    if ! command -v mn &> /dev/null; then
        print_error "Mininet is not installed. Install with: sudo apt-get install mininet"
    fi
    print_success "Mininet installed"
    
    # Check if POX is available
    if [ ! -d "$HOME/pox" ]; then
        print_warning "POX controller not found at $HOME/pox"
        print_info "Make sure POX is running in another terminal:"
        print_info "  cd ~/pox && ./pox.py py.controller"
    fi
    print_success "Prerequisites check complete"
}

################################################################################
# Function: Validate delay parameter
################################################################################
validate_delay() {
    if [ -z "$1" ]; then
        print_error "Delay parameter required. Usage: sudo ./run_experiment.sh [5|20]"
    fi
    
    if [ "$1" != "5" ] && [ "$1" != "20" ]; then
        print_error "Invalid delay parameter. Use 5 or 20 (milliseconds)"
    fi
    
    echo "$1"
}

################################################################################
# Function: Kill any existing Mininet processes
################################################################################
cleanup_mininet() {
    print_info "Cleaning up any existing Mininet processes..."
    
    # Kill any mn processes
    pkill -f mininet || true
    
    # Clear any residual OVS bridges
    ovs-vsctl list-br 2>/dev/null | while read bridge; do
        ovs-vsctl del-br "$bridge" 2>/dev/null || true
    done
    
    # Wait a bit for cleanup
    sleep 1
    print_success "Cleanup complete"
}

################################################################################
# Function: Create and run Mininet topology
################################################################################
run_mininet_experiment() {
    local delay=$1
    
    print_header "Running Mininet Experiment (${delay}ms delay)"
    
    print_info "Topology: Linear with 3 switches"
    print_info "  h1 --- s1 --- s2 --- s3 --- h3"
    print_info "  Total Links: 4"
    print_info "  Delay per Link: ${delay}ms"
    print_info ""
    
    # Calculate theoretical RTT
    local one_way_delay=$((4 * delay))
    local theoretical_rtt=$((2 * one_way_delay))
    
    print_info "Theoretical Analysis:"
    print_info "  One-way delay = 4 × ${delay}ms = ${one_way_delay}ms"
    print_info "  RTT = 2 × ${one_way_delay}ms = ${theoretical_rtt}ms"
    print_info ""
    
    # Create a temporary Mininet script
    local mn_script="/tmp/mininet_experiment_${delay}ms.py"
    
    cat > "$mn_script" << 'MNEOF'
#!/usr/bin/env python3
"""
Mininet experiment script for RTT measurement
"""
import sys
from mininet.net import Mininet
from mininet.node import OVSSwitch, RemoteController
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel

def run_experiment(delay_ms):
    """
    Run Mininet topology with specified link delay
    
    Args:
        delay_ms: Delay in milliseconds for each link
    """
    setLogLevel('info')
    
    # Create network with remote controller
    net = Mininet(
        controller=RemoteController,
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True
    )
    
    # Add remote controller (POX on port 6633)
    c0 = net.addController(
        'c0',
        controller=RemoteController,
        ip='127.0.0.1',
        port=6633
    )
    
    print("\n" + "="*60)
    print("Network Delay Measurement Experiment")
    print(f"Link Delay: {delay_ms}ms per link")
    print("="*60 + "\n")
    
    # Add hosts
    h1 = net.addHost('h1', ip='10.0.0.1')
    h3 = net.addHost('h3', ip='10.0.0.3')
    
    # Add switches
    s1 = net.addSwitch('s1')
    s2 = net.addSwitch('s2')
    s3 = net.addSwitch('s3')
    
    # Add links with delay
    net.addLink(h1, s1, delay=f'{delay_ms}ms')
    net.addLink(s1, s2, delay=f'{delay_ms}ms')
    net.addLink(s2, s3, delay=f'{delay_ms}ms')
    net.addLink(s3, h3, delay=f'{delay_ms}ms')
    
    # Start network
    net.start()
    
    print(f"\n✓ Network started with {delay_ms}ms delay per link")
    print("\nTopology:")
    print("  h1 (10.0.0.1)")
    print("    |")
    print("  s1")
    print("    |")
    print("  s2")
    print("    |")
    print("  s3")
    print("    |")
    print("  h3 (10.0.0.3)")
    
    print("\n" + "="*60)
    print("Mininet CLI Ready")
    print("="*60)
    print("\nUseful commands:")
    print("  h1 ping -c 5 h3          # Run RTT measurement")
    print("  h1 ping -c 10 h3         # Run 10 pings")
    print("  iperf h1 h3              # Measure throughput")
    print("  s1 dpctl dump-flows      # Check flow table on s1")
    print("  net                      # Show network info")
    print("  exit                     # Exit Mininet")
    print("\n" + "="*60 + "\n")
    
    # Launch CLI
    CLI(net)
    
    # Cleanup
    net.stop()
    print("\n✓ Network stopped")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 mininet_experiment.py <delay_ms>")
        sys.exit(1)
    
    delay = int(sys.argv[1])
    run_experiment(delay)
MNEOF
    
    # Run the Mininet experiment
    print_info "Launching Mininet topology..."
    print_info "Make sure POX controller is running in another terminal!"
    print_info ""
    
    python3 "$mn_script" "$delay"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Experiment completed successfully"
    else
        print_error "Experiment failed with exit code $exit_code"
    fi
    
    # Cleanup script file
    rm -f "$mn_script"
}

################################################################################
# Function: Generate results summary
################################################################################
generate_results_summary() {
    local delay=$1
    
    print_header "Experiment Summary"
    
    local one_way=$((4 * delay))
    local theoretical=$((2 * one_way))
    
    echo ""
    echo "Delay Configuration:"
    echo "  Per-link delay: ${delay}ms"
    echo "  Total hops: 4"
    echo "  One-way delay: ${one_way}ms"
    echo ""
    echo "Theoretical RTT: ${theoretical}ms"
    echo ""
    echo "Next Steps:"
    echo "  1. Run: h1 ping -c 5 h3"
    echo "  2. Record average RTT from ping output"
    echo "  3. Compare with theoretical value (${theoretical}ms)"
    echo ""
    echo "Expected Results:"
    if [ "$delay" -eq 5 ]; then
        echo "  RTT ≈ 40-42 ms (theoretical: 40ms)"
    elif [ "$delay" -eq 20 ]; then
        echo "  RTT ≈ 160-162 ms (theoretical: 160ms)"
    fi
    echo ""
}

################################################################################
# Function: Display usage help
################################################################################
show_usage() {
    cat << EOF
Network Delay Measurement Tool - Experiment Script

USAGE:
  sudo ./run_experiment.sh [DELAY]

ARGUMENTS:
  DELAY          Delay in milliseconds (5 or 20)
    5             Run experiment with 5ms per-link delay
    20            Run experiment with 20ms per-link delay

EXAMPLES:
  sudo ./run_experiment.sh 5
    Runs Mininet with 5ms delay, theoretical RTT = 40ms

  sudo ./run_experiment.sh 20
    Runs Mininet with 20ms delay, theoretical RTT = 160ms

PREREQUISITES:
  - Mininet installed: sudo apt-get install mininet
  - POX controller running in another terminal:
    cd ~/pox && ./pox.py py.controller
  - This script must be run with sudo

WORKFLOW:
  1. Start POX controller in Terminal 1:
     cd ~/pox && ./pox.py py.controller

  2. Run this script in Terminal 2:
     sudo ./run_experiment.sh 5

  3. Inside Mininet CLI, run measurement:
     mininet> h1 ping -c 5 h3

  4. Observe RTT values and compare with theory

TOPOLOGY:
  h1 --- s1 --- s2 --- s3 --- h3
  
  4 links total, each with configurable delay

TESTING:
  Inside Mininet CLI, useful commands:
    h1 ping -c 5 h3        # Ping 5 packets (basic RTT test)
    h1 ping -c 10 h3       # Ping 10 packets (more samples)
    iperf h1 h3            # Measure throughput
    s1 dpctl dump-flows    # Check OpenFlow flow rules on s1
    pingall                # Test all host pairs
    net                     # Display network info
    exit                    # Exit Mininet and cleanup

EXPECTED RESULTS:
  5ms delay case:
    Theoretical RTT = 2 × (4 × 5ms) = 40ms
    Observed RTT ≈ 41.5ms (error ~3.75%)

  20ms delay case:
    Theoretical RTT = 2 × (4 × 20ms) = 160ms
    Observed RTT ≈ 161ms (error ~0.625%)

TROUBLESHOOTING:
  - Timeout errors: POX controller not running
  - Connection refused: Check POX is on port 6633
  - Topology issues: Run cleanup first
  - Permission denied: Use 'sudo' to run this script

MORE INFO:
  See README.md and Network_Delay_Measurement_Report.docx
  for complete project documentation.

EOF
}

################################################################################
# Main Script Execution
################################################################################
main() {
    # Handle help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    # Validate delay parameter
    DELAY=$(validate_delay "$1")
    
    print_header "Network Delay Measurement Tool"
    print_info "SDN-based Mininet Experiment"
    print_info ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Cleanup before starting
    cleanup_mininet
    echo ""
    
    # Generate summary
    generate_results_summary "$DELAY"
    echo ""
    
    # Run experiment
    run_mininet_experiment "$DELAY"
}

# Run main function with all arguments
main "$@"
