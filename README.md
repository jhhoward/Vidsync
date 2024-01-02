# Vidsync for Book 8088

## What is this?
The Book 8088 DOS laptop sometimes has a problem with centering the picture correctly in its LCD display. Vidsync is a simple program designed to fix this issue.

## How does it work?
The Book 8088's display fails to calibrate correctly if the image being displayed doesn't have a clear boundary and is particularly problematic if the screen is blank after switching screen modes.

Vidsync is a terminate and stay resident (TSR) program that intercepts the BIOS call to set the video mode. Immediately after setting a new screen mode, the program will enable a pixel in the top left and bottom right of the screen and pause for a short period of time to allow the display an opportunity to correctly calibrate the screen's position.

The program only needs to be run once and can be added to your AUTOEXEC.BAT during startup.

## Points to note
* There is currently no way to remove the TSR from memory other than to reboot your machine. 
* Don't run the program twice as it won't check to see if it is already in memory!
* The delay when setting a screen mode has been adjusted based on a Book 8088 V2 with a V20 in turbo mode. When running in 4.77Mhz, the delay will take longer that needed.
