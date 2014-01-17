The primary purpose of MPlayerControl is to allow asynchronous control
of MPlayer from Matlab.  It also uses DirectSound to generate a list
of available audio devices for display in the WISP GUI.

Two versions of MPlayerControl are provided here:

MPlayerControl_x86.exe has a reference to
Microsoft.DirectX.DirectSound, which is included in the DirectX
End-User Runtime available from Microsoft.  This version ONLY works
with 32-bit versions of Matlab because only a 32-bit version of the
DirectSound library is available from Microsoft.

MPlayerControl.exe has references to SharpDX.dll and
SharpDX.DirectSound.dll, which are available from sharpdx.org.  This
version works with both 32 and 64-bit versions of Matlab.  SharpDX is
distributed under the MIT License, reproduced below.

Copyright (c) 2010-2012 SharpDX - Alexandre Mutel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
