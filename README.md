# AXI-Memory-Controller
# AXI4 Slave Memory Controller with UVM Verification

A spec-compliant AXI4 slave memory controller implemented in SystemVerilog with a comprehensive UVM verification environment.

## Features

### RTL Design
- **Full AXI4 protocol compliance** - All five channels (AW, W, B, AR, R)
- **Burst types** - FIXED, INCR, and WRAP with proper address calculation
- **Configurable parameters** - Data width (64-bit default), address width (32-bit), ID width (4-bit)
- **Byte-addressable memory** - 4KB default size with full strobe handling
- **Error response logic**:
  - SLVERR for out-of-range addresses
  - SLVERR for exclusive access attempts (not supported)
  - DECERR for 4KB boundary violations
- **Protocol assertions** - Built-in SystemVerilog assertions for compliance checking

### UVM Verification Environment
- **Layered agent architecture** - Modular, reusable components
- **Constrained-random sequences** - Comprehensive test scenarios
- **Reference model scoreboard** - Automatic data comparison
- **Functional coverage** - Burst types, lengths, alignments, responses
- **Multiple simulators** - Xcelium, VCS, Questa/ModelSim support

## Directory Structure

```
axi4_slave_uvm/
├── rtl/
│   ├── axi4_pkg.sv           # Protocol types and parameters
│   ├── axi4_if.sv            # AXI4 interface with assertions
│   └── axi4_slave_mem_ctrl.sv # DUT implementation
├── tb/
│   ├── agents/
│   │   └── axi4_master_agent/
│   │       ├── axi4_seq_item.sv      # Transaction class
│   │       ├── axi4_master_driver.sv  # Protocol driver
│   │       ├── axi4_master_monitor.sv # Monitor with coverage
│   │       ├── axi4_master_sequencer.sv
│   │       ├── axi4_master_agent.sv
│   │       └── axi4_master_agent_pkg.sv
│   ├── sequences/
│   │   └── axi4_sequences.sv  # Test sequences
│   ├── scoreboards/
│   │   └── axi4_scoreboard.sv # Reference model
│   ├── env/
│   │   └── axi4_env.sv        # UVM environment
│   ├── tests/
│   │   └── axi4_tests.sv      # Test cases
│   └── tb_top.sv              # Top-level testbench
├── sim/
│   ├── filelist.f             # Compilation file list
│   ├── run.sh                 # Run script
│   ├── Makefile               # Build automation
│   └── coverage.ccf           # Coverage config (Xcelium)
├── scripts/
│   └── eda_playground_setup.sh # EDA Playground helper
└── docs/
    └── README.md              # This file
```

## Quick Start

### Prerequisites
- Cadence Xcelium, Synopsys VCS, or Siemens Questa/ModelSim
- UVM 1.2 library (typically included with simulator)

### Running Simulation

```bash
cd sim

# Run sanity test (default)
make sanity

# Run specific test
make run TEST=axi4_burst_test

# Run with custom seed
make run TEST=axi4_random_test SEED=12345

# Run with debug verbosity
make run TEST=axi4_error_test VERBOSITY=UVM_HIGH

# Run full regression
make regression

# Run all individual tests
make run_all

# Run with coverage
make coverage TEST=axi4_regression_test

# Clean simulation files
make clean
```

### Using run.sh Script

```bash
cd sim

# Basic run
./run.sh -t axi4_sanity_test

# Run with GUI
./run.sh -t axi4_burst_test -g

# Run with waveforms
./run.sh -t axi4_random_test -w

# Run with coverage
./run.sh -t axi4_regression_test -c

# Full options
./run.sh --help
```

## Test Cases

| Test Name | Description |
|-----------|-------------|
| `axi4_sanity_test` | Basic write/read verification |
| `axi4_burst_test` | All burst types (FIXED, INCR, WRAP) |
| `axi4_boundary_test` | 4KB boundary crossing scenarios |
| `axi4_unaligned_test` | Unaligned address testing |
| `axi4_strobe_test` | Strobe edge cases (13 patterns) |
| `axi4_error_test` | Error injection scenarios |
| `axi4_b2b_test` | Back-to-back transactions |
| `axi4_random_test` | 100 random mixed transactions |
| `axi4_regression_test` | Full regression (all scenarios) |

