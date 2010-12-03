function S = ReadExperimentSettings(SettingsFile)
% ReadExperimentSettings - Import settings in a structure from a text file.
%
%
%

disp('TODO: ReadExperimentSettings')


% Dummy settings
%----------------
S = [];
S.Experiment.Name = '';
S.Experiment.PhaseOrder = 'Random';
S.Experiment.Phases = [];
%S.Experiment.Phases(1).Name = '';
%S.Experiment.Phases(1).PhaseEnd = 'Fixed';

C.NumOL = 2;
C.OL(1).Name = 'Left';
C.OL(2).Name = 'Right';
C.OL(1).Key = '4';
C.OL(2).Key = '6';

C.OL(1).AudioDevice = []; % The third audio device with audio outputs
C.OL(1).AudioChannels = [1 2];

C.OL(1).DisplayCoords = [1 1 1280 1024];
C.OL(1).Fullscreen = 1;

C.OL(1).VideoAudioDevice = 1;          % Audio device used for videos
C.OL(1).VideoAudioChannels = [1 2];    % Audio channels used for videos
S.OL = C;

end