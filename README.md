# pointer G-1 Pure Data Patch
This patch is inspired by [yann seznec's ys.granular patch](https://github.com/yannseznec/ys.granular), which I used as a foundation to figure out what elements I needed to build my own granular effects unit. The patch has undergone major changes to be usable in a live performance environment, while being able to run lightweight on a Raspberry Pi. The main deviation from the original patch is using delwrite~ buffers to avoid problems with static buffers like clicks and undesirable loop points. Among many other things, I added a lookahead limiter, a per-grain delay, a neural network using Flucoma, some optimisations, and new mappable parameters.

The pd version I used was 0.56.2 and the following libraries are necessary to run the patch:
- comport
- cyclone
- FluidCorpusManipulation

This is the device thats running the patch. A seperate repository is comming soon.

![Image1](https://github.com/user-attachments/assets/4a28dc39-c1f8-4987-92e3-356913420f2e)
