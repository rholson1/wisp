function stopfcn = PlayVideo(C,OL,VideoFileName, Callback, CallbackArg, Loop)
  % PLAYVIDEO - Play a video at a specified output location.
  %
  % PlayVideo(C,OL,VideoFileName)
  % PlayVideo(C,OL,VideoFileName,Callback,CallbackArg)
  %
  % C  : Hardware configuration structure (see ConfigureHardware)
  % OL : Output Location number
  % VideoFileName : Full filename of the video to be played
  % Callback : handle to a function to be executed at the end of playback
  % CallbackArg : argument to callback function
  %
  % Dependencies : MPlayer, MPlayerControl
  % See Also ConfigureHardware, PlayAudio
  %
  % 2010-05-18 : Created by Robert H. Olson, Ph.D. rolson@waisman.wisc.edu
  % 2010-08-09 : Permit "simultaneous" display at more than one OL
  
  
  numOL = length(OL); % number of output locations
  if numOL == 0
    disp('*** PlayVideo: No output locations defined')
    return
  end
  
  % Loop video?
  if isempty(Loop)
      Loop = 0;
  end
  if Loop
    loopstr = ' -loop 0';
  else
    loopstr = '';
  end
  
  % Check matlab version to see if we should use .NET or COM
  global MPLAYER_COM
  
  for OLidx = 1:numOL % iterate over output locations
    
    % Try to start MPlayerControl
    try      
      if MPLAYER_COM
        mplayer{OLidx} = actxserver('MPlayerControl.MPlayerControl');
      else
        mplayer{OLidx} = MPlayerControl.MPlayerControl;
      end
      mplayer{OLidx}.Executable = GetMPlayerExecutable();
      %VideoAudioDeviceList = regexp(mplayer.DeviceList,'\|','split');
    catch e
      errordlg(['Problem starting MPlayerControl.  Make sure that MPlayerControl has been installed.' e.message], ...
        'MPlayerControl Error');
      return
    end
    
    
    c = C.OL(OL(OLidx)).DisplayCoords;
    c(3:4) = c(3:4)-c(1:2)+[1 1];
    
    mplayer{OLidx}.Xoffset = c(1)-1;
    mplayer{OLidx}.Yoffset = c(2)-1;
    mplayer{OLidx}.Width = c(3);
    mplayer{OLidx}.Height = c(4);
    
    mplayer{OLidx}.Device = C.OL(OL(OLidx)).VideoAudioDevice - 1;
    
    NumOutputChannels = length(C.OL(OL(OLidx)).VideoAudioChannels);
    ChannelString = ['2:' num2str(NumOutputChannels)];
    for i = 1:NumOutputChannels
      ChannelString = [ChannelString ':0:' num2str(C.OL(OL(OLidx)).VideoAudioChannels(i)-1)];
    end
    mplayer{OLidx}.Channels = ChannelString;
    mplayer{OLidx}.Filename = [' -noborder "' VideoFileName '"' loopstr];  % insert -noborder into command line
    
    mplayer{OLidx}.PlayFile(); % Start playback using previous-defined settings
    
    TimerStart = tic;
    
    pause(0.001)
    pause(0.005) % DEBUG
    if C.OL(OL(OLidx)).Fullscreen
      mplayer{OLidx}.Command('vo_fullscreen 1')
    end
    
  end
  
  % Fire a callback at the end of the movie?
  USECALLBACK = (nargin >= 5) && ~Loop;
  if USECALLBACK
    % Reqest the movie length (last OL only)
    mplayer{numOL}.Command('pausing_keep get_time_length')
    
    % Wait a bit, and then check the response property
    TimerDelay = 2;
    t{1} = timer('StartDelay',TimerDelay,'TimerFcn',@GetVideoLength);
    start(t{1})
  end
  
  stopfcn = @StopVideo;
  
  % Callback for timer object which gets video length from mplayer.response
  function GetVideoLength(obj, events)
    
    stop(t{1})
    delete(t{1})
    
    if (MPLAYER_COM && ~ishandle(mplayer{numOL})) || ...
        (~MPLAYER_COM && ~isvalid(mplayer{numOL})) % the video has already been stopped
      return
    end
    
    if MPLAYER_COM
      TimerPeriod = str2double(regexp(mplayer{numOL}.Response,'(?<==)\S*','match')) - toc(TimerStart);
    else
      TimerPeriod = str2double(regexp(mplayer{numOL}.Response.char,'(?<==)\S*','match')) - toc(TimerStart);
    end

    if isempty(TimerPeriod) || isnan(TimerPeriod)
      disp('Problem getting length of movie.')
      if MPLAYER_COM
        disp(['MPlayer.Response = ' mplayer{numOL}.Response])
      else
        disp(['MPlayer.Response = ' mplayer{numOL}.Response.char])
      end
      pause(1)
      if MPLAYER_COM
        disp(['MPlayer.Response after 1 sec delay = ' mplayer{numOL}.Response])
      else
        disp(['MPlayer.Response after 1 sec delay = ' mplayer{numOL}.Response.char])
      end
      return
    end

    % Use a timer to handle the end of video playback
    TimerPeriod = fix(TimerPeriod * 1000)/1000;           % Millisecond precision
    t{2} = timer('StartDelay',TimerPeriod,'TimerFcn',@StopVideo);
    start(t{2})

  end
  
  
  % Callback for timer object which fires at the end of the video.
  function StopVideo(obj, events)
    try
      if length(t) > 1
        stop(t{2})
        delete(t{2})
      end
    catch ME
      if ~strcmp(ME.identifier,'MATLAB:UndefinedFunction')
        disp(' *** Problem Deleting Timer in PlayVideo>StopVideo ***')
        disp([' --- ' ME.message])
      end
    end
    
    % Send a stop command to MPlayer (?)
    try
      for OLidx2 = 1:numOL
        mplayer{OLidx2}.Command('stop')
        mplayer{OLidx2}.Command('quit')
        if MPLAYER_COM
          mplayer{OLidx2}.release
        else
          mplayer{OLidx2}.delete
        end
      end
    catch ME
      disp(' *** Problem Stopping Video in PlayVideo>StopVideo ***')
      disp([' --- ' ME.message])
    end
    % Run the user-supplied callback function
    Callback(CallbackArg)
  end
  
end

