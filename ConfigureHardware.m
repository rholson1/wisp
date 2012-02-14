function C = ConfigureHardware(C_init)
% ConfigureHardware - GUI tool to select display locations and audio channels.
%
% C = ConfigureHardware();
% 
% ConfigureHardware displays a GUI which allows association of monitors and
% audio channels with named output locations.  At completion, the function
% returns the configuration information in a structure.
%
%
%
% Dependencies: PsychToolbox-3 with PsychPortAudio
%               MPlayer, MPlayerControl
%
% 2010-04-05 Created by Robert H. Olson, Ph.D., rolson@waisman.wisc.edu

C = []; % Create variable
%% Initial values for C
% Eventually, these values should come from an argument to the function
% so that C = ConfigureHardware(C_init) uses the contents of C_init as
% initial values for the form.

if nargin == 0
  C.NumOL = 2;
  C.UsePsychPortAudio = 0;
  C.ImageDisplayMode = 1;
  C.OL(1).Name = 'Left';
  C.OL(2).Name = 'Right';
  C.OL(1).Key = '4';
  C.OL(2).Key = '6';
  
  C.OL(1).AudioDevice = []; % The third audio device with audio outputs
  C.OL(1).AudioChannels = [1 2];
  
  C.OL(1).DisplayCoords = [1 1 1280 1024];
  C.OL(1).Fullscreen = 1;
  
  %C.OL(1).Balance = 0; % Audio balance for videos [-9000 9000] (MEDIAPLAYER)
  C.OL(1).VideoAudioDevice = 1;          % Audio device used for videos
  C.OL(1).VideoAudioChannels = [1 2];    % Audio channels used for videos
else
  C = C_init;
  if ~isfield(C,'ImageDisplayMode'), C.ImageDisplayMode = 1; end
end

%% Global Variables

workingOL = 1;

% Check version (and existance of) Psychtoolbox.
try 
  PTBver = PsychtoolboxVersion;
catch
  PTBver = 0;
end

if PTBver < 3
  errordlg(['Psychtoolbox-3 is required for audio output, but was not found.  ' ...
            'For information about installation of PTB-3, see ' ...
            'http://psychtoolbox.org.'], 'Psychtoolbox-3 Not Found');
  return
end

if verLessThan('matlab','7.9') % older than R2009b
  % Use COM to access MPlayerControl
  
  % Try to start MPlayerControl
  try
    mplayer = actxserver('MPlayerControl.MPlayerControl');
    mplayer.Executable = GetMPlayerExecutable();
    VideoAudioDeviceList = regexp(mplayer.DeviceList,'\|','split');
  catch e
    errordlg(['Problem starting MPlayerControl.  Make sure that MPlayerControl has been installed.' e.message], ...
      'MPlayerControl Error');
    return
  end
else
  % Use .NET to access MPlayerControl
  
  % Load MPlayerControl as a private .NET assembly
  % (should be loaded already, but this will allow ConfigureHardware to be run
  % independenly of WISP as a diagnostic tool)
  try
    mpcfile = fullfile(fileparts(mfilename('fullpath')),'mpc','MPlayerControl.exe');
    NET.addAssembly(mpcfile);
  catch ME
    disp(['Problem adding MPlayerControl assembly. ' ME.message])
  end
  
  % Try to start MPlayerControl
  try
    mplayer = MPlayerControl.MPlayerControl;
    mplayer.Executable = GetMPlayerExecutable();
    VideoAudioDeviceList = regexp(mplayer.DeviceList.char,'\|','split');
  catch e
    errordlg(['Problem starting MPlayerControl.  Make sure that MPlayerControl has been installed.' e.message], ...
      'MPlayerControl Error');
    return
  end
end

%-------------------------------------------------------------------------
%  Audio Devices
%-------------------------------------------------------------------------

% Get info about audio devices
InitializePsychSound;

