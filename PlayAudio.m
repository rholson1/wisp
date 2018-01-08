function stopfcn = PlayAudio(C,OL,AudioFileName,Callback,CallbackArg,Loop)
% PLAYAUDIO - Play an audio file at a specified location.
%
% PlayAudio(C,OL,AudioFileName)
% PlayAudio(C,OL,AudioFileName,Callback,CallbackArg)
%
% C  :  Hardware configuration (see ConfigureHardware)
% OL :  Ouput location 
% AudioFileName : Full name of the audio file to be played
% Callback : handle to a function to be executed after playback is complete
% CallbackArg : argument to callback function
%
% See Also ConfigureHardware, PlayVideo
%
% 2010-5-18 : Created by Robert H. Olson, Ph.D. rolson@waisman.wisc.edu
% 2010-8-10 : Added support for multiple output locations
% 2018-1-08 : Use audioread instead of deprecated wavread if available.

% Was a callback function supplied?
RUNCALLBACK = (nargin >= 5);

if Loop
  Repetitions = 0;
else
  Repetitions = 1;
end

if exist('audioread')
   [y, freq] = audioread(AudioFileName);        % Read audio file
else
   [y, freq] = wavread(AudioFileName);        % Read audio file
end
y = y(:,1)';                                      % Pick the first channel and make a row vector
totaltime = length(y)/freq;

NumOL = length(OL); % Number of output locations
pahandles = zeros(1,NumOL); % vector of PortAudio device handles

for OLidx = 1:NumOL
  nrchannels = C.OL(OL(OLidx)).NumAudioChannels;    % Number of channels in the output device
  w = zeros(nrchannels,length(y));                  % Create empty matrix
  
  selectchannels = C.OL(OL(OLidx)).AudioChannels ;  % Put audio data in selected channels
  for i = 1:length(selectchannels)
    w(selectchannels(i),:) = y;
  end
  
  deviceid = C.OL(OL(OLidx)).AudioDevice - 1 ;      % Select Audio Device
  
  pahandles(OLidx) = PsychPortAudio('Open', deviceid, [], 0, freq, nrchannels,[],[],[]);  % Open audio device
  PsychPortAudio('FillBuffer', pahandles(OLidx), w);    % Fill buffer with audio data
  PsychPortAudio('Start', pahandles(OLidx), Repetitions, 0, 1);  % Start playback immediately
end

if ~Loop
  % Use a timer to stop the audio device
  TimerPeriod = fix(totaltime * 1000)/1000;                    % Millisecond precision
  t = timer('StartDelay',TimerPeriod,'TimerFcn',@StopAudio);   % Create timer object
  start(t);                                                    % Start timer to stop playback
end

stopfcn = @StopAudio;

%  Callback function for timer
  function StopAudio(obj, events)
    for ii = 1:NumOL
      PsychPortAudio('Close', pahandles(ii)); % Close PortAudio devices
    end
    
    if ~Loop
      stop(t)
      delete(t)
    end
    
    if RUNCALLBACK
      Callback(CallbackArg)
    end
  end
end


