# POX Controller - Network Delay Measurement Tool
# Purpose: SDN-based learning switch with packet forwarding
# This controller handles packet_in events and installs flow rules dynamically

from pox.core import core
from pox.openflow import openflow_discovery
from pox.lib.revent import *
from pox.lib.util import dpidToStr
from pox.openflow import *
import pox.openflow.libopenflow_01 as of
from pox.lib.packet.ethernet import ethernet, ETHER_BROADCAST
from pox.lib.packet.ipv4 import ipv4
from pox.lib.packet.arp import arp
from collections import defaultdict

log = core.getLogger()

class NetworkDelayMeasurement(object):
    """
    SDN Controller for Network Delay Measurement
    
    Features:
    - Learning switch: learns MAC addresses and ports
    - Installs OpenFlow rules for efficient forwarding
    - Logs packet_in events for analysis
    - Supports multi-switch linear topology
    """
    
    def __init__(self):
        """Initialize the controller with MAC learning table"""
        # mac_to_port: {dpid: {mac: port}}
        self.mac_to_port = defaultdict(dict)
        
        # Statistics tracking
        self.packet_count = defaultdict(int)
        self.flow_rules_installed = 0
        
    def start_switch(self, event):
        """Called when a switch connects to the controller"""
        dpid = event.connection.dpid
        log.info("Switch %s connected", dpidToStr(dpid))
        
    def packet_in_handler(self, event):
        """
        Handle packet_in messages from switches
        
        Logic:
        1. Parse incoming packet (Ethernet frame)
        2. Learn source MAC -> port mapping
        3. Install flow rule for forward path
        4. Flood packet if destination unknown (learning phase)
        5. Log statistics
        """
        packet = event.parsed  # Ethernet packet
        dpid = event.connection.dpid
        in_port = event.port
        
        # Log incoming packet
        log.info("Packet_in: Switch %s, Port %s, Src MAC: %s, Dst MAC: %s",
                 dpidToStr(dpid), in_port, packet.src, packet.dst)
        self.packet_count[dpid] += 1
        
        # Learning: record source MAC address
        self.mac_to_port[dpid][packet.src] = in_port
        
        # Determine output port
        if packet.dst in self.mac_to_port[dpid]:
            # Destination known: unicast to learned port
            out_port = self.mac_to_port[dpid][packet.dst]
        else:
            # Destination unknown: flood to all ports (except incoming)
            out_port = of.OFPP_FLOOD
        
        # Install flow rule for this pair (if not flooding)
        if out_port != of.OFPP_FLOOD:
            self.install_flow_rule(event.connection, packet.src, 
                                   packet.dst, out_port)
        
        # Send the packet out
        self.send_packet(event.connection, of.ofp_action_output(port=out_port),
                         event.data)
    
    def install_flow_rule(self, connection, src_mac, dst_mac, out_port):
        """
        Install OpenFlow flow rule on switch
        
        Match: Source MAC + Destination MAC
        Action: Forward to out_port
        Timeout: 10 seconds (hard timeout for cleanup)
        """
        msg = of.ofp_flow_mod()
        msg.match = of.ofp_match()
        msg.match.dl_src = src_mac
        msg.match.dl_dst = dst_mac
        msg.match.dl_type = ethernet.IP_TYPE  # Only match IP packets
        
        # Action: forward to out_port
        msg.actions.append(of.ofp_action_output(port=out_port))
        
        # Timeouts
        msg.idle_timeout = 10  # Remove rule if no activity for 10s
        msg.hard_timeout = 30  # Remove rule after 30s regardless
        msg.priority = 100
        
        connection.send(msg)
        self.flow_rules_installed += 1
        
        log.info("Flow rule installed: %s -> %s via port %s (Total: %d)",
                 src_mac, dst_mac, out_port, self.flow_rules_installed)
    
    def send_packet(self, connection, action, packet_data):
        """Send a packet out of a switch"""
        msg = of.ofp_packet_out()
        msg.actions.append(action)
        msg.data = packet_data
        connection.send(msg)


def launch():
    """
    POX launch function - sets up the controller
    
    Called automatically by POX when this module is loaded
    Registers event handlers for OpenFlow events
    """
    # Create controller instance
    controller = NetworkDelayMeasurement()
    
    # Register event handlers
    core.openflow.addListenerByName("ConnectionUp", controller.start_switch)
    core.openflow.addListenerByName("PacketIn", controller.packet_in_handler)
    
    log.info("Network Delay Measurement Controller Started")
    log.info("Ready to accept OpenFlow connections on port 6633")
