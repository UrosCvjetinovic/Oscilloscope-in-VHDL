# Oscilloscope-in-VHDL
Implementation of an Oscilloscope on a FPGA and VGA monitor 

## Intro

The topic of the project task is the implementation of a single-channel oscilloscope that only has the capability to display an input signal. The project is implemented on an Altera DE1-SoC board with an FPGA chip using VHDL (VHSIC Hardware Description Language). The Altera Quartus II software is used for the project design.

The input signal in the form of voltage is fed to an eight-channel AD converter AD7928, which is built into the Altera DE1-SoC board. The AD7928 converts the input voltage to 12 bits, which are processed and transmitted to the signal drawing screen via a VGA cable.

## Initialization 

The input signal is selected at a frequency of 80.64KHz for 1344 samples. The AD converter (AD7928) used in this project receives and transmits data serially. Therefore, for the AD converter to work successfully, it must operate at a frequency 31 times higher than the sampling frequency. This achieves a long enough rest time, the pause between samples, for the AD converter to perform the conversion successfully. The data received by the AD converter defines its operating mode, and for this project, the AD converter operates in normal mode. The Din signal of the AD converter is set up so that the AD converter operates in normal mode (Din=1000001100010000) after the first three samples are deactivated by the reset. This avoids the first three samples, which have an incorrect value. The input data Din is sent one bit at a time at a frequency of 31*80.64KHz, for which a component is created that converts parallel input to serial at the required frequency. The CS signal is active in logical zero and is activated after two clock signal periods following the reset and deactivated after 16 clock signal periods, remaining inactive until the 31st period. 

![ADC](https://user-images.githubusercontent.com/59072921/218258952-e49f446a-d88f-448b-9f91-31fcfebc9c66.png)

During active CS signal, the Din signal is written and simultaneously the Dout signal is output (during the first activation of the Cs signal, the Dout signal is inactive). The output signal Dout is outputted serially in the format '0A2A1A0D11D10...D0', where A2A1A0 is the address of the input signal port, and D11...D0 is the converted output voltage required for further processing. Since Dout is outputted serially, it is necessary to immediately convert it to parallel output with clock signal synchronization (the parallel output clock signal will now be 80.64 kHz). After parallel outputting the Dout signal, double buffering of the data is performed. Double buffering is achieved by having both buffers work on the same clock, the sampling clock, and the rd_wr signal that is one of the complemented inputs of this signal. One buffer writes data to the input and communicates with the AD converter with a logical one on its input, while the other outputs the values that it has stored in the previous cycle and communicates with the signal drawing screen via the VGA cable.


## Implementation description of VHDL code

- PS - Parallel-in to Serial-out (PISO) Shift Register
The component ps.vhd converts a 16-bit word generated by the state of the adccontroller.vhd component into a signal synchronized with the clock signal and lasts for 16 clock cycles, where in each cycle the highest unwritten bit of the 16-bit word is output. This component is synchronized with the CS signal using the enable_ps signal and is used to forward the Din word to the control register of the AD converter.

 - SP - The SP (Serial-in to Parallel-out) 
Shift Register component in sp.vhd stores the bits of the Dout signal generated by the AD converter in a 16-bit word, which is passed on to both sample_buffer.vhd components. This procedure stores one sample in the buffer responsible for writing, and after 1344 samples the roles of the buffers are swapped. This component is synchronized with the CS signal through the enable_sp signal and is used to pass the Din word to the control register of the AD converter.

- ADCCONTROLER
The component adccontroler.vhd generates all auxiliary signals used for synchronization of writing and reading from the AD converter. It also has two states, startup_mode and normal_mode, which serve to skip the first three samplings after establishing the voltage (which is considered after deactivating the reset). The first three samplings are skipped by not generating the clock for loading into the buffer and the buffer enable signal during that period.

![wavedrom](https://user-images.githubusercontent.com/59072921/218258751-50d4ef76-1f77-4f3c-97ea-5fb7bfbd8bc9.png)

- SAMPLE_BUFFER
The SAMPLE_BUFFER component achieves double buffering through two sample_buffer.vhd components that alternate between writing to one buffer and reading samples from the other buffer using the r_sample_clk clock signal and the rd_wr signal generated by the adccontroler.vhd component. This ensures that the VGA channel image is uninterrupted, and that data is read from the AD converter and the previous 1344 samples are drawn on the screen at the same time.

- PLL
The component pll.vhd is used to raise the clock signal from 50 MHz to 65 MHz required for working with the screen through the VGA channel.

- VGA_SYNC
The vga_sync.vhd component is used for synchronizing the signal generated by the image on the screen with the oscilloscope.vhd component.

- VGA logic
Drawing on the monitor screen is achieved by comparing the value of the sample at position hpos in the buffer with the value of vpos, with a certain offset that centers the zero on the middle of the screen. The background and signal color, as well as potential modifications in this project, can be configured.

## Block diagram
![Osciloskop](https://user-images.githubusercontent.com/59072921/218258791-bfe03343-7ae6-4b1f-b0d9-499bd740b343.png)