% Get a structure array of audio devices
AudioDevices = PsychPortAudio('GetDevices');
% Identify which audio devices have output channels
AudioOut = find([AudioDevices.NrOutputChannels] > 0); 

% List of Audio Output devices
AudioDeviceList = arrayfun(@(x)[x.DeviceName ' (' x.HostAudioAPIName ')'],AudioDevices(AudioOut),'UniformOutput',false)';

%-------------------------------------------------------------------------
% Display Devices
%-------------------------------------------------------------------------
DisplayDevices = get(0,'MonitorPosition');
DisplayDeviceList = cellstr(num2str(DisplayDevices));
%-------------------------------------------------------------------------
% UI 
%-------------------------------------------------------------------------
h.fs = 10; % fontsize

if ispref('SaffranExperiment','Position')
  xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure
else
  xy = [200 200];
end

f = figure('Name', 'Output Locations', ...
  'Visible', 'on', ...
  'NumberTitle', 'off', ...
  'IntegerHandle', 'off', ...
  'Resize', 'off', ...
  'MenuBar','none', ...
  'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
  'Position',[xy 540 600]);%,...
  %'WindowStyle','modal');


m = get(0,'MonitorPosition');
NumDisplays = size(m,1);

% Select number of output locations
uicontrol('style','text','string','Number of Output Locations : ', ...
  'position',[20 560 200 25],'fontsize',h.fs);
h.txtOL = uicontrol('style','edit','backgroundcolor','w', ...
  'position',[220 565 30 25],'fontsize',h.fs,'string',num2str(C.NumOL), ...
  'callback',@txtOL_edit);
uicontrol('style','text','string',['(' num2str(NumDisplays) ' displays found)'], ...
  'position',[250 560 150 25],'fontsize',h.fs);

% Output Location Configuration Panel
h.panelOL = uipanel('title',['Configure Output Location ' num2str(workingOL)], ...
  'fontsize',h.fs,'units','pixels','position',[10 110 522 410]);
uicontrol(h.panelOL,'style','pushbutton','string','-','fontsize',h.fs, ...
  'position',[190 390 20 25],'callback',{@changeOL,-1});
uicontrol(h.panelOL,'style','pushbutton','string','+','fontsize',h.fs, ...
  'position',[210 390 20 25],'callback',{@changeOL,1});

% Name
uicontrol(h.panelOL,'style','text','string','OL Name :','fontsize',h.fs, ...
  'position',[10 350 80 25]);
h.txtName = uicontrol(h.panelOL,'style','edit','string',C.OL(workingOL).Name,'fontsize',h.fs, ...
  'position',[110 355 120 25],'backgroundcolor','w','callback',@txtName_edit);
% Key 
uicontrol(h.panelOL,'style','text','string','Response Key :','fontsize',h.fs, ...
  'position',[250 350 100 25])
h.txtKey = uicontrol(h.panelOL,'style','edit','string',C.OL(workingOL).Key,'fontsize',h.fs, ...
  'position',[350 355 80 25],'backgroundcolor','w','KeyPressFcn',@txtKey_keypress);

% Audio Panel
h.panelAudio = uipanel(h.panelOL,'title','PsychPortAudio','fontsize',h.fs, ...
  'units','pixels','position',[10 190 500 140]);
% Audio Device
uicontrol(h.panelAudio,'style','text','string','Audio Device :','fontsize',h.fs, ...
  'position',[10 90 100 25]);
h.cboAudio = uicontrol(h.panelAudio,'style','popupmenu','fontsize',h.fs,...
  'position',[110 95 350 25],'string',AudioDeviceList,'Value',1,...
  'backgroundcolor','w','callback',@cboAudio_change);
% Audio Channel(s)
uicontrol(h.panelAudio,'style','text','string','Channel(s) :','fontsize',h.fs, ...
  'position',[10 60 100 25]);
