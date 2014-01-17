====
WISP
====

WISP is a MATLAB-based program for creating and running experimental paradigms such as the Head-Turn Preference Protocol and Looking-While-Listening.


Installation
------------

A. Install prerequisistes.

   1. Install Matlab_.  Both 32-bit and 64-bit versions of Matlab are now supported.

   2. Install PsychToolbox_.

   3. Install SMPlayer_, a video playback package which includes MPlayer, the program WISP uses to play videos.

B. Install WISP_

   1. In the Branches tab of the Downloads section, you can download the entire WISP_ repository as a .zip file.  Other files in the Downloads section describe a possible hardware setup that could be used with WISP.  Unfortunately, some of the hardware described is no longer available.

   2. Copy the WISP folder from the WISP package to some sensible location on your hard disk, such as C:\toolboxes\WISP.  If you choose a different location, adjust the following instructions accordingly.

   3. Make site-specific changes to WISP function **GetMPlayerExecutable.m**.

      WISP needs to know where mplayer.exe is located.  Update GetMPlayerExecutable.m in the WISP directory to reflect the location on your system, which will be within the SMPlayer program directory.  You will probably want to change the line which begins ``mplayerpath =`` to something like::

      mplayerpath = 'C:\Program Files\SMPlayer\MPlayer\mplayer.exe';

   4. Add the WISP folder to your Matlab path::

      >> addpath C:\toolboxes\WISP
      >> savepath


.. _Matlab: http://www.mathworks.com
.. _PsychToolbox: http://psychtoolbox.org
.. _SMPlayer: http://smplayer.sourceforge.net
.. _WISP: https://bitbucket.org/rholson1/wisp/get/default.zip


