# Network Delay Measurement Tool - SDN/Mininet Project

## 🎯 Project Objective

This project implements an SDN system using Mininet and POX to measure how network latency (RTT) behaves when delays are introduced across multiple hops. We:
- Set up a multi-hop linear topology with 3 switches
- Introduce configurable delays on links
- Measure RTT and compare with theoretical values
- Validate that Mininet accurately simulates real network behavior

---

## 📋 Problem Statement

Real networks experience latency due to physical distance, intermediate devices, and link characteristics. This project answers: **How does RTT scale when delay is introduced across network hops?**

We test with two scenarios (5ms and 20ms per-link delay) and validate our measurements against theory.

---

## 🏗️ Topology Design

### Linear Topology (3 switches)
```
h1 ─── s1 ─── s2 ─── s3 ─── h3
```

**What we have:**
- 2 hosts (h1, h3)
- 3 switches (s1, s2, s3)
- 4 total links (h1→s1, s1→s2, s2→s3, s3→h3)
- Each link has a configurable delay

**Why this topology?** It's simple, predictable, and lets us easily calculate expected RTT. The fixed 4-hop path shows how delay accumulates across multiple hops.

---

## 🛠️ Tools & Technologies

| Component | Version | Purpose |
|-----------|---------|---------|
| **Mininet** | Latest | Network emulation platform |
| **POX Controller** | 0.7.0 | OpenFlow SDN controller |
| **Python** | 3.6+ | Controller logic & scripting |
| **Linux (WSL/Ubuntu)** | 20.04 LTS | Operating system |
| **ping** | - | RTT measurement utility |

---

## 🚀 Setup & Execution

**Prerequisites:**
```bash
sudo apt-get install mininet
cd ~
git clone https://github.com/noxrepo/pox.git
```

**Step 1: Start POX Controller (Terminal 1)**
```bash
cd ~/pox
./pox.py py.controller
# Wait for "INFO:core:POX ... is up."
```

**Step 2: Launch Mininet (Terminal 2)**

For 5ms delay:
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=5ms
```

For 20ms delay:
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=20ms
```

**Step 3: Run Measurements (Inside Mininet CLI)**
```mininet
mininet> h1 ping -c 5 h3
```

---

## 📊 Experimental Results

### Test 1: 5ms Delay per Link

| Parameter | Value |
|-----------|-------|
| Delay per link | 5 ms |
| Number of hops | 4 |
| One-way delay | 4 × 5 = 20 ms |
| Theoretical RTT | 2 × 20 = **40 ms** |
| Observed RTT | **41.5 ms** |
| Error | 3.75% ✅ |

### Test 2: 20ms Delay per Link

| Parameter | Value |
|-----------|-------|
| Delay per link | 20 ms |
| Number of hops | 4 |
| One-way delay | 4 × 20 = 80 ms |
| Theoretical RTT | 2 × 80 = **160 ms** |
| Observed RTT | **161 ms** |
| Error | 0.625% ✅ |

### The Formula
```
RTT = 2 × (Number of hops × Delay per link)

For our topology: RTT = 2 × (4 × d) = 8d
```

### What We Found
- RTT increases linearly with delay ✓
- Results match theory within 4% error ✓
- Multi-hop networks multiply the delay effect ✓
- First ping may be slightly higher (ARP + flow setup) ⚠️

---

## 4. Experimental Procedure and Results

### 4.1 POX Controller Startup

The POX controller is initialized with the custom learning switch controller:

![alt text](screenshots/pox.png)

The controller successfully loads and waits for switch connections on port 6633. Multiple OpenFlow flow events are logged as the controller manages switch initialization and packet forwarding.

---

### 4.2 Experiment 1: 20ms Link Delay Topology

**Command executed:**
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=20ms
```

![alt text](screenshots/delay2.png)

The topology creates 3 switches with 4 links, each configured with 20ms delay. The output shows:
- Topology creation with all hosts and switches initialized
- Pingall test: 100% connectivity (0% packet loss)
- h1 to h3 ping results showing approximately 161ms RTT
- Statistics confirm 5 packets transmitted and received with average delay of ~161ms

---

### 4.3 Experiment 2: 5ms Link Delay Topology

**Command executed:**
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=5ms
```

![alt text](screenshots/delay1.png)

With 5ms per-link delay, the topology shows:
- Identical topology structure as 20ms case
- Pingall test: 100% connectivity (0% packet loss)
- h1 to h3 ping results showing approximately 41-42ms RTT
- Statistics show min/avg/max values clustering around 41ms
- Experiment completed in ~193 seconds

---

## 5. Results and Analysis

### 5.2 RTT vs Link Delay Graph

![alt text](screenshots/rtt_vs_delay.png)

The graph clearly demonstrates the linear relationship between per-link delay and observed RTT:
- At 5ms delay: RTT ≈ 41.5ms
- At 20ms delay: RTT ≈ 161ms
- Linear trend: RTT = 8d + overhead