h.lstChannels = uicontrol(h.panelAudio,'style','listbox','fontsize',h.fs,...
  'position',[110 10 100 75],'max',2,'backgroundcolor','w',...
  'callback',@lstChannels_change);
% uicontrol(h.panelAudio,'style','text','position',[230 10 250 75],...
%   'string',['Note that channel selection only works with ASIO soundcard drivers.  ' ... 
%   'If an ASIO driver specific to your soundcard is not available, try ASIO4ALL.'], ...
%   'fontsize',h.fs,'horizontalalignment','left');


% Video Panel
h.panelVideo = uipanel(h.panelOL,'title','Video / Audio','fontsize',h.fs, ...
  'units','pixels','position',[10 10 500 165]);

% Display
uicontrol(h.panelVideo,'style','text','string','Detected Displays :','fontsize',h.fs, ...
  'position',[10 115 150 25]);
h.cboDisplay = uicontrol(h.panelVideo,'style','popupmenu','fontsize',h.fs, ...
  'position',[160 120 200 25],'backgroundcolor','w',...
  'callback',@cboDisplay_change,'string',DisplayDeviceList);

% Coordinates
uicontrol(h.panelVideo,'style','text','string','Output Coordinates :','fontsize',h.fs, ...
  'position',[10 85 150 25]);
h.txtDisplayCoords = uicontrol(h.panelVideo,'style','edit','fontsize',h.fs, ...
  'position',[160 90 200 25], 'backgroundcolor','w', ...
  'callback',@txtDisplayCoords_edit);

% Fullscreen
h.chkFullscreen = uicontrol(h.panelVideo,'style','checkbox','string','Fullscreen', ...
  'position',[370 90 100 25],'callback',@chkFullscreen_change,'fontsize',h.fs);

% Audio for Video
uicontrol(h.panelVideo,'style','text','string','Audio Device :','fontsize',h.fs, ...
  'position',[10 55 150 25]);
h.cboVideoAudio = uicontrol(h.panelVideo,'style','popupmenu','string',VideoAudioDeviceList, ...
  'position',[160 60 250 25],'backgroundcolor','w','fontsize',h.fs, ...
  'callback',@cboVideoAudio_change);
uicontrol(h.panelVideo,'style','text','string','Channel(s) :','fontsize',h.fs, ...
  'position',[10 25 150 25]);
h.lstVideoAudioChannels = uicontrol(h.panelVideo,'style','listbox','fontsize',h.fs, ...
  'position',[160 10 60 45],'string',{'0','1'},'backgroundcolor','w','max',2, ...
  'callback',@lstVideoAudioChannels_change);
uicontrol(h.panelVideo,'style','text','fontsize',h.fs,'position',[240 10 240 45],'string', ...
  ['Audio in video files is played using Windows DirectSound. ' ...
  ' Devices are assumed to have two channels.'],'horizontalalignment','left');

% PsychPortAudio Checkbox
h.chkUsePsychPortAudio = uicontrol(f,'style','checkbox','fontsize',h.fs, ...
  'string','Use PsychPortAudio','position',[20 70 200 25], ...
  'value',C.UsePsychPortAudio,'callback',@chkUsePsychPortAudio_change);

% Image Display Mode
uicontrol('style','text','fontsize',h.fs,'string','Image Display Mode',...
  'position',[270 65 140 25]);
h.cboImageDisplayMode = uicontrol(f,'style','popupmenu','string',{'center' 'fit' 'stretch'}, ...
  'position',[410 70 100 25], 'backgroundcolor', 'w', 'fontsize', h.fs, ...
  'value',C.ImageDisplayMode,'callback',@cboImageDisplayMode_change);

% Test Buttons
uicontrol(f,'style','pushbutton','fontsize',h.fs, ...
  'string','Test Audio','position',[20 20 150 30], ...
  'callback',@test_audio);
uicontrol(f,'style','pushbutton','fontsize',h.fs, ...
  'string','Test Video','position',[190 20 150 30], ...
  'callback',@test_video);
