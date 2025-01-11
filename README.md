# Fake6525

This was forked from ZXByteman/Fake6523 which is a MOS 6523 TPI (Tri Port Interface) CPLD replacement which has been proved on a 1551.

This itself was a fork of the original go4retro/Fake6523 repo from which the "Code was fixed and HW checked on real 1551 - working good."

As the 6525 behaves exactly as a 6523 when in "Mode 0" but has two additional registers and a second Mode 1 where it has added interrupts, handshaking pins and GPIO pins. I've attempted to rewrite to add the additional registers and behave as a 6525. 

I have changed the Eagle board and schematics to KiCAD. There are no changes however as the hardware is identical (same pin outs) so while KiCAD is my "preferred" program feel free to use the Eagle versions if you prefer. 

In theory this should probably work. Maybe. 
