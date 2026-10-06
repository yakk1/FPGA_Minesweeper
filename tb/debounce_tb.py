import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ValueChange, with_timeout, SimTimeoutError, ReadOnly
from cocotb.utils import get_sim_time as gst
from cocotb_tools.runner import get_runner 
from cocotb.clock import Clock


class PulseMonitor:
    def __init__(self, dut):
        self.dut = dut
        self.pulse_count = 0

    async def start(self):
        prev_out = 0
        while True:
            await RisingEdge(self.dut.clk)
            await ReadOnly()

            curr_out = int(self.dut.out.value)

            # Invariant 1
            if (prev_out == 1):
                assert curr_out == 0, "Error, out was high for more than one clock cycle"

            # Count every new pulse
            if (curr_out == 1 and prev_out == 0):
                self.pulse_count += 1
                self.dut._log.info(f"Monitor detected pulse #{self.pulse_count} at {gst(units='ns')} ns")
            prev_out = curr_out

# Reset device (Active High)
async def reset_dut(dut):
    dut.reset.value = 1
    await Timer(24, unit="ns")
    dut.reset.value = 0

# Simulate a button press on debounce module
@cocotb.test()
async def debounce_tb(dut):

    # Start the clock (1 MhZ)
    clock = cocotb.start_soon(Clock(dut.clk, 1, unit="us").start())

    # Start monitor
    monitor = PulseMonitor(dut)
    cocotb.start_soon(monitor.start())

    # Reset dut
    dut.btn_in.value = 0
    await reset_dut(dut)

    # Test 1: Single press, check for 1 pulse of 1 cycle width
    monitor.pulse_count = 0

    dut.btn_in.value = 1
    await Timer(0.5, unit = "ms")
    dut.btn_in.value = 0
    await Timer(1.1, unit="ms")
    assert monitor.pulse_count == 1, f"Expected 1 pulse, but monitor saw {monitor.pulse_count}"
    
    # Test 2: Long press, check for 1 pulse of 1 cycle width
    monitor.pulse_count = 0

    dut.btn_in.value = 1
    await Timer(3, unit = "ms")
    dut.btn_in.value = 0
    await Timer(1.1, unit="ms")
    assert monitor.pulse_count == 1, f"Expected 1 pulse, but monitor saw {monitor.pulse_count}"

    # Test 3: Single press, with noise check for 1 pulse of 1 cycle width
    monitor.pulse_count = 0

    dut.btn_in.value = 1
    await Timer(0.1, unit = "ms")
    dut.btn_in.value = 0
    await Timer(0.1, unit = "ms")
    dut.btn_in.value = 1
    await Timer(0.1, unit = "ms")
    dut.btn_in.value = 1
    await Timer(0.6, unit = "ms")
    dut.btn_in.value = 0
    await Timer(1.1, unit="ms")
    assert monitor.pulse_count == 1, f"Expected 1 pulse, but monitor saw {monitor.pulse_count}"
    
    #Test 4: Single press, then another press
    monitor.pulse_count = 0

    dut.btn_in.value = 1
    await Timer(0.5, unit = "ms")
    dut.btn_in.value = 0
    await Timer(1.1, unit="ms")
    dut.btn_in.value = 1
    await Timer(0.5, unit = "ms")
    dut.btn_in.value = 0
    await Timer(1.1, unit="ms")
    assert monitor.pulse_count == 2, f"Expected 2 pulses, but monitor saw {monitor.pulse_count}"

    # Reset dut
    dut.btn_in.value = 0
    await reset_dut(dut)



def debounce_runner():
    """Simulate the debounce module using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "tb" / "model"))
    sources = [proj_path / "src" / "debounce.sv"] #grow/modify this as needed.
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {
        "WAIT_TIME_MS": 1,      
        "CLK_FREQ": 1_000_000
    }
    sys.path.append(str(proj_path / "tb"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="debounce",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="debounce",
        test_module="debounce_tb",
        test_args=run_test_args,
        waves=True,
        plusargs=["+WAVE_FILE=" + str(proj_path / "tb" / "debounce_tb_waves.vcd")]
    )
 
if __name__ == "__main__":
    debounce_runner()