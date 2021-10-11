# 3D_Scan_Road

This repository contains data used when making this youtube-video: https://youtu.be/4V6TXG68Qa0

GNSS-stylus, V1.4.0 was used to log and post-process the data. It's downloadable here: https://github.com/GNSS-Stylist/GNSS-Stylus/releases/tag/V1.4.0

Overall directory structure:

* Godot_Playback: Project made in Godot engine that can be used to "playback" the scanning data. This was used to generate CGI-parts and overlays for the youtube video. Godot-version used was v3.3.3.rc1, but any 3.3.x-version (and probably later ones) will most likely work. See more detailed readme.md in the directory itself. Directories:
  
  * GNSS_Stylus_Scripts: Files generated using GNSS-Stylus' Post-processing.
  
  * GroundRock, MB100D_Full, MB100D_RigRemoved, Objects: 3D-models generated from the point clouds using MeshLab.

* Logs_Params: Raw log files and parameters used when post-processing the data using GNSS-Stylus-application. These files can be used in the application's post-processing operations (use "Files->Add from files including other fields (parameters)..." to read all at once). Includes data from GNSS- and lidar-devices. For indivisual file types please see explanations from https://github.com/GNSS-Stylist/3D_Scan_HareStatue. Directories/files:

  * CameraWalks: Logs and params from a rig that was operated by hand (like in the youtube-video when following the "scan van" when it starts to scan). There are more of these, but only one was used in the video. There are also camera calibration logs.
  
  * CarDrive: Logs and params from a rig that was installed into the roof of a car (speed about 20...30 km/h). "DrivingBack*.*" were logged when driving back faster (like 40 km/h) on the road, but these were not used in the video.
  
  * Extract_Me_RoadScan.zip: Logs and params from "scan van". Zipped due to github's file size limitation of 100 MB. Lidar data is about 170 MB unpacked. Extract before use.