uicontrol(f,'style','pushbutton','fontsize',h.fs, ...
  'string','Test Image','position',[360 20 150 30], ...
  'callback',@test_image);


refreshOL(); % Update OL fields


uiwait(f); % Do not leave function until figure closes.

%=========================================================================
%
%                  Callbacks and Subfunctions
%
%=========================================================================

%-------------------------------------------------------------------------
% Refresh OL Fields 
%-------------------------------------------------------------------------
  function refreshOL()
    % Update fields with data for the currently-selected OL
    set(h.txtName,'string',C.OL(workingOL).Name);
    set(h.txtKey,'string',C.OL(workingOL).Key);
    
    if isempty(C.OL(workingOL).AudioDevice) || ~any(AudioOut==C.OL(workingOL).AudioDevice)
      C.OL(workingOL).AudioDevice = AudioOut(1);
    end
    set(h.cboAudio,'value',find(AudioOut==C.OL(workingOL).AudioDevice,1));
    cboAudio_change(h.cboAudio,[]);
    
    set(h.txtDisplayCoords,'string',num2str(C.OL(workingOL).DisplayCoords));
    
%     if MEDIAPLAYER
%       if isempty(C.OL(workingOL).Balance)
%         C.OL(workingOL).Balance = 0;
%       end
%       set(h.sliderBalance,'value',C.OL(workingOL).Balance);
%       set(h.txtBalance,'string',num2str(C.OL(workingOL).Balance));
%     else

      % MPlayer
      if isempty(C.OL(workingOL).VideoAudioDevice)
        C.OL(workingOL).VideoAudioDevice = 1;
      end
      set(h.cboVideoAudio,'value',C.OL(workingOL).VideoAudioDevice);
      set(h.lstVideoAudioChannels,'value',C.OL(workingOL).VideoAudioChannels);
      
      if isempty(C.OL(workingOL).Fullscreen)
        C.OL(workingOL).Fullscreen = 0;
      end
      set(h.chkFullscreen,'value',C.OL(workingOL).Fullscreen);
      
%     end
  end

%-------------------------------------------------------------------------
% Change number of OLs
%-------------------------------------------------------------------------
  function txtOL_edit(obj, events)
    n = floor(str2double(get(obj,'string')));
    if isnan(n), n=1; end
    n = max(n,1); % require at least one output location
    
    set(obj,'string',num2str(n)); % In case of bad input
    
    % Resize OL array if necessary
    if n > C.NumOL
      C.OL(n).Name = []; % Expand OL array
    else
      C.OL = C.OL(1:n);  % Contract OL array
    end
      
    C.NumOL = n;
  end

%-------------------------------------------------------------------------
% Change OL Name
%-------------------------------------------------------------------------
  function txtName_edit(obj, events)
    C.OL(workingOL).Name = get(obj, 'string');
  end

%-------------------------------------------------------------------------
% Change OL Response Key
%-------------------------------------------------------------------------
  function txtKey_keypress(obj, events)
    C.OL(workingOL).Key = events.Key;
    set(h.txtKey,'string',events.Key);
  end
  
  
  