### 5.3 Theoretical Analysis

Formula for RTT in linear topology:
```
RTT = 2 × (Number of Hops × Delay per Link)
```

For our 4-hop topology:
```
RTT = 2 × (4 × d) = 8d
```

**Case 1 (5ms):**
- RTT = 8 × 5 = 40ms
- Observed = 41.5ms → Error = 3.75%

**Case 2 (20ms):**
- RTT = 8 × 20 = 160ms
- Observed = 161ms → Error = 0.625%

### 5.4 Key Findings
- RTT scales linearly with link delay - doubling delay increases RTT by 4x
- Mininet accurately simulates real network delay behavior
- Multi-hop topology amplifies delay effect (4 hops = 8x multiplier)
- OpenFlow flow rule installation doesn't add significant latency
- SDN-based approach successfully manages packet forwarding

---

## 6. SDN Controller Implementation

### 6.1 Controller Logic

The POX controller implements a learning switch pattern:

1. Switch connects → Controller registers connection
2. Packet arrives at switch → Switch sends packet_in to controller
3. Controller extracts source MAC and port information
4. Controller learns MAC-to-port mapping
5. If destination is known:
   - Install OpenFlow flow rule
   - Forward packet to learned port
6. If destination is unknown → Flood to all ports

### 6.2 Flow Rule Design

Flow rules installed have the following characteristics:
- **Match:** Source MAC + Destination MAC + Ethernet type
- **Action:** Forward to learned output port
- **Priority:** 100 (standard forwarding priority)
- **Idle Timeout:** 10 seconds (remove rule if inactive)
- **Hard Timeout:** 30 seconds (remove rule regardless)

### 6.3 Performance Benefit

After initial learning phase, all packets use pre-installed rules, eliminating controller overhead. This demonstrates the efficiency of SDN for high-throughput forwarding.

---

## 7. Validation and Testing

### 7.1 Test Results

Three validation tests confirm correct behavior:

**Test 1 - Basic Connectivity**
- Command: `h1 ping -c 5 h3`
- Result: 100% success rate, stable RTT within expected range ✓

**Test 2 - Multi-host Reachability**
- Command: `pingall`
- Result: All hosts reach each other with 0% packet loss ✓

**Test 3 - Flow Table Verification**
- Command: `s1 dpctl dump-flows`
- Result: Flow rules installed with correct match/action fields ✓

### 7.2 Validation Summary

All experimental measurements fall within 4% of theoretical predictions, confirming:
- Mininet accurately simulates network delays
- POX controller correctly implements OpenFlow
- Linear topology provides predictable delay accumulation
- Flow rule installation is efficient and correct

---

## 8. Conclusion

### 8.1 Summary of Achievement

This project successfully demonstrates an SDN-based network delay measurement system. Key achievements include:
- Implemented a complete SDN controller using POX with packet handling and flow rule installation
- Created a multi-hop linear topology that accurately demonstrates delay accumulation
- Measured RTT under two delay scenarios with validation against theoretical predictions
- Achieved measurement accuracy within 0.6-3.75% error margin
- Demonstrated OpenFlow protocol functionality and SDN benefits

### 8.2 Learning Outcomes

Through this project, the following technical competencies were developed:
- Understanding of SDN architecture and OpenFlow protocol
- Practical experience with Mininet network simulation
- Ability to design and implement SDN controllers in Python
- Network performance measurement and analysis skills
- Understanding of delay-sensitive network design

### 8.3 Project Impact

This project demonstrates that SDN provides effective control over network behavior, allowing dynamic configuration and measurement of network performance. The linear scaling of RTT with delay validates the predictability of multi-hop networks, which is critical for designing delay-sensitive applications like VoIP and online gaming.

---

## 9. Appendix

### 9.1 Command Reference

**POX Controller Startup:**
```bash
cd ~/pox && ./pox.py py.controller
```

**Mininet Topology (5ms delay):**
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=5ms
```

**Mininet Topology (20ms delay):**
```bash
sudo mn --controller=remote,port=6633 --topo linear,3 --link tc,delay=20ms
```

**Run Measurements:**
```bash
mininet> h1 ping -c 5 h3
```

### 9.2 References

- [1] POX OpenFlow Controller - https://github.com/noxrepo/pox
- [2] Mininet Network Emulator - http://mininet.org
- [3] OpenFlow 1.0 Specification - https://opennetworking.org/
- [4] Linux Traffic Control (tc) - https://man7.org/linux/man-pages/man8/tc.8.html

---

## 📝 Author & Submission

**Student:** Mirunjai Suresh Kumar  
**SRN:** PES1UG24AM161  
**University:** PES University, Bangalore  
**Program:** CSE (AIML) - Class 4C  
**Date:** April 2025

---

**Status:** ✅ Complete and Ready for Submission
