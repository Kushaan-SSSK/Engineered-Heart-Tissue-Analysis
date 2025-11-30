**Introduction**

The EHT assay device consists of several components:

- A frame that supports a mechanical stage above a video camera. There is white light illumination for the video camera and a high intensity blue LED for optical pacing.
- An Arduino running software (EHT-controller) that controls the camera, optical pacer, and white light illumination.
- A PC connected to the mechanical stage and the Arduino. Using MicroManager as the hardware controller and the BeanShell script EHT-acquire, the PC automates multiwell acquisition.
- Post-acquisition video analysis using MATLAB (EHT_motion_tracker) to yield EHT post positions over time.
- Force analysis in MATLAB (analyze_EHT), which analyzes post position vs time to calculate contraction and relaxation kinetics and force.

**Software Workflow:**
1. Image acquisition: MicroManager with BeanShell script (`EHT_acqure_v2.bsh`)
2. Motion tracking: MATLAB (`EHT_motion_tracker.m`)
3. Force analysis: MATLAB (`analyze_EHT.m`)

All analysis is now performed in MATLAB for a unified workflow. See `Code/README_MATLAB.md` for detailed software documentation.

**Assembly of the EHT assay device.**

Refer to ItemList.xlsx and EHT-scope-schematics.pdf

1. **Assemble the EHT assay device frame (See Fig. 1)**

Assemble the frame for the device using 80/20 10 series profiles, following the schematics in Fig. 1. Cut the profiles to length using a miter saw with a blade for cutting aluminum. This frame holds the mechanical stage above the camera and lens and below the pacing LEDs. The frame dimensions should be adjusted to fit the select XY stage.

2. **Attach the frame to the aluminum base plate (See Fig. 1)**

Attach the rubber damping feet to the aluminum base plate.

Use the right angle brackets to attach the 80/20 frame to the base plate.

Use two 6” vertical brackets to attach the vertical strut to the base plate.

3. **Attach the mechanical stage to the frame (See Fig. 1)**

We used a spare Prior H101A stage. This stage was designed for an upright microscope and needed modifications to work in this inverted application. It would be better to use a stage designed for an inverted microscope.

4. **Assemble the camera and lens (See Fig. 2)**

3D print the mount that holds the ring light and long pass filter on the lens. Use a glue gun to attach the ring light and long pass filter to the mount. Solder long wires to the ring light. The mount fits into the threads on the end of the lens. Attach the lens to the camera. Mount the camera on the linear actuator using the 3D printed camera mount. Mount the linear actuator to the vertical strut using the 3D printed actuator holder. Wire the linear actuator to its controller and its AC/DC transformer, following the instructions on the Actuonix website. Solder the ground and signal wires to a BNC cabinet connector.

5. **Assemble the pacing LEDs (see Fig. 3 and 4)**

Place the Teflon sliders in the T-tracks on the top rails of the frame. Also put the stopper bolts into these T-tracks. Cut one aluminum bar so it spans the frame and a shorter aluminum bar about ½ the length of the first. Drill holes in the longer aluminum bar, one pair for the bolts on the Teflon sliders, and one pair to mount the shorter bar. Cut slots into the shorter bar so that its position can be adjusted with respect to the upper bar. Attach the 2 blue pacing LEDs using thermal epoxy. Solder long wires to the blue pacing LEDs. Snap the lens covers on the pacing LEDs. Mount the shorter bar under the longer using screws, springs, and wing nut. This will allow you to be able to adjust the height and location of the pacing lights so that it is centered above the camera and just above the top of the stage top incubator. Use the long wires to connect the pacing lights to the high-power LED drivers, mounted in the 3D printed LED driver case. Solder the LED driver inputs to BNC cabinet connectors. Pass the long wires from the ring light into the LED driver case and solder them to BNC cabinet connectors. Inside the LED driver case, connect the 12V AC/DC transformer to the LED drivers and connect the ring light AD/DC transformer to the long wires from the ring light.

6. **Assemble the Arduino (See Fig. 4)**

3D print the Arduino case. Build the RGB LCD shield, which is the user interface for the Arduino. Instructions on Adafruit website. Wire the Arduino as follows: Pin 5 for white LED ring light. Pin 6, Blue pacing LEDs. Pin 10, linear actuator. Each of these wires is soldered to the central terminal on a cabinet BNC connector, attached to the Arduino case. Solder a wire to each of the 3 outer BNC terminals. Solder the other end to a wire from the GND. Wire the RGB LCD shield. On the RGB shield board, we refer to the bottom row of 12 holes counting left to right, with the hole nearest the reset button being 12. Red from hole 3 to Arduino 5V. Black from hole 5 to Arduino GND (next to the 5V pin). Green from hole 11 to Arduino A4. White from hole 12 to Arduino A5. Use BNC connectors to connect the Arduino to the pacing LED driver, white LED ring light, and linear actuator.

Plug the Arduino into the computer using a USB cable. Upload EHT-controller.ino to the Arduino.

7. **Configure EHT-assay-device.**

Unplug and plug in the USB connector to the Arduino. The code should run. Use keys next to the LCD to select focus. Adjust the position of the camera using the up and down arrows on the Arduino so that the camera is focused on the EHT posts when they are placed within 24w dish inside the stage incubator. Adjust the height of the pacing assembly and center the pacing LEDs over the center of the lens. Make sure that the mechanical stage can move all of the well positions over the lens center.

8. **Install and configure micromanager.**

Install Basler camera pylon 6 SDK. Install micromanager 1.4. Configure it to use the Prior stage, the Basler camera, and the Arduino-Hub. Load and run the BeanShell code for EHT-acquire, which controls automated image acquisition. On the Arduino, select the “Run” option so that the computer can control the acquisition.

9. **Configure MATLAB for post motion analysis**

Install MATLAB (R2016b or later) with the following toolboxes:
- Image Processing Toolbox
- Curve Fitting Toolbox

The MATLAB code for motion tracking and force analysis is located in the `Code/EHT-analyze/` folder:
- **EHT_motion_tracker.m** - Analyzes EHT video images and yields a table of position vs time
- **EHT_motion_tracker_gui.m** - GUI interface for motion tracking
- **analyze_EHT.m** - Analyzes post position vs time to calculate contraction/relaxation kinetics and force

**Quick Start:**
```matlab
% In MATLAB, navigate to Code/EHT-analyze/
EHT_motion_tracker_gui()  % Run motion tracking with GUI
```

See `Code/README_MATLAB.md` for detailed installation and usage instructions.

**Note:** The previous ImageJ/Fiji-based workflow has been replaced with a unified MATLAB workflow for easier use and better integration.