%-------------------------------------------------------------------------
% Callback for Audio Device 
%-------------------------------------------------------------------------
  function cboAudio_change(obj, events)
    
    NumChannels = AudioDevices(AudioOut(get(obj,'value'))).NrOutputChannels;
    
    set(h.lstChannels,'string',num2str((0:NumChannels-1)'));
    set(h.lstChannels,'value',C.OL(workingOL).AudioChannels);
    
    C.OL(workingOL).AudioDevice = AudioOut(get(obj,'value'));

    C.OL(workingOL).NumAudioChannels = NumChannels;
  end

%-------------------------------------------------------------------------
% Callback for Audio Channels
%-------------------------------------------------------------------------
  function lstChannels_change(obj, events)
    C.OL(workingOL).AudioChannels = get(obj,'value');
  end

%-------------------------------------------------------------------------
% Callback for Display 
%-------------------------------------------------------------------------
  function cboDisplay_change(obj, events)
    s = get(obj,'string');
    set(h.txtDisplayCoords,'string',s{get(obj,'value')});
    txtDisplayCoords_edit(h.txtDisplayCoords);
  end

%-------------------------------------------------------------------------
% Callback for Display Coordinates
%-------------------------------------------------------------------------
  function txtDisplayCoords_edit(obj, events)
    s = get(obj,'string');
    C.OL(workingOL).DisplayCoords = sscanf(s,'%d')';
  end

%-------------------------------------------------------------------------
% Callback for Fullscreen Checkbox
%-------------------------------------------------------------------------
  function chkFullscreen_change(obj, events)
    C.OL(workingOL).Fullscreen = get(obj,'value');
  end

%-------------------------------------------------------------------------
% Callback for Balance Slider
%-------------------------------------------------------------------------
  function sliderBalance_change(obj, events)
    v = get(obj,'value');
    v = round(v);                             % Only allow integer values
    set(obj,'value',v);                       % Update slider to integer
    set(h.txtBalance,'string',num2str(v));    % Set textbox to match slider

    C.OL(workingOL).Balance = v;              % Store value in structure
  end

%-------------------------------------------------------------------------
% Callback for Balance Textbox
%-------------------------------------------------------------------------
  function txtBalance_change(obj, events)
    v = get(obj,'string');
    v = str2double(v);
    if isnan(v), v = 0; end;                  % Validate input
    v = max(v,-9000);
    v = min(v,9000);
    
    set(h.sliderBalance,'value',v);           % Update slider to integer
    set(obj,'string',num2str(v));             % Set textbox to match slider

    C.OL(workingOL).Balance = v;              % Store value in structure
  end

%-------------------------------------------------------------------------
% Callback for Video Audio Combobox
%-------------------------------------------------------------------------
  function cboVideoAudio_change(obj, events)
    C.OL(workingOL).VideoAudioDevice = get(obj,'Value');    
  end

%-------------------------------------------------------------------------
% Callback for Video Audio Channels Listbox
%-------------------------------------------------------------------------
  function lstVideoAudioChannels_change(obj, events)
    C.OL(workingOL).VideoAudioChannels = get(obj,'Value');    
  end

%-------------------------------------------------------------------------
% Callback for +/- Buttons
%-------------------------------------------------------------------------
  function changeOL(obj, events, qty)
    % Change the working Output Location
    workingOL = workingOL + qty;
    workingOL = min(workingOL, C.NumOL); % do not exceed number of OL
    workingOL = max(workingOL, 1);       % do not drop below 1
    
    set(h.panelOL,'title',['Configure Output Location ' num2str(workingOL)]);
    
    refreshOL();
  end

%-------------------------------------------------------------------------
% Callback for Image Display Mode Combobox
%-------------------------------------------------------------------------
  function cboImageDisplayMode_change(obj, events)
    C.ImageDisplayMode = get(obj,'value');    
  end

%-------------------------------------------------------------------------
% Test Audio Output 
%-------------------------------------------------------------------------
  function test_audio(obj, events)
    if C.UsePsychPortAudio
      % Based on code from BasicSoundOutputDemo.m (PsychToolBox)
      a = load(fullfile(fileparts(mfilename('fullpath')), 'samples', 'jungle-run.mat')); % load test audio file
      %nrchannels = length(C.OL(workingOL).AudioChannels);
      nrchannels = AudioDevices(AudioOut(get(h.cboAudio,'value'))).NrOutputChannels;
      freq = a.Fs;
      wavedata = a.y(:,1)'; % select one channel of audio
      %wavedata = repmat(wavedata,nrchannels,1); % expand to number of output channels
      
      w = zeros(nrchannels,length(wavedata));
      selectchannels = C.OL(workingOL).AudioChannels - 1;
      for i = 1:length(selectchannels)
        w(selectchannels(i)+1,:) = wavedata;
      end
      
      deviceid = C.OL(workingOL).AudioDevice - 1 ;
      
      % Select Audio Channels
      % Only works on Windows with ASIO sound cards
      % Should be a row vector
      
      
      pahandle = PsychPortAudio('Open', deviceid, [], 0, freq, nrchannels,[],[],[]);
      %pahandle = PsychPortAudio('Open', deviceid, [], 0, freq, nrchannels,[],[],selectchannels);
      PsychPortAudio('FillBuffer', pahandle, w);
      PsychPortAudio('Start', pahandle, [], 0, 1);
      pause(4)
      PsychPortAudio('Close',pahandle);
    else
      % Use MPlayer to play audio

      mplayer.Device = C.OL(workingOL).VideoAudioDevice - 1;
      
      NumOutputChannels = length(C.OL(workingOL).VideoAudioChannels);
      ChannelString = ['2:' num2str(NumOutputChannels)];
      for i = 1:NumOutputChannels
        ChannelString = [ChannelString ':0:' num2str(C.OL(workingOL).VideoAudioChannels(i)-1)];
      end
      mplayer.Channels = ChannelString;
      mplayer.Filename = fullfile(fileparts(mfilename('fullpath')), 'samples', 'jungle-run.wav');
      
      mplayer.PlayFile(); % Start playback 
      
      pause(4)
      
      mplayer.Command('stop')
    end
  end

%-------------------------------------------------------------------------
% Test Video Output
%-------------------------------------------------------------------------
  function test_video(obj, events)
    %BorderWidth = 3;
    %TopBorderWidth = 20; 
    
    
    c = C.OL(workingOL).DisplayCoords;
    c(3:4) = c(3:4)-c(1:2)+[1 1];
    %cc = [c(1)+BorderWidth-1, c(2)+BorderWidth-1, c(3)-2*BorderWidth, c(4)-(BorderWidth+TopBorderWidth)];
    
    % MPlayer code follows
    
    mplayer.Xoffset = c(1);
    mplayer.Yoffset = c(2);
    mplayer.Width = c(3);
    mplayer.Height = c(4);
    
    mplayer.Device = C.OL(workingOL).VideoAudioDevice - 1;
    
    NumOutputChannels = length(C.OL(workingOL).VideoAudioChannels);
    ChannelString = ['2:' num2str(NumOutputChannels)];
    for i = 1:NumOutputChannels
      ChannelString = [ChannelString ':0:' num2str(C.OL(workingOL).VideoAudioChannels(i)-1)];
    end
    mplayer.Channels = ChannelString;
    mplayer.Filename = [' -noborder ' fullfile(fileparts(mfilename('fullpath')), 'samples', 'a11v_1101342.mpg')];

    mplayer.PlayFile(); % Start playback using previous-defined settings
    pause(0.5)
    %mplayer.Command('set_property border 0')
    
    if C.OL(workingOL).Fullscreen
      mplayer.Command('vo_fullscreen 1')
    end
    
    pause(5)
    mplayer.Command('stop')
    
    
  end

%-------------------------------------------------------------------------
% Test Image Display
%-------------------------------------------------------------------------
  function test_image(obj, events)
    TestImageFile = fullfile(fileparts(mfilename('fullpath')), 'samples', 'sample.jpg');
    stopImage = PlayImage(C,workingOL,TestImageFile);
    pause(3)
    stopImage();
  end
%-------------------------------------------------------------------------
%  UsePsychPortAudio checkbox callback
%-------------------------------------------------------------------------
  function chkUsePsychPortAudio_change(obj,evt)
    C.UsePsychPortAudio = get(obj,'value');
  end

end % ConfigureHardware