# FPGA-Based-CNN-Accelerator-on-Zynq-Soc

## Overview
This project implements a hardware-accelerated **Convolutional Neural Network (CNN)** layer on the **Xilinx Zynq-7000 SoC (Zybo Z7-20)**. The accelerator performs real-time **Edge Detection** using a 3x3 Sobel-like filter.

The system offloads computationally intensive convolution operations from the ARM Cortex-A9 CPU to the FPGA logic (PL), utilizing **AXI DMA** for high-speed data transfer via **AXI4-Stream** interfaces.

## System Architecture
The system consists of the Processing System (PS) and Programmable Logic (PL) connected via AXI Interconnects.
<img width="2088" height="770" alt="Image" src="https://github.com/user-attachments/assets/b5a1c1f0-34f3-43f2-a624-c53f39624cea" />

1.  **Processing System (PS):**
    * Generates synthetic image data (Test Pattern).
    * Configures the AXI DMA controller.
    * Handles Cache Coherency (Flush/Invalidate) between DDR and FPGA.
2.  **AXI DMA:**
    * Reads image data from DDR Memory (MM2S).
    * Writes processed results back to DDR Memory (S2MM).
3.  **Custom CNN Accelerator IP (PL):**
    * **Line Buffer (Sliding Window):** Converts incoming serial pixel stream into parallel 3x3 pixel windows.
    * **Convolution Unit (MAC):** Performs parallel multiply-accumulate operations with a fixed 3x3 kernel.


## Hardware Design Details (RTL)

### 1. Sliding Window Unit (Line Buffer)
* Implemented using **Shift Registers** to store previous rows of the image.
* Handles boundary conditions and stream latency.
* **Input:** 8-bit Gray-scale pixel stream.
* **Output:** Flattened 9-pixel array (3x3 window) for the MAC unit.

### 2. MAC (Multiply-Accumulate) Unit
* Performs 9 parallel multiplications and accumulations in a single clock cycle.
* **Kernel Used (Edge Detection):**
    ```text
    -1  -1  -1
    -1   8  -1
    -1  -1  -1
    ```
* Supports signed integer arithmetic to handle negative edge values.

## Simulation & Verification

The RTL logic was verified using Vivado Xsim before synthesis.

### Sliding Window Verification
* Verified that the serial input stream is correctly converted into a 3x3 window.
* Confirmed correct data shifting for Top, Middle, and Bottom rows.
<img width="2256" height="774" alt="Image" src="https://github.com/user-attachments/assets/9593542a-04df-4643-a35e-f46f2b29007a" />


### Convolution MAC Verification
* Verified the arithmetic accuracy of the edge detection kernel.
* Confirmed that flat regions output `0` and edges output high magnitudes (e.g., `±570`).

<img width="2072" height="518" alt="Image" src="https://github.com/user-attachments/assets/7d13184a-c381-400f-869c-f2f6c133764b" />


## Software Implementation (Vitis)

The bare-metal C driver running on the ARM Cortex-A9 performs the following:

1.  **Synthetic Data Generation:** Creates a 28x10 test image with a vertical edge (Dark region `10` vs Bright region `200`).
2.  **Cache Management:** Flushes the Data Cache (`Xil_DCacheFlush`) to ensure DMA reads the correct data from DRAM.
3.  **DMA Transfer:** Initiates AXI DMA transfers (MM2S & S2MM) in Polling Mode.
4.  **Result Visualization:** Reads the processed data and visualizes the detected edges using ASCII art in the UART terminal.

---

## Experimental Results

The system was tested on the actual hardware. The accelerator successfully detected the vertical edges in the test pattern.

* **Input:** Square box pattern (pixel value 200) on a dark background (pixel value 10).
* **Output:** Vertical lines (`||`) detected at the boundaries of the box.

![Image](https://github.com/user-attachments/assets/b209b0d6-f274-4ea4-a460-aed229f174ab)

