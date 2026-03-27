# pointer G-1 Pure Data Patch
This patch is inspired by [Yann Seznec's ys.granular patch](https://github.com/yannseznec/ys.granular), which I used as a foundation to figure out what elements I needed to build my own granular effects unit. The patch has undergone major changes to be usable in a live performance environment, while remaining lightweight on a Raspberry Pi. The main deviation from the original patch is the use of delwrite~ buffers to avoid problems with static buffers, such as clicks and undesirable loop points. Among many other things, I added a lookahead limiter, a per-grain delay, a neural network using Flucoma, some optimisations, and new mappable parameters.

The Pd version I used was 0.56.2 and the following libraries are necessary to run the patch:
- comport
- cyclone
- FluidCorpusManipulation
- oscP5 in Processing

As this patch is custom-made for my specific Raspberry Pi 5 setup, the playability is quite limited. If you have the necessary hardware, these are the steps to get this to run:
1. Ensure all libraries are installed via Deken.
2. Make sure you are running on a sample rate of 44.1 kHz.
3. Open _main.pd.
4. Change the devicename message box in front of the comport object to your device.
5. Output values from a microcontroller should be between 0 and 1022 (the code I used is also included).
6. Run the Processing patch and make sure both sides are connected over the correct OSC IP address.
7. Use the mouse movement to control the neural network.


This is the device that's running the patch. A separate repository is coming soon.

![Image1](https://github.com/user-attachments/assets/4a28dc39-c1f8-4987-92e3-356913420f2e)