## Sequences

The verification environment includes constrained-random sequences targeting:

1. **Burst Boundary Crossing** - Addresses near 4KB boundaries (0x1000, 0x2000)
2. **Unaligned Addresses** - Various address alignments (offsets 0-7)
3. **Strobe Edge Cases** - 13 patterns including:
   - All bytes enabled
   - Single byte (first/last/middle)
   - Alternating patterns
   - Upper/lower half
4. **WRAP Bursts** - Valid lengths (2, 4, 8, 16 beats)
5. **FIXED Bursts** - FIFO-style access patterns
6. **Error Injection** - Out-of-range, exclusive access, invalid WRAP lengths

## EDA Playground Setup

For running on EDA Playground:

1. Run the setup script to generate concatenated files:
   ```bash
   cd scripts
   ./eda_playground_setup.sh
   ```

2. Go to [EDA Playground](https://www.edaplayground.com/)

3. Create a new playground:
   - Simulator: **Cadence Xcelium** (with UVM)
   - Design tab: Paste `sim/eda_playground/design.sv`
   - Testbench tab: Paste `sim/eda_playground/testbench.sv`

4. Add simulator options:
   ```
   +UVM_TESTNAME=axi4_sanity_test +UVM_VERBOSITY=UVM_MEDIUM
   ```

5. Click **Run**

## AXI4 Protocol Overview

### Channels
- **AW (Write Address)** - Write address and control
- **W (Write Data)** - Write data with strobes
- **B (Write Response)** - Write transaction response
- **AR (Read Address)** - Read address and control
- **R (Read Data)** - Read data with response

### Burst Types
- **FIXED (0)** - Address remains constant (FIFO access)
- **INCR (1)** - Incrementing addresses
- **WRAP (2)** - Wrapping at boundary (cache line fill)

### Response Codes
- **OKAY (0)** - Normal access success
- **EXOKAY (1)** - Exclusive access success (not supported)
- **SLVERR (2)** - Slave error (out-of-range, exclusive)
- **DECERR (3)** - Decode error (4KB boundary violation)

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 64 | Data bus width in bits |
| `ADDR_WIDTH` | 32 | Address bus width in bits |
| `ID_WIDTH` | 4 | Transaction ID width |
| `MEM_SIZE` | 4096 | Memory size in bytes |

## Coverage Metrics

The environment collects:
- **Functional coverage** from monitor covergroups
- **Protocol coverage** for all burst types and lengths
- **Cross coverage** for type × length × alignment combinations
- **Structural coverage** (when enabled) for RTL code

## Assertions

Built-in protocol assertions check:
- VALID/READY handshake rules
- Reset behavior
- Burst length constraints
- 4KB boundary rules
- Response ordering

Enable with `+define+AXI4_ASSERTIONS_ON`

## Extending the Environment

### Adding New Tests
1. Create test class in `tb/tests/axi4_tests.sv`
2. Extend `axi4_base_test`
3. Instantiate/start sequences in `run_phase()`

### Adding New Sequences
1. Add sequence class to `tb/sequences/axi4_sequences.sv`
2. Extend `axi4_base_sequence`
3. Implement `body()` task with constrained items

### Adding Coverage Points
1. Add covergroups to `axi4_master_monitor.sv`
2. Sample in appropriate monitor tasks

## Troubleshooting

### Common Issues

1. **UVM_FATAL: Timeout**
   - Increase timeout in `tb_top.sv` (default 10ms)
   - Check for deadlock in handshake logic

2. **Data Mismatch in Scoreboard**
   - Enable debug verbosity: `+UVM_VERBOSITY=UVM_HIGH`
   - Check strobe handling in DUT
   - Verify address calculation for WRAP bursts

3. **DECERR Responses**
   - Transaction crosses 4KB boundary
   - Reduce burst length or align address

4. **Compilation Errors**
   - Check file order in `filelist.f`
   - Ensure UVM library path is correct

## License

This project is provided for educational and reference purposes.

## References

- ARM AMBA AXI and ACE Protocol Specification
- UVM 1.2 Reference Manual
- Accellera SystemVerilog LRM