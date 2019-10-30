====
WISP
====

WISP is a MATLAB-based program for creating and running experimental paradigms such as the Head-Turn Preference Protocol and Looking-While-Listening.


Install Prerequisites
---------------------

1. Install Matlab_.  The 64-bit version of Matlab is required for compatibility with PsychToolbox.  Note that Matlab R2018a has a bug which will prevent WISP from playing videos; this is fixed in 2018a Update 3.

2. Install PsychToolbox_.

3. Install SMPlayer_, a video playback package which includes MPlayer, the program WISP uses to play videos.  The version of MPlayer included with SMPlayer 0.8.6 is known to work with WISP.  More recent versions have a modified system for positioning windows on multiple-monitor desktops, and WISP does not yet support the newer approach.


Install WISP_
-------------

1. In the Branches tab of the Downloads section, you can download the entire WISP_ repository as a .zip file.  Alternatively, if you have git installed, clone the repository using:

   git clone https://github.com/rholson1/wisp.git

2. Copy the WISP folder from the WISP package to some sensible location on your hard disk, such as C:\\toolboxes\\WISP.  If you choose a different location, adjust the following instructions accordingly.

3. Make site-specific changes to WISP function **GetMPlayerExecutable.m**.

   WISP needs to know where mplayer.exe is located.  Update GetMPlayerExecutable.m in the WISP directory to reflect the location on your system, which will be within the SMPlayer program directory.  You will probably want to change the line which begins ``mplayerpath =`` to something like::
     
     mplayerpath = 'C:\Program Files\SMPlayer\MPlayer\mplayer.exe';

4. Add the WISP folder to your Matlab path::

     >> addpath C:\toolboxes\WISP
     >> savepath


.. _Matlab: http://www.mathworks.com
.. _PsychToolbox: http://psychtoolbox.org
.. _SMPlayer: https://sourceforge.net/projects/smplayer/files/SMPlayer/0.8.6/
.. _WISP: https://bitbucket.org/rholson1/wisp/get/default.zip


