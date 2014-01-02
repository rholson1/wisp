====
WISP
====

WISP is a MATLAB-based program for creating and running experimental paradigms such as the Head-Turn Preference Protocol and Looking-While-Listening.


Installation
------------

Installation instructions are given in sw_install.pdf_ , located in the Downloads section.  
In the Branches tab of the Downloads section, you can download the entire WISP_ repository as a .zip file.  Other files in the Downloads section describe a possible hardware setup that could be used with WISP.  Unfortunately, some of the hardware described is no longer available.


Prerequisites
-------------

WISP has some prerequisites: Matlab, PsychToolbox, and MPlayer.  A complete list of prerequisites and sources is provided in sw_install.pdf.


32-Bit vs 64-Bit
----------------
When WISP was written, PsychToolbox was 32-bit only, so the 32-bit version of Matlab was required.  A 64-it version of PsychToolbox is now available, but WISP still doesn't work with 64-bit Matlab + 64-bit PsychToolbox.  I suspect the problem is related to MPlayerControl.exe, which acts as an interface to MPlayer from Matlab.  Someday I will look into this, but in the meantime, the 32-bit vesions seem to work fine, and are required.


.. _sw_install.pdf: https://bitbucket.org/rholson1/wisp/downloads/sw_install.pdf
.. _WISP: https://bitbucket.org/rholson1/wisp/get/default.zip


