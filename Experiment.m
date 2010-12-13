function Experiment(SettingsFile)
  % Start experiment GUI
  %
  % Experiment()
  % Experiment(SettingFile)
  %
  % SettingsFile : File containing experiment settings.
  %                If SettingsFile is not provided, the program starts with an empty experiment.
  %
  % Robert H. Olson, Ph.D., rolson@waisman.wisc.edu
  
  
  %% Global Variables
  % Status Variables
  CurrentLevel = 1; % 1-4 {Experiment, Phase, Item, Event}
  WorkingPhase = 1; % Selected Phase in Phase List
  WorkingItem = 1;  % Selected Item in Item List
  WorkingEvent = 1; % Selected Event in Event List
  
  ConditionRow = 1; % Selected Row in Condition Table on Run Screen
  
  % Constant Lists
  G.ProgramName = 'WISP';
  
  G.LevelNames = {'Experiment' 'Phase' 'Item' 'Event' 'Run'};
  G.PhaseOrder = {'Sequential' 'Random'};
  G.PhaseEnd = {'Fixed' 'Time' 'Contingent'};
  G.ItemOrder = {'Sequential' 'Random with Replacement' 'Random without Replacement' 'Random within Blocks'};
  G.Measure = {'sum(on-target)' 'ave(on-target)'};
  G.Group = {'First n Trials' 'Last n Trials' 'All Trials'};
  G.Operators = {' +' ' -' ' *' ' /'};
  G.Comparison = {' >' ' <' ' ='};
  G.RepeatOnFail = {'None' 'Immediate' 'End of Phase' 'Random within Phase' 'End of Block' 'Random within Block'};
  G.RepeatsAllowed = {'One' 'Until Successful'};
  G.OutputLocationTypes = {'All Selected' 'Random Within Selected' 'Match Event' 'Don''t Match Event'};
  G.EventTypes = {'trial.StartTime' 'event.StartTime' 'event.StopTime' 'key.PressTime' 'key.Duration' 'key.TrialDuration' 'key.ReleaseTime'};
  G.Balance = {'None' 'Blocks' 'Trials'};
  G.MediaFilter = {'*.wav;*.avi;*.mpg;*.mov;*.bmp;*.gif;*.jpg;*.jpeg;*.png','Stimulus File';'*.wav','Audio File (*.wav)';'*.avi;*.mpg;*.mov','Video File (*.avi, *.mpg, *.mov)';'*.bmp;*.gif;*.jpg;*.jpeg;*.png','Image File (*.bmp, *.gif, *.jpg, *.png)'};
  
  gui.fs = 10; % font size for GUI elements
  
  % Figure position persists between sessions
  if ~ispref('SaffranExperiment','Position')
    addpref('SaffranExperiment','Position',[100 100]);
  end
  gui.xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure
  
  % S contains all information about the experiment
  S = [];
  S0 = []; % S0 is a reference used to track whether S has changed.
  
  %% Initialization : Read Settings
  
  % Directory for experiment settings persists between sessions
  if ~ispref('SaffranExperiment','SettingsDir')
    addpref('SaffranExperiment','SettingsDir',pwd);
  end
  SettingsDir = getpref('SaffranExperiment','SettingsDir');
  
  % Prompt user to select a settings file
  if nargin == 0
    [fname,pname] = uigetfile({'*.txt','Settings Files (*.txt)'},'Select Experiment Settings File',SettingsDir);
    
    if isequal(fname,0) 
      % No file was selected, so create a basic data structure S.
      
      % Initialize S
      S.Results = [];
      S.Experiment = [];
      S.Experiment.Name = '';
      S.Experiment.Phases = [];
      S.Experiment.PhaseOrder = G.PhaseOrder{1};
      S.OL = [];
      S.OL.NumOL = 1;
      S.OL.UsePsychPortAudio = true;
      
      S.OL.OL(1).Name = '';
      S.OL.OL(1).Key = '';
      
      InitializePsychSound; % Initialize PsychPortAudio
      AudioDevices = PsychPortAudio('GetDevices'); % Get a structure array of audio devices
      AudioOut = find([AudioDevices.NrOutputChannels] > 0); % Identify which audio devices have output channels
      
      S.OL.OL(1).AudioDevice = AudioOut(1);
      S.OL.OL(1).AudioChannels = [];
      S.OL.OL(1).DisplayCoords = [];
      S.OL.OL(1).Fullscreen = 1;
      S.OL.OL(1).VideoAudioDevice = 1;
      S.OL.OL(1).VideoAudioChannels = [];
      S.OL.OL(1).NumAudioChannels = 2;
      
      S.Paths.ResultsPath = '';
      S.Paths.StimulusPath = '';
      SettingsFile = '';
      
      S0 = S;
    else
      setpref('SaffranExperiment','SettingsDir',pname);
      SettingsFile = [pname fname];
      LoadSettings(); % Load from SettingsFile
    end
  else
    LoadSettings(); % Load from SettingsFile
  end
  
  %% Create GUI Figure
  f = figure('MenuBar', 'None',  ...
    'Name', G.ProgramName, ...
    'NumberTitle', 'off', 'IntegerHandle', 'off', ...
    'Position',[gui.xy 1000 800], ...
    ... %'Units', 'normalized','Position', [0.1 0.1 0.8 0.8], ...
    'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
    'HandleVisibility','callback',...
    'Resize','off',...                                               % Disallow resizing window
    'CloseRequestFcn', @ExitExperiment);
  
  %% Main Menu
  % File
  gui.menu.file = uimenu(f,'Label','File');
  uimenu(gui.menu.file,'Label','New Experiment','callback',@New_Experiment)
  uimenu(gui.menu.file,'Label','Load Experiment','callback',@Load_Experiment)
  uimenu(gui.menu.file,'Label','Save Experiment','callback',@Save_Experiment)
  uimenu(gui.menu.file,'Label','Save Experiment As...','callback',@Save_Experiment_As)
  uimenu(gui.menu.file,'Label','Quit','callback',@ExitExperiment,'Separator','on');
  
  % Settings
  gui.menu.settings = uimenu(f,'Label','Settings');
  uimenu(gui.menu.settings,'Label','Output Locations','callback',@SetOutputLocations);
  uimenu(gui.menu.settings,'Label','File Paths','callback',@SetFilePaths);
  uimenu(gui.menu.settings,'Label','Key Definitions','callback',@SetKeyDefinitions);
  uimenu(gui.menu.settings,'Label','Convert Images to BMP','callback',@ConvertToBMP);
  %uimenu(gui.menu.settings,'Label','Use PsychPortAudio','callback',@UsePsychPortAudio,'checked',iif(S.UsePsychPortAudio,'on','off'),'separator','on');
  
  % Experiment
  gui.menu.experiment = uimenu(f,'Label','Experiment');
  uimenu(gui.menu.experiment,'Label','Edit','callback',{@ChangeLevel,1})
  uimenu(gui.menu.experiment,'Label','Run','callback',{@ChangeLevel,5})
  
  % Results
  gui.menu.results = uimenu(f,'Label','Results');
  uimenu(gui.menu.results,'Label','Postprocess Results','callback',@Process_Results)
  
  % Help
  gui.menu.help = uimenu(f,'Label','Help');
  uimenu(gui.menu.help,'Label','User''s Guide','callback',@showUsersGuide);
  uimenu(gui.menu.help,'Label','Structure of Stored Data','callback',@showDataStructure);
  uimenu(gui.menu.help,'Label','Output Format Creation','callback',@showOutputFormatCreation);
  uimenu(gui.menu.help,'Label','About','Separator','on','callback',@showAboutBox);
  
  
  %% Context Menu
  %
  % A context menu will be available for the Phase, Item, and Event listboxes.
  % The menu will provide an alternate interface to work with the selected event
  gui.cmenu = uicontextmenu('parent',f);
  uimenu(gui.cmenu,'Label','Create New...','Callback',@cmenuNew);
  uimenu(gui.cmenu,'Label','Edit Selected','Callback',@cmenuEdit);
  uimenu(gui.cmenu,'Label','Copy Selected','Callback',@cmenuCopy);
  uimenu(gui.cmenu,'Label','Delete Selected','Callback',@cmenuDelete);
  uimenu(gui.cmenu,'Label','Move Selected Up','Callback',@cmenuUp);
  uimenu(gui.cmenu,'Label','Move Selected Down','Callback',@cmenuDown);
  
  %% UI Elements
  % Place UI elements in uipanels (keep only the "CurrentLevel" panel visible)
  for i = 1:5
    LevelPanel(i) = uipanel('parent',f,'title',G.LevelNames{i},'fontsize',gui.fs+2,'fontweight','bold','foregroundcolor','k','position',[0 0 1 1],'bordertype','none','visible','off');
    
    switch i
      case 1 % Experiment
        %% Experiment Level GUI
        
        % Experiment Name
        uicontrol(LevelPanel(1),'Style', 'text', 'String', 'Experiment ID', ...
          'Position',[280 685 120 25],'fontsize',gui.fs);
        gui.txtExperiment = uicontrol(LevelPanel(1),'Style', 'edit', ...
          'Position',[400 690 250 25], 'BackGroundColor', 'w','fontsize',gui.fs, ...
          'CallBack', @txtExperiment_change);
        
        % Phase listbox
        uicontrol(LevelPanel(1),'Style', 'text', 'String', 'Phase List', ...
          'Position',[400 650 200 25], 'FontSize', gui.fs);
        gui.lstPhases = uicontrol(LevelPanel(1),'Style', 'listbox',...
          'Position',[400 400 250 250], 'FontSize', gui.fs, 'BackGroundColor', 'w', 'Max', 1, ...
          'UIContextMenu',gui.cmenu,'callback',@lstPhases_change);
        
        % Listbox Control Buttons
        uicontrol(LevelPanel(1),'style','pushbutton','string','New',   'callback',@cmenuNew,   'position',[280 620 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(1),'style','pushbutton','string','Edit',  'callback',@cmenuEdit,  'position',[280 590 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(1),'style','pushbutton','string','Copy',  'callback',@cmenuCopy,  'position',[280 560 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(1),'style','pushbutton','string','Delete','callback',@cmenuDelete,'position',[280 530 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(1),'style','pushbutton','string','Up',    'callback',@cmenuUp,    'position',[280 500 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(1),'style','pushbutton','string','Down',  'callback',@cmenuDown,  'position',[280 470 100 25],'fontsize',gui.fs);
        
        % Phase Order combobox
        uicontrol(LevelPanel(1),'style','text','string','Phase Order', ...
          'Position',[280 360 120 25],'fontsize',gui.fs);
        gui.cboPhaseOrder = uicontrol(LevelPanel(1),'style','popupmenu',...
          'string',G.PhaseOrder,'fontsize',gui.fs,'backgroundcolor','w',...
          'Position',[400 365 250 25],'callback',@cboPhaseOrder_change);
        
      case 2 % Phase
        %% Phase Level GUI
        
        % Experiment Name (Display Only)
        uicontrol(LevelPanel(2),'Style', 'text', 'String', 'Experiment ID', ...
          'Position',[280 715 120 25],'fontsize',gui.fs);
        gui.btnExperiment = uicontrol(LevelPanel(2),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,1},...
          'Position',[400 715 250 25], 'fontsize',gui.fs);
        
        % Phase Name
        uicontrol(LevelPanel(2),'Style', 'text', 'String', 'Phase ID', ...
          'Position',[280 685 120 25],'fontsize',gui.fs);
        gui.txtPhase = uicontrol(LevelPanel(2),'Style', 'edit', ...
          'Position',[400 690 250 25], 'BackGroundColor', 'w','fontsize',gui.fs, ...
          'CallBack', @txtPhase_change);
        
        % Item listbox
        uicontrol(LevelPanel(2),'Style', 'text', 'String', 'Item List', ...
          'Position',[400 650 200 25], 'FontSize', gui.fs);
        gui.lstItems = uicontrol(LevelPanel(2),'Style', 'listbox',...
          'Position',[400 400 250 250], 'FontSize', gui.fs, 'BackGroundColor', 'w', 'Max', 1, ...
          'UIContextMenu',gui.cmenu,'callback',@lstItems_change);
        
        % Listbox Control Buttons
        uicontrol(LevelPanel(2),'style','pushbutton','string','New',   'callback',@cmenuNew,   'position',[280 620 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(2),'style','pushbutton','string','Edit',  'callback',@cmenuEdit,  'position',[280 590 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(2),'style','pushbutton','string','Copy',  'callback',@cmenuCopy,  'position',[280 560 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(2),'style','pushbutton','string','Delete','callback',@cmenuDelete,'position',[280 530 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(2),'style','pushbutton','string','Up',    'callback',@cmenuUp,    'position',[280 500 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(2),'style','pushbutton','string','Down',  'callback',@cmenuDown,  'position',[280 470 100 25],'fontsize',gui.fs);
        
        % Item Order combobox
        uicontrol(LevelPanel(2),'style','text','string','Trial Order', ...
          'Position',[280 360 120 25],'fontsize',gui.fs);
        gui.cboItemOrder = uicontrol(LevelPanel(2),'style','popupmenu',...
          'string',G.ItemOrder,'fontsize',gui.fs,'backgroundcolor','w',...
          'Position',[400 365 250 25],'callback',@cboItemOrder_change);
        
        % Repetitions textbox
        uicontrol(LevelPanel(2),'style','text','string','Repetitions', ...
          'Position',[280 330 120 25],'fontsize',gui.fs);
        gui.txtRepetitions = uicontrol(LevelPanel(2),'style','edit',...
          'fontsize',gui.fs,'backgroundcolor','w',...
          'Position',[400 335 250 25],'callback',@txtRepetitions_change);
        
        % Phase End Condition
        uicontrol(LevelPanel(2),'style','text','string','Phase End Condition', ...
          'Position',[240 300 160 25],'fontsize',gui.fs);
        gui.cboPhaseEnd = uicontrol(LevelPanel(2),'style','popupmenu',...
          'string',G.PhaseEnd,'fontsize',gui.fs,'backgroundcolor','w',...
          'Position',[400 305 250 25],'callback',@cboPhaseEnd_change);
        
        % Use a subpanel to show phase end condition options
        for j = 1:length(G.PhaseEnd)
          gui.panelPhaseEnd(j) = uipanel(LevelPanel(2),'units','pixels','Position',[240 80 460 200],'visible','off');
          
          switch j
            case 1 % Fixed
              uicontrol(gui.panelPhaseEnd(1),'style','text','string','End phase after all trials are complete.',...
                'Position',[20 140 300 25],'fontsize',gui.fs);
            case 2 % Time
              uicontrol(gui.panelPhaseEnd(2),'style','text','string','End phase after',...
                'Position',[20 140 130 25],'fontsize',gui.fs);
              gui.txtPhaseEndTime = uicontrol(gui.panelPhaseEnd(2),'style','edit','backgroundcolor','w',...
                'Position',[150 145 60 25],'fontsize',gui.fs,'callback',@txtPhaseEndTime_change);
              uicontrol(gui.panelPhaseEnd(2),'style','text','string','seconds.',...
                'Position',[210 140 80 25],'fontsize',gui.fs);
              
            case 3 % Contingent
              % Ignore Failed checkbox
              gui.chkIgnoreFailed = uicontrol(gui.panelPhaseEnd(3),'style','checkbox','string','Ignore failed trials','fontsize',gui.fs,'position',[170 175 120 20],'callback',@chkIgnoreFailed_change);              
              
              % A
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','A','fontsize',gui.fs,'Position',[100 150 20 25]);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','Measure','fontsize',gui.fs,'Position',[10 115 80 25]);
              gui.cboPhaseMeasureA = uicontrol(gui.panelPhaseEnd(3),'style','popupmenu','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[90 120 120 25],'string',G.Measure,'callback',@cboPhaseMeasureA_change);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','Group','fontsize',gui.fs,'Position',[10 85 80 25]);
              gui.cboPhaseGroupA = uicontrol(gui.panelPhaseEnd(3),'style','popupmenu','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[90 90 120 25],'string',G.Group,'callback',@cboPhaseGroupA_change);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','n','fontsize',gui.fs,'Position',[10 55 80 25]);
              gui.txtPhaseNA = uicontrol(gui.panelPhaseEnd(3),'style','edit','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[90 60 60 25],'callback',@txtPhaseNA_change);
              
              % B
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','B','fontsize',gui.fs,'Position',[330 150 20 25]);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','Measure','fontsize',gui.fs,'Position',[240 115 80 25]);
              gui.cboPhaseMeasureB = uicontrol(gui.panelPhaseEnd(3),'style','popupmenu','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[320 120 120 25],'string',G.Measure,'callback',@cboPhaseMeasureB_change);
              
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','Group','fontsize',gui.fs,'Position',[240 85 80 25]);
              gui.cboPhaseGroupB = uicontrol(gui.panelPhaseEnd(3),'style','popupmenu','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[320 90 120 25],'string',G.Group,'callback',@cboPhaseGroupB_change);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','n','fontsize',gui.fs,'Position',[240 55 80 25]);
              gui.txtPhaseNB = uicontrol(gui.panelPhaseEnd(3),'style','edit','fontsize',gui.fs,'backgroundcolor','w',...
                'Position',[320 60 60 25],'callback',@txtPhaseNB_change);
              
              % Contingency Formula
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','End phase when',...
                'Position',[20 5 140 25],'fontsize',gui.fs);
              
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','A  +  (','fontsize',gui.fs,...
                'position',[160 5 60 25])
              gui.txtPhaseEndMultiplier = uicontrol(gui.panelPhaseEnd(3),'style','edit','fontsize',gui.fs,'backgroundcolor','w',...
                'position',[220 10 40 25],'callback',@txtPhaseEndMultiplier_change);
              uicontrol(gui.panelPhaseEnd(3),'style','text','string','x  B)','fontsize',gui.fs,...
                'position',[260 5 50 25])
              gui.cboPhaseEndOperator = uicontrol(gui.panelPhaseEnd(3),'style','popupmenu','fontsize',gui.fs,'backgroundcolor','w',...
                'position',[310 10 40 25],'string',G.Comparison,'callback',@cboPhaseEndOperator_change);
              gui.txtPhaseEndScalar = uicontrol(gui.panelPhaseEnd(3),'style','edit','fontsize',gui.fs,'backgroundcolor','w',...
                'position',[360 10 40 25],'callback',@txtPhaseEndScalar_change);
          end
        end
        
      case 3 % Item
        %% Item Level GUI
        
        
        % Experiment Name (Display Only)
        uicontrol(LevelPanel(3),'Style', 'text', 'String', 'Experiment ID', ...
          'Position',[280 745 120 25],'fontsize',gui.fs);
        gui.btnExperiment(2) = uicontrol(LevelPanel(3),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,1},...
          'Position',[400 745 250 25], 'fontsize',gui.fs);
        
        % Phase Name (Display Only)
        uicontrol(LevelPanel(3),'Style', 'text', 'String', 'Phase ID', ...
          'Position',[280 715 120 25],'fontsize',gui.fs);
        gui.btnPhase = uicontrol(LevelPanel(3),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,2},...
          'Position',[400 715 250 25], 'fontsize',gui.fs);
        
        % Item Name
        uicontrol(LevelPanel(3),'Style', 'text', 'String', 'Item ID', ...
          'Position',[280 685 120 25],'fontsize',gui.fs);
        gui.txtItem = uicontrol(LevelPanel(3),'Style', 'edit', ...
          'Position',[400 690 250 25], 'BackGroundColor', 'w','fontsize',gui.fs, ...
          'CallBack', @txtItem_change);
        
        
        % Event listbox
        uicontrol(LevelPanel(3),'Style', 'text', 'String', 'Event List', ...
          'Position',[400 650 200 25], 'FontSize', gui.fs);
        gui.lstEvents = uicontrol(LevelPanel(3),'Style', 'listbox',...
          'Position',[400 400 250 250], 'FontSize', gui.fs, 'BackGroundColor', 'w', 'Max', 1, ...
          'callback',@lstEvents_change,...
          'UIContextMenu',gui.cmenu);
        
        % Listbox Control Buttons
        uicontrol(LevelPanel(3),'style','pushbutton','string','New',   'callback',@cmenuNew,   'position',[280 620 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(3),'style','pushbutton','string','Edit',  'callback',@cmenuEdit,  'position',[280 590 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(3),'style','pushbutton','string','Copy',  'callback',@cmenuCopy,  'position',[280 560 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(3),'style','pushbutton','string','Delete','callback',@cmenuDelete,'position',[280 530 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(3),'style','pushbutton','string','Up',    'callback',@cmenuUp,    'position',[280 500 100 25],'fontsize',gui.fs);
        uicontrol(LevelPanel(3),'style','pushbutton','string','Down',  'callback',@cmenuDown,  'position',[280 470 100 25],'fontsize',gui.fs);
        
        
        % Repeat on Failure Combobox
        uicontrol(LevelPanel(3),'style','text','string','Repeat on Failure', ...
          'Position',[260 360 140 25],'fontsize',gui.fs);
        gui.cboRepeatOnFail = uicontrol(LevelPanel(3),'style','popupmenu',...
          'string',G.RepeatOnFail,'fontsize',gui.fs,'backgroundcolor','w',...
          'Position',[400 365 250 25],'callback',@cboRepeatOnFail_change);
        
        % Repeats Allowed combobox
        uicontrol(LevelPanel(3),'style','text','string','Repeats Allowed', ...
          'Position',[260 330 140 25],'fontsize',gui.fs);
        gui.cboRepeatsAllowed = uicontrol(LevelPanel(3),'style','popupmenu', ...
          'string',G.RepeatsAllowed,'fontsize',gui.fs,'backgroundcolor','w',...
          'position',[400 335 250 25],'callback',@cboRepeatsAllowed_change);
        
        
      case 4 % Event
        %% Event Level GUI
        
        % Experiment Name (Display Only)
        uicontrol(LevelPanel(4),'Style', 'text', 'String', 'Experiment ID', ...
          'Position',[280 765 120 25],'fontsize',gui.fs);
        gui.btnExperiment(3) = uicontrol(LevelPanel(4),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,1},...
          'Position',[400 765 250 25], 'fontsize',gui.fs);
        
        % Phase Name (Display Only)
        uicontrol(LevelPanel(4),'Style', 'text', 'String', 'Phase ID', ...
          'Position',[280 740 120 25],'fontsize',gui.fs);
        gui.btnPhase(2) = uicontrol(LevelPanel(4),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,2},...
          'Position',[400 740 250 25], 'fontsize',gui.fs);
        
        % Item Name (Display Only)
        uicontrol(LevelPanel(4),'Style', 'text', 'String', 'Item ID', ...
          'Position',[280 715 120 25],'fontsize',gui.fs);
        gui.btnItem = uicontrol(LevelPanel(4),'Style', 'pushbutton', ...
          'callback',{@ChangeLevel,3},...
          'Position',[400 715 250 25], 'fontsize',gui.fs);
        
        % Event Name
        uicontrol(LevelPanel(4),'Style', 'text', 'String', 'Event ID', ...
          'Position',[280 685 120 25],'fontsize',gui.fs);
        gui.txtEvent = uicontrol(LevelPanel(4),'Style', 'edit', ...
          'Position',[400 690 250 25], 'BackGroundColor', 'w','fontsize',gui.fs, ...
          'CallBack', @txtEvent_change);
        
        % Stimulus Filename / Browse Button
        uicontrol(LevelPanel(4),'style','text','string','Stimulus Filename', ...
          'Position',[160 630 140 25],'fontsize',gui.fs);
        gui.txtStimulusFilename = uicontrol(LevelPanel(4),'style','edit',...
          'Position',[300 635 350 25],'fontsize',gui.fs,'backgroundcolor','w',...
          'callback',@txtStimulusFilename_change);
        gui.btnStimulusFilename = uicontrol(LevelPanel(4),'style','pushbutton',...
          'string','Browse...','fontsize',gui.fs,'position',[660 635 100 25],...
          'callback',@btnStimulusFilename_click);
        
        % Stimulus Location Subframe
        gui.OutputLocationPanel = uibuttongroup('parent',LevelPanel(4),'title','Stimulus Location',...
          'units','pixels','position',[300 400 400 220],'fontsize',gui.fs,...
          'SelectionChangeFcn',@OutputLocationPanel_change);
        
        % Radio buttons
        gui.rdoOLType(1) = uicontrol(gui.OutputLocationPanel,'style','radio','fontsize',gui.fs,'string',G.OutputLocationTypes{1},'position',[10 150 180 25]);
        gui.rdoOLType(2) = uicontrol(gui.OutputLocationPanel,'style','radio','fontsize',gui.fs,'string',G.OutputLocationTypes{2},'position',[10 110 180 25]);
        gui.rdoOLType(3) = uicontrol(gui.OutputLocationPanel,'style','radio','fontsize',gui.fs,'string',G.OutputLocationTypes{3},'position',[10 20 180 25]);
        %gui.rdoOLType(4) = uicontrol(gui.OutputLocationPanel,'style','radio','fontsize',gui.fs,'string',G.OutputLocationTypes{4},'position',[10 10 180 25]);
        
        uicontrol(gui.OutputLocationPanel,'style','text','fontsize',gui.fs,'string','Balance','position',[45 80 60 25]);
        gui.cboRandBalance = uicontrol(gui.OutputLocationPanel,'style','popupmenu','fontsize',gui.fs,'string',G.Balance,'position',[110 85 80 25],'backgroundcolor','w','callback',@cboRandBalance_change);
        uicontrol(gui.OutputLocationPanel,'style','text','fontsize',gui.fs,'string','Rand ID','position',[45 50 60 25]);
        gui.txtRandID = uicontrol(gui.OutputLocationPanel,'style','edit','fontsize',gui.fs,'position',[110 55 60 25],'backgroundcolor','w','callback',@txtRandID_change);
        
        
        % Output Locations listbox
        gui.lblOutputLocations = uicontrol(gui.OutputLocationPanel,'style','text','string','Output Locations',...
          'fontsize',gui.fs,'position',[200 180 160 25]);
        gui.lstOutputLocations = uicontrol(gui.OutputLocationPanel,'style','listbox',...
          'max',2,'position',[200 100 160 80],'fontsize',gui.fs,'backgroundcolor','w',...
          'callback',@lstOutputLocations_change);
        
        % Event combobox
        gui.lblRelatedEvent = uicontrol(gui.OutputLocationPanel,'style','text','string','Event',...
          'fontsize',gui.fs,'position',[200 45 160 25]);
        gui.cboRelatedEvent = uicontrol(gui.OutputLocationPanel,'style','popupmenu',...
          'position',[200 20 160 25],'backgroundcolor','w','fontsize',gui.fs,'string',' ',...
          'callback',@cboRelatedEvent_change);
        
        
        
        %--------------------------------------------------------------------
        % Event Conditions UI
        %--------------------------------------------------------------------
        
        gui.ContingencyPanel = uipanel(LevelPanel(4),...
          'units','pixels','position',[10 10 980 380]);
        
        % Expressions List
        uicontrol(gui.ContingencyPanel,'style','text','string','Expressions :',...
          'position',[10 330 120 25],'fontsize',gui.fs)
        gui.lstExpressions = uicontrol(gui.ContingencyPanel,'style','listbox','position',[135 160 700 200], ...
          'backgroundcolor','w','fontsize',gui.fs,'max',2, ...
          'KeyPressFcn',@lstExpressions_Keypress);
        
        % Expression Definition Controls
        %-------------------------------
        % Object to which event applies
        gui.cboObjectA = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[205 130 140 25], ...
          'string','AttentionGetter','value',1,'backgroundcolor','w','fontsize',gui.fs);
        % Event
        gui.cboEventTypeA = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[60 130 140 25], ...
          'string',G.EventTypes,'value',1,'backgroundcolor','w','fontsize',gui.fs, ...
          'callback',{@cboEventType_change,gui.cboObjectA});
        % Binary Operator (+-*/)
        gui.cboEventOperator = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[350 130 40 25], ...
          'string',G.Operators,'value',1,'backgroundcolor','w','fontsize',gui.fs);
        % Multiplier for second expression
        gui.txtEventMultiplier = uicontrol(gui.ContingencyPanel,'style','edit','position',[395 130 60 25],...
          'backgroundcolor','w','fontsize',gui.fs,...
          'callback',@validate_number); % callback to validate data
        % x
        uicontrol(gui.ContingencyPanel,'style','text','string',char(215),'position',[455 130 25 25],'fontsize',gui.fs+4);
        
        % Second Object
        gui.cboObjectB = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[625 130 140 25], ...
          'string','Current Trial','value',1,'backgroundcolor','w','fontsize',gui.fs);
        
        % Second Event
        gui.cboEventTypeB = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[480 130 140 25], ...
          'string',G.EventTypes,'value',1,'backgroundcolor','w','fontsize',gui.fs, ...
          'callback',{@cboEventType_change,gui.cboObjectB});
        
        % Relational Operator (<>=)
        gui.cboRelOperator = uicontrol(gui.ContingencyPanel,'style','popupmenu','position',[770 130 40 25], ...
          'string',G.Comparison,'value',1,'backgroundcolor','w','fontsize',gui.fs);
        % Comparison value
        gui.txtEventScalar = uicontrol(gui.ContingencyPanel,'style','edit','position',[815 130 60 25], ...
          'backgroundcolor','w','fontsize',gui.fs,...
          'callback',@validate_number);
        
        gui.btnSaveExpression = uicontrol(gui.ContingencyPanel,'style','pushbutton','position',[755 100 120 25], ...
          'string','Save Expression','callback',@btnSaveExpression_click,'fontsize',gui.fs);
        
        % Condition text boxes
        uicontrol(gui.ContingencyPanel,'style','text','string','Start Condition :','position',[210 80 120 25], ...
          'fontsize',gui.fs);
        gui.txtStartCondition = uicontrol(gui.ContingencyPanel,'style','edit','position',[335 80 290 25], ...
          'fontsize',gui.fs,'backgroundcolor','w','callback',@txtStartCondition_change);
        uicontrol(gui.ContingencyPanel,'style','text','string','Stop Condition :','position',[210 50 120 25], ...
          'fontsize',gui.fs);
        gui.txtStopCondition = uicontrol(gui.ContingencyPanel,'style','edit','position',[335 50 290 25], ...
          'fontsize',gui.fs,'backgroundcolor','w','callback',@txtStopCondition_change);
        uicontrol(gui.ContingencyPanel,'style','text','string','Failure Condition :','position',[210 20 120 25], ...
          'fontsize',gui.fs);
        gui.txtFailCondition = uicontrol(gui.ContingencyPanel,'style','edit','position',[335 20 290 25], ...
          'fontsize',gui.fs,'backgroundcolor','w','callback',@txtFailCondition_change);
        
      case 5 % Run
        %% Run Level GUI
        
        uicontrol(LevelPanel(5),'style','text','string','Experiment ID','fontsize',gui.fs,'position',[100 700 120 25])
        uicontrol(LevelPanel(5),'style','text','string','Subject ID','fontsize',gui.fs,'position',[100 660 120 25])
        uicontrol(LevelPanel(5),'style','text','string','Date/Time','fontsize',gui.fs,'position',[100 620 120 25])
        uicontrol(LevelPanel(5),'style','text','string','Tester','fontsize',gui.fs,'position',[100 580 120 25])
        uicontrol(LevelPanel(5),'style','text','string','Comments','fontsize',gui.fs,'position',[100 540 120 25])
        
        uicontrol(LevelPanel(5),'style','text','string','Gender','fontsize',gui.fs,'position',[600 660 120 25]);
        uicontrol(LevelPanel(5),'style','text','string','Birthdate','fontsize',gui.fs,'position',[600 620 120 25]);
        uicontrol(LevelPanel(5),'style','text','string','List','fontsize',gui.fs,'position',[600 580 120 25]);
        
        gui.txtExperimentID = uicontrol(LevelPanel(5),'style','text','fontsize',gui.fs,'position',[220 705 160 25]);%,'backgroundcolor','w');
        gui.txtSubjectID = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[220 665 160 25],'backgroundcolor','w');
        gui.txtDateTime = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[220 625 160 25],'backgroundcolor','w');
        gui.txtTester = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[220 585 160 25],'backgroundcolor','w');
        gui.txtComments = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[220 505 320 65],'backgroundcolor','w',...
          'max',2,'horizontalalignment','left');
        
        gui.txtGender = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[720 665 160 25],'backgroundcolor','w');
        gui.txtBirthdate = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[720 625 160 25],'backgroundcolor','w');
        gui.txtList = uicontrol(LevelPanel(5),'style','edit','fontsize',gui.fs,'position',[720 585 160 25],'backgroundcolor','w');
        
        % Condition Table
        gui.tblCondition = uitable(LevelPanel(5),'fontsize',gui.fs,'position',[600 450 300 120],...
          'ColumnName',{'Condition Name','Value'},...
          'ColumnEditable',true,...
          'ColumnFormat',{'char','char'},...
          'Data',{'',''},...
          'ColumnWidth',{100 160},...
          'CellSelectionCallback',@tblCondition_select); 
        
        uicontrol(LevelPanel(5),'style','pushbutton','fontsize',gui.fs,'position',[600 420 140 25],...
          'string','New Condition','callback',@NewCondition);
        uicontrol(LevelPanel(5),'style','pushbutton','fontsize',gui.fs,'position',[760 420 140 25],...
          'string','Delete Condition','callback',@DeleteCondition);
        
        
        gui.chkInfoSlide = uicontrol(LevelPanel(5),'style','checkbox','fontsize',gui.fs,'position',[600 280 160 25],...
          'string','Show Info Slides','callback',@chkInfoSlide_change);
        gui.cboInfoSlideOL = uicontrol(LevelPanel(5),'style','popupmenu','fontsize',gui.fs,'position',[760 280 120 25],'backgroundcolor','w',...
          'string','test','callback',@cboInfoSlideOL_change);
        
        
        uicontrol(LevelPanel(5),'style','pushbutton','fontsize',gui.fs,'position',[390 625 40 25],...
          'string','now','callback',@Update_DateTime);
        
        uicontrol(LevelPanel(5),'style','pushbutton','fontsize',gui.fs,'position',[220 280 320 30],...
          'string','Run Experiment','Callback',@Run_Experiment);
        
    end
    
    
  end
  

  
  refreshGUI()
  
  % -- END OF MAIN FUNCTION --
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                         Subfunctions
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  %% refreshGUI
  function refreshGUI()
    switch CurrentLevel
      case 1 %----- Experiment -----%
        
        % Experiment ID
        set(gui.txtExperiment,'string',S.Experiment.Name);
        
        % Phase List
        if isempty(S.Experiment.Phases)
          set(gui.lstPhases,'string','');
        else
          set(gui.lstPhases,'string',{S.Experiment.Phases.Name},'value',WorkingPhase);
        end
        
        % Phase Order
        set(gui.cboPhaseOrder,'value',strmatch(S.Experiment.PhaseOrder,G.PhaseOrder,'exact'));
        
      case 2 %----- Phase -----%
        % Experiment ID
        set(gui.btnExperiment,'string',S.Experiment.Name);
        
        % Phase ID
        set(gui.txtPhase,'string',S.Experiment.Phases(WorkingPhase).Name);
        
        % Item List
        if isfield(S.Experiment.Phases(WorkingPhase),'Items') && ~isempty(S.Experiment.Phases(WorkingPhase).Items)
          n = length(S.Experiment.Phases(WorkingPhase).Items);
          WorkingItem = min(n,WorkingItem);
          set(gui.lstItems,'string',{S.Experiment.Phases(WorkingPhase).Items.Name},'value',WorkingItem);
        else
          set(gui.lstItems,'string','');
        end
        
        % Item (Trial) Order
        set(gui.cboItemOrder,'value',S.Experiment.Phases(WorkingPhase).ItemOrder);
        
        % Repetitions
        set(gui.txtRepetitions,'string',num2str(S.Experiment.Phases(WorkingPhase).Repetitions));
        
        % Phase End Condition
        v = find(strcmp(S.Experiment.Phases(WorkingPhase).PhaseEnd,G.PhaseEnd));
        set(gui.cboPhaseEnd,'value',v);
        set(gui.panelPhaseEnd(v),'visible','on');
        set(gui.panelPhaseEnd((1:3)~=v),'visible','off');
        
        % Time Limit
        set(gui.txtPhaseEndTime,'string',num2str(S.Experiment.Phases(WorkingPhase).TimeLimit));
        
        % Contingency Fields
        set(gui.chkIgnoreFailed,'value',S.Experiment.Phases(WorkingPhase).IgnoreFailed);
        set(gui.cboPhaseMeasureA,'value',S.Experiment.Phases(WorkingPhase).MeasureA);
        set(gui.cboPhaseGroupA,'value',S.Experiment.Phases(WorkingPhase).GroupA);
        set(gui.txtPhaseNA,'string',num2str(S.Experiment.Phases(WorkingPhase).nA));
        set(gui.cboPhaseMeasureB,'value',S.Experiment.Phases(WorkingPhase).MeasureB);
        set(gui.cboPhaseGroupB,'value',S.Experiment.Phases(WorkingPhase).GroupB);
        set(gui.txtPhaseNB,'string',num2str(S.Experiment.Phases(WorkingPhase).nB));
        set(gui.txtPhaseEndMultiplier,'string',num2str(S.Experiment.Phases(WorkingPhase).Multiplier));
        set(gui.cboPhaseEndOperator,'value',S.Experiment.Phases(WorkingPhase).Operator);
        set(gui.txtPhaseEndScalar,'string',num2str(S.Experiment.Phases(WorkingPhase).Scalar));
        
      case 3 %----- Item -----%
        % Experiment ID
        set(gui.btnExperiment,'string',S.Experiment.Name);
        
        % Phase ID
        set(gui.btnPhase,'string',S.Experiment.Phases(WorkingPhase).Name);
        
        % Item ID
        set(gui.txtItem,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Name);
        
        % Event List
        % Make sure WorkingEvent is valid so listbox renders.
        WorkingEvent = min(max(WorkingEvent,1), length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events));
        if isfield(S.Experiment.Phases(WorkingPhase).Items(WorkingItem),'Events') && ...
            ~isempty(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events)
          set(gui.lstEvents,'string',{S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events.Name},'value',WorkingEvent);
        else
          set(gui.lstEvents,'string','');
        end
        
        % Repeat on Failure
        set(gui.cboRepeatOnFail,'value',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatOnFail);
        try
          set(gui.cboRepeatsAllowed,'value',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatsAllowed);
        catch
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatsAllowed = 1;
          set(gui.cboRepeatsAllowed,'value',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatsAllowed);
        end
        
      case 4 %----- Event -----%
        % Experiment ID
        set(gui.btnExperiment,'string',S.Experiment.Name);
        
        % Phase ID
        set(gui.btnPhase,'string',S.Experiment.Phases(WorkingPhase).Name);
        
        % Item ID
        set(gui.btnItem,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Name);
        
        % Event ID
        set(gui.txtEvent,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).Name);
        
        % Stimulus Filename
        set(gui.txtStimulusFilename,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StimulusFilename);
        
        % Output Location Radio Buttons
        set(gui.rdoOLType(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocationType),'value',1);
        
        % Output Locations Listbox
        tempOL = S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocation;
        if max(tempOL) > length(S.OL.OL)
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocation = tempOL(tempOL <= length(S.OL.OL));
        end
        set(gui.lstOutputLocations,'string',{S.OL.OL.Name},'value',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocation);
        
        % RandBalance combobox
        if ~isfield(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent),'RandBalance') || ...
            isempty(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandBalance) 
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandBalance = 1;
        end
        set(gui.cboRandBalance,'value',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandBalance);
        
        % RandID textbox
        if ~isfield(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent),'RandID')
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandID = '';
        end
        set(gui.txtRandID,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandID);
        
        % Related Event
        %  Check to see if the stored event name matches the list of events
        evtlist = {S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events.Name};
        evtidx = strmatch(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelatedEvent,evtlist,'exact');
        if isempty(evtidx)
          evtidx = 1;
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelatedEvent = evtlist{1};
        end
        set(gui.cboRelatedEvent,'string',evtlist,'value',evtidx);
        
        % Expressions listbox
        set(gui.lstExpressions,'string',build_expressions(),'value',1);
        
        % Update cboObjectA,B based on values of cboEventTypeA,B
        cboEventType_change(gui.cboEventTypeA,[],gui.cboObjectA);
        cboEventType_change(gui.cboEventTypeB,[],gui.cboObjectB);
        
        % Event Conditions (start, stop, fail)
        set(gui.txtStartCondition,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StartCondition);
        set(gui.txtStopCondition,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StopCondition);
        set(gui.txtFailCondition,'string',S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).FailCondition);
        
      case 5 % Run
        % Experiment ID
        set(gui.txtExperimentID,'string',S.Experiment.Name);
        
        % Date/Time
        set(gui.txtDateTime,'string',datestr(now(),'yyyy-mm-dd HH:MM'));
        
        % Summary Slide OL
        if ~isfield(S.Experiment,'ShowInfoSlide')
          S.Experiment.ShowInfoSlide = 1;
        end
        if ~isfield(S.Experiment,'InfoSlideOL')
          S.Experiment.InfoSlideOL = 1;
        end
        
        set(gui.chkInfoSlide,'value',S.Experiment.ShowInfoSlide);
        set(gui.cboInfoSlideOL,'string',{S.OL.OL.Name},'value',S.Experiment.InfoSlideOL);
        
        if ~isfield(S.Results,'Condition');
          S.Results.Condition = {'' ''};
        end
        set(gui.tblCondition,'Data',S.Results.Condition);
    end
    
    set(LevelPanel(CurrentLevel),'visible','on');
    set(LevelPanel((1:5)~=CurrentLevel),'visible','off');
    
    set(f,'Name',[G.ProgramName ' - ' SettingsFile]);
    
    
  end
  
  %% ExitExperiment
  function ExitExperiment(obj, events)
    % Do any last-minute cleanup
    pos = get(f,'Position');
    setpref('SaffranExperiment','Position',pos(1:2));
    
    % Determine if changes have been made to S.
    S.Results = [];
    S0.Results = [];
    
    if isequal(S,S0)
      % No changes have been made to S.  No need to save.
      delete(f)
    else
      % Changes have been made to S.  Prompt to save.
      button = questdlg(['Save changes to ' SettingsFile '?'],'Save Settings');
      switch button
        case 'Yes'
          % save settings and close figure
          SaveSettings();
          delete(f)
        case 'No'
          % close figure
          delete(f)
      end
    end
  end
  
  %% New_Experiment
  function New_Experiment(obj, events)
    % Clear information about experiment
    % Note that information about output locations, special file paths is not cleard
    
    S.Results = [];
    S.Experiment = [];
    S.Experiment.Name = '';
    S.Experiment.Phases = [];
    S.Experiment.PhaseOrder = G.PhaseOrder{1};
    SettingsFile = '';
    
    set(f,'Name',[G.ProgramName ' - ' SettingsFile]);
    
    CurrentLevel = 1;
    refreshGUI()
    
    S0 = S;  % Create a copy of S at its initial state. 
  end
  
  %% Load_Experiment
  function Load_Experiment(obj, events)
    [fname,pname] = uigetfile('*.txt','Load Experiment Settings',getpref('SaffranExperiment','SettingsDir'));
    if ~isequal(fname,0)
      setpref('SaffranExperiment','SettingsDir',pname);
      SettingsFile = [pname fname];
      LoadSettings()

      CurrentLevel = 1;
      refreshGUI()
    end
    
  end
  
  %% Save_Experiment
  function Save_Experiment(obj, events)
    SaveSettings()
  end
  
  %% Save_Experiment_As
  function Save_Experiment_As(obj, events)
    [fname,pname]=uiputfile('*.txt','Save Experiment Settings');
    if ~isequal(fname,0)
      SettingsFile = [pname fname];
      SaveSettings()
    end
  end  
  
  %% SaveSettings
  function SaveSettings(obj, events)
    S.Results = [];
    ss = gencode(S);
    
    fid = fopen(SettingsFile,'w');
    fprintf(fid,'%s\n',ss{:});
    fclose(fid);
    set(f,'Name',[G.ProgramName ' - ' SettingsFile]);
    
    S0 = S;
  end
  
  %% LoadSettings
  function LoadSettings(obj, events)
    if exist(SettingsFile,'file')
      fid = fopen(SettingsFile);
      ss = textscan(fid,'%[^\n]');
      ss = ss{1};
      fclose(fid);
      S = [];
      eval(sprintf('%s\n',ss{:}));
    end
    
    if ~isfield(S,'UsePsychPortAudio'), S.UsePsychPortAudio = true; end
    
    S0 = S; % Store copy of S to determine if changes have occurred later.
  end
  
  %% ChangeLevel
  function ChangeLevel(obj, events, NewLevel)
    if nargin == 3
      % For changing level using the ID buttons
      CurrentLevel = NewLevel;
    else
      % For changing level using the Level menu
      CurrentLevel = strmatch(get(obj, 'Label'),G.LevelNames);
    end
    
    refreshGUI()
  end
  
  %% Context Menu New
  function cmenuNew(obj, events)
    
    % Create a new object
    switch CurrentLevel
      case 1
        % Create a new phase and set default values
        WorkingPhase = length(S.Experiment.Phases) + 1;
        S.Experiment.Phases(WorkingPhase).Name = 'New Phase';
        S.Experiment.Phases(WorkingPhase).ItemOrder = 1;
        
        S.Experiment.Phases(WorkingPhase).Repetitions = 1;
        
        S.Experiment.Phases(WorkingPhase).PhaseEnd = G.PhaseEnd{1};
        S.Experiment.Phases(WorkingPhase).TimeLimit = 60;
        S.Experiment.Phases(WorkingPhase).MeasureA = 1;
        S.Experiment.Phases(WorkingPhase).GroupA = 1;
        S.Experiment.Phases(WorkingPhase).nA = 5;
        S.Experiment.Phases(WorkingPhase).MeasureB = 1;
        S.Experiment.Phases(WorkingPhase).GroupB = 1;
        S.Experiment.Phases(WorkingPhase).nB = 5;
        S.Experiment.Phases(WorkingPhase).Multiplier = 0;
        S.Experiment.Phases(WorkingPhase).Operator = 1;
        S.Experiment.Phases(WorkingPhase).Scalar = 0;
        S.Experiment.Phases(WorkingPhase).IgnoreFailed = 1;
        
      case 2
        % Create a new item
        if ~isfield(S.Experiment.Phases(WorkingPhase),'Items')
          S.Experiment.Phases(WorkingPhase).Items = [];
        end
        WorkingItem = length(S.Experiment.Phases(WorkingPhase).Items) + 1;
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Name = 'New Item';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatOnFail = 1;
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatsAllowed = 1;        
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events = [];
      case 3
        % Create a new event
        if ~isfield(S.Experiment.Phases(WorkingPhase).Items(WorkingItem),'Events')
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events = [];
        end
        WorkingEvent = length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events) + 1;
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).Name = 'New Event';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StimulusFilename = '';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocationType = 1;
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocation = [];
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelatedEvent = '';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ExpressionID = [];
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectA = {};
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectB = {};
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StartCondition = '';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StopCondition = '';
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).FailCondition = '';
        
    end
    refreshGUI()
  end
  
  %% Context Menu Edit
  function cmenuEdit(obj, events)
    % Edit selected object
    CurrentLevel = CurrentLevel + 1; % Edit always applies to next level object
    refreshGUI()
  end
  
  %% Context Menu Copy
  function cmenuCopy(obj, events)
    % Copy selected object
    switch CurrentLevel
      case 1 
        % Copy Phase
        newidx = length(S.Experiment.Phases) + 1;
        S.Experiment.Phases(newidx) = S.Experiment.Phases(WorkingPhase);
        WorkingPhase = newidx;
        
      case 2 
        % Copy Item
        newidx = length(S.Experiment.Phases(WorkingPhase).Items) + 1;
        S.Experiment.Phases(WorkingPhase).Items(newidx) = ...
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem);
        WorkingItem = newidx;
        
      case 3 
        % Copy Event
        newidx = length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events) + 1;
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(newidx) = ...
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent);
        WorkingEvent = newidx;
    end
    
    refreshGUI()
  end
  
  %% Context Menu Delete
  function cmenuDelete(obj, events)
    % Delete selected object
    switch CurrentLevel
      case 1
        % Delete Phase
        S.Experiment.Phases(WorkingPhase) = [];
        WorkingPhase = min(length(S.Experiment.Phases),WorkingPhase);
      case 2
        % Delete Item
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem) = [];
        WorkingItem = min(length(S.Experiment.Phases(WorkingPhase).Items), WorkingItem);
      case 3
        % Delete Event 
        S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent) = [];
        WorkingEvent = min(length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events), WorkingEvent);
    end
    
    refreshGUI()
  end
  
  %% Context Menu Up
  function cmenuUp(obj, events)
    % Move selected object up in list
    switch CurrentLevel
      
      case 1 % Move Phase Up
        
        if WorkingPhase > 1
          v = 1:length(S.Experiment.Phases);
          v([WorkingPhase-1 WorkingPhase]) = v([WorkingPhase WorkingPhase-1]);
          WorkingPhase = WorkingPhase - 1;
          S.Experiment.Phases = S.Experiment.Phases(v);
        end
        
      case 2 % Move Item Up
        
        if WorkingItem > 1
          v = 1:length(S.Experiment.Phases(WorkingPhase).Items);
          v([WorkingItem-1 WorkingItem]) = v([WorkingItem WorkingItem-1]);
          WorkingItem = WorkingItem - 1;
          S.Experiment.Phases(WorkingPhase).Items = ...
            S.Experiment.Phases(WorkingPhase).Items(v);
        end
        
      case 3 % Move Event Up
        
        if WorkingEvent > 1
          v = 1:length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events);
          v([WorkingEvent-1 WorkingEvent]) = v([WorkingEvent WorkingEvent-1]);
          WorkingEvent = WorkingEvent - 1;
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events = ...
            S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(v);
        end
    end
    
    refreshGUI()
    
  end
  
  %% Context Menu Down
  function cmenuDown(obj, events)
    % Move selected object down in list
    switch CurrentLevel
      
      case 1 % Move Phase Down
        L = length(S.Experiment.Phases);
        if WorkingPhase < L
          v = 1:L;
          v([WorkingPhase WorkingPhase + 1]) = v([WorkingPhase + 1 WorkingPhase]);
          WorkingPhase = WorkingPhase + 1;
          S.Experiment.Phases = S.Experiment.Phases(v);
        end
        
      case 2 % Move Item Down
        
        L = length(S.Experiment.Phases(WorkingPhase).Items);
        if WorkingItem < L
          v = 1:L;
          v([WorkingItem WorkingItem + 1]) = v([WorkingItem + 1 WorkingItem]);
          WorkingItem = WorkingItem + 1;
          S.Experiment.Phases(WorkingPhase).Items = ...
            S.Experiment.Phases(WorkingPhase).Items(v);
        end
        
      case 3 % Move Event Down
        
        L = length(S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events);
        if WorkingEvent < L
          v = 1:L;
          v([WorkingEvent WorkingEvent + 1]) = v([WorkingEvent + 1 WorkingEvent]);
          WorkingEvent = WorkingEvent + 1;
          S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events = ...
            S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(v);
        end
    end
    
    refreshGUI()
  end
  
  %% Set Output Locations
  function SetOutputLocations(obj, events)
    % Show the hardware configuration form
    S.OL = ConfigureHardware(S.OL);
  end
  
  %% txtExperiment_change
  function txtExperiment_change(obj, events)
    S.Experiment.Name = get(obj, 'string');
  end
  
  %% lstPhases_change : Phase List Callback
  function lstPhases_change(obj, events)
    WorkingPhase = get(obj, 'value');
    
    % Double-click to edit the phase
    if strcmpi(get(f,'SelectionType'),'open')
      cmenuEdit()
    end
  end
  
  %% cboPhaseOrder_change
  function cboPhaseOrder_change(obj, events)
    S.Experiment.PhaseOrder = G.PhaseOrder(get(obj,'value'));
  end
  
  %% txtPhase_change
  function txtPhase_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Name = get(obj, 'string');
  end
  
  %% lstItems_change
  function lstItems_change(obj, events)
    WorkingItem = get(obj,'value');
    
    % Double-click to edit the item
    if strcmpi(get(f,'SelectionType'),'open')
      cmenuEdit()
    end
  end
  
  %% cboItemOrder_change
  function cboItemOrder_change(obj, events)
    S.Experiment.Phases(WorkingPhase).ItemOrder = get(obj,'value');
  end
  
  %% txtRepetitions_change
  function txtRepetitions_change(obj, events)
    v = round(str2double(get(obj,'string')));
    if isnan(v), v = 1; end
    S.Experiment.Phases(WorkingPhase).Repetitions = v;
    set(obj,'string',num2str(v)); % Write value back to textbox in case any rounding, etc, was required
  end
  
  %% cboPhaseEnd_change
  function cboPhaseEnd_change(obj, events)
    v = get(obj,'value');
    set(gui.panelPhaseEnd(v),'visible','on');
    set(gui.panelPhaseEnd((1:3)~=v),'visible','off');
    
    S.Experiment.Phases(WorkingPhase).PhaseEnd = G.PhaseEnd{v};
    
  end
  
  %% txtPhaseEndTime_change
  function txtPhaseEndTime_change(obj, events)
    v = str2double(get(obj,'string'));
    if isnan(v), v = 0; end
    S.Experiment.Phases(WorkingPhase).TimeLimit = v;
    set(obj,'string',num2str(v));
  end
  
  %% cboPhaseMeasureA_change
  function cboPhaseMeasureA_change(obj, events)
    S.Experiment.Phases(WorkingPhase).MeasureA = get(obj,'value');
  end
  
  %% cboPhaseGroupA_change
  function cboPhaseGroupA_change(obj, events)
    S.Experiment.Phases(WorkingPhase).GroupA = get(obj, 'value');
  end
  
  %% txtPhaseNA_change
  function txtPhaseNA_change(obj, events)
    v = round(str2double(get(obj,'string'))); % Must be an integer
    if isnan(v), v = 0; end
    S.Experiment.Phases(WorkingPhase).nA = v;
  end
  
  %% cboPhaseMeasureB_change
  function cboPhaseMeasureB_change(obj, events)
    S.Experiment.Phases(WorkingPhase).MeasureB = get(obj,'value');
  end
  
  %% cboPhaseGroupB_change
  function cboPhaseGroupB_change(obj, events)
    S.Experiment.Phases(WorkingPhase).GroupB = get(obj, 'value');
  end
  
  %% txtPhaseNB_change
  function txtPhaseNB_change(obj, events)
    v = round(str2double(get(obj,'string'))); % Must be an integer
    if isnan(v), v = 0; end
    S.Experiment.Phases(WorkingPhase).nB = v;
  end
  
  %% txtPhaseEndMultiplier_change
  function txtPhaseEndMultiplier_change(obj, events)
    v = str2double(get(obj,'string'));
    if isnan(v), v = 0; end
    S.Experiment.Phases(WorkingPhase).Multiplier = v;
    set(obj,'string',num2str(v));
  end
  
  %% cboPhaseEndOperator_change
  function cboPhaseEndOperator_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Operator = get(obj,'value');
  end
  
  %% txtPhaseEndScalar_change
  function txtPhaseEndScalar_change(obj, events)
    v = str2double(get(obj,'string'));
    if isnan(v), v = 0; end
    S.Experiment.Phases(WorkingPhase).Scalar = v;
    set(obj,'string',num2str(v));
  end
  
  %% txtItem_change
  function txtItem_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Name = get(obj,'string');
  end
  
  %% lstEvents_change : Events List Callback
  function lstEvents_change(obj, events)
    WorkingEvent = get(obj, 'value');
    
    % Double-click to edit the event
    if strcmpi(get(f,'SelectionType'),'open')
      cmenuEdit()
    end
  end
  
  %% cboRepeatOnFail_change
  function cboRepeatOnFail_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatOnFail = get(obj,'value');
  end
  
  %% txtEvent_change
  function txtEvent_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).Name = get(obj,'string');
    refreshGUI()
  end
  
  %% txtStimulusFilename_change
  function txtStimulusFilename_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StimulusFilename = get(obj,'string');
  end
  
  %% btnStimulusFilename_click
  function btnStimulusFilename_click(obj, events)
    % Present a file selection dialog box
    
    % Note that the starting directory is retained between sessions
    if ispref('SaffranExperiment','StimulusDir')
      StimulusDir = getpref('SaffranExperiment','StimulusDir');
    else
      addpref('SaffranExperiment','StimulusDir','');
      StimulusDir = cd;
    end
    [fname, pname] = uigetfile(G.MediaFilter,'Select a stimulus file',StimulusDir);
    if fname ~= 0
      stimfile = fullfile(pname,fname);
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StimulusFilename = stimfile;
      set(gui.txtStimulusFilename,'string',stimfile)
      setpref('SaffranExperiment','StimulusDir',pname);
    end
  end
  
  %% OutputLocationPanel_change
  function OutputLocationPanel_change(obj, events)
    % Store the index of the Output Location Type
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocationType = ...
      strmatch(get(get(obj,'SelectedObject'),'string'),G.OutputLocationTypes,'exact');
  end
  
  %% lstOutputLocations_change
  function lstOutputLocations_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).OutputLocation = get(obj,'value');
  end
  
  %% cboRelatedEvent_change
  function cboRelatedEvent_change(obj, events)
    % Store the name of the related event -- for this to work, we need
    % unique event names
    eventlist = get(obj,'string');
    RelatedEvent = eventlist{get(obj,'value')};
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelatedEvent = RelatedEvent;
  end
  
  %% cboEventType_change
  function cboEventType_change(obj, events, dest_obj)
    % Update gui.cboObject(A or B) based on selected EventType
    eventlist = get(obj,'string');
    eventparts = regexp(eventlist{get(obj,'value')},'\w*','match');
    
    switch eventparts{1}
      case 'trial'
        set(dest_obj,'string','CurrentTrial','value',1);
      case 'event'
        % Generate list of events
        evtlist = {S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events.Name};
        set(dest_obj,'string',evtlist,'value',min(length(evtlist),get(dest_obj,'value')));
      case 'key'
        % Need to generate list of keys?
        %OLsymbols = strcat('OL_',cellstr(num2str((1:length(S.OL.OL))')))';  % OL_1, OL_2, etc...
        OLsymbols = strcat('OL_',{S.OL.OL.Name});                            % e.g. OL_Left, OL_Center, ...
        othersymbols = fieldnames(S.Keys)';
        KeyList = [{'Correct' 'Incorrect'} OLsymbols othersymbols];
        set(dest_obj,'string',KeyList,'value',min(length(KeyList),get(dest_obj,'value')));
    end
    
  end
  
  %% validate_number - Enforce numeric input to a text box
  function validate_number(obj, events)
    v = str2double(get(obj, 'string'));
    if isnan(v), v = 0; end             % Non-numeric entries are set to zero
    set(obj,'string',num2str(v));
  end
  
  %% btnSaveExpression_click
  function btnSaveExpression_click(obj, events)
    % Save an expression to the database and update the expression listbox
    
    validate_number(gui.txtEventMultiplier);
    validate_number(gui.txtEventScalar);
    
    % Must determine new expression number
    ExpID = S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ExpressionID;
    if isempty(ExpID)
      ExpNum = 1;
      expidx = 1;
    else
      ExpNum = max(ExpID) + 1;
      expidx = length(ExpID) + 1;
    end
    
    % Store components of expression to database
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ExpressionID(expidx) = ExpNum;
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventTypeA(expidx) = get(gui.cboEventTypeA,'value');
    objs = get(gui.cboObjectA,'string');
    if ~iscell(objs), objs = {objs}; end
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectA{expidx} = objs{get(gui.cboObjectA,'value')};
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventOperator(expidx) = get(gui.cboEventOperator,'value');
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).Multiplier(expidx) = str2double(get(gui.txtEventMultiplier,'string'));
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventTypeB(expidx) = get(gui.cboEventTypeB,'value');
    objs = get(gui.cboObjectB,'string');
    if ~iscell(objs), objs = {objs}; end
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectB{expidx} = objs{get(gui.cboObjectB,'value')};
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelOperator(expidx) = get(gui.cboRelOperator,'value');
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventScalar(expidx) = str2double(get(gui.txtEventScalar,'string'));
    
    refreshGUI()
  end
  
  % build_expressions
  function explist = build_expressions()
    % Return a cell array of expression strings built from stored
    % expression components
    
    evt = S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent);
    explist = cell(1,length(evt.ExpressionID));
    for m = 1:length(evt.ExpressionID)
      explist{m} = ['e' num2str(evt.ExpressionID(m)) ': ' G.EventTypes{evt.EventTypeA(m)} ...
        '(' evt.ObjectA{m} ')' G.Operators{evt.EventOperator(m)} ' ' num2str(evt.Multiplier(m)) ...
        ' * ' G.EventTypes{evt.EventTypeB(m)} '(' evt.ObjectB{m} ')' ...
        G.Comparison{evt.RelOperator(m)} ' ' num2str(evt.EventScalar(m))];
    end
  end
  
  %% lstExpressions_Keypress
  function lstExpressions_Keypress(obj, events)
    if strcmp(events.Key,'delete')
      expidx = get(obj,'value');
      % delete the selected Expression
      % Must remove:
      % - ExpressionID
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ExpressionID(expidx) = [];
      % - EventTypeA (B)
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventTypeA(expidx) = [];
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventTypeB(expidx) = [];
      % - ObjectA (B)
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectA(expidx) = [];
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).ObjectB(expidx) = [];
      % - EventOperator
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventOperator(expidx) = [];
      % - Multiplier
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).Multiplier(expidx) = [];
      % - RelOperator
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RelOperator(expidx) = [];
      % - EventScalar
      S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).EventScalar(expidx) = [];
      
      if expidx == length(get(obj,'string')) && expidx > 1
        set(obj,'value',expidx - 1);
      end
      refreshGUI();
    end
  end
  
  %% txtStartCondition_change
  function txtStartCondition_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StartCondition = get(obj,'string');
  end
  
  %% txtStopCondition_change
  function txtStopCondition_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).StopCondition = get(obj,'string');
  end
  
  %% txtFailCondition_change
  function txtFailCondition_change(obj, events)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).FailCondition = get(obj,'string');
  end
  
  %% File Paths Dialog Box
  function SetFilePaths(obj, events)
    % Provide UI to define default stimulus path and results destination
    try
      dfp = {S.Paths.StimulusPath S.Paths.ResultsPath};
    catch
      dfp = {'' ''}; % Default file paths are empty
    end
    
    fp = inputdlg({'Default Stimulus Path' 'Results File Path'},'File Paths',1,dfp,'on');
    % If user presses Cancel, fp = {}
    if ~isempty(fp)
      S.Paths.StimulusPath = fp{1};
      S.Paths.ResultsPath = fp{2};
    end
    
  end
  
  %% Key Definition Dialog Box
  function SetKeyDefinitions(obj, events)
    % Allow definition of keys for selected actions
    if isfield(S,'Keys')
      S.Keys = ConfigureKeys(S.Keys);
    else
      S.Keys = ConfigureKeys();
    end
  end
  
  %% Run Experiment
  function Run_Experiment(obj, events)
    % Only one results set is stored in a given settings file.
    
    % Results are written to the results directory in a settings-style file immediately after the experiment
    % using a name based on the date, experiment name, subject id, and maybe some other identifier.
    S.Results = [];
    % Initial values from the Run Experiment form
    S.Results.SubjectID = get(gui.txtSubjectID,'string');
    S.Results.DateTime = get(gui.txtDateTime,'string');
    S.Results.Tester = get(gui.txtTester,'string');
    S.Results.Comments = get(gui.txtComments,'string');
    
    S.Results.Gender = get(gui.txtGender,'string');
    S.Results.Birthdate = get(gui.txtBirthdate,'string');
    S.Results.List = get(gui.txtList,'string');
    S.Results.Condition = get(gui.tblCondition,'data');
    
    S.Results.Trials = [];
    
    % Run the experiment and store the results
    S.Results = RunExperiment(S);
    
    fname = fullfile(S.Paths.ResultsPath,[datestr(S.Results.DateTime,'yyyy-mm-dd-HHMM') ...
      '_' S.Experiment.Name '_' S.Results.SubjectID '.txt']);
    
    % Write experiment results to disk
    ss = gencode(S);
    fid = fopen(fname,'w');
    fprintf(fid,'%s\n',ss{:});
    fclose(fid);
    
    % Reset fields for next subject
    set(gui.txtSubjectID,'string','');
    set(gui.txtDateTime,'string',datestr(now(),'yyyy-mm-dd HH:MM'));
    set(gui.txtGender,'string','');
    set(gui.txtBirthdate,'string','');
    set(gui.txtComments,'string','');
    
  end
  
  %% Process_Results
  function Process_Results(obj, events)
    % Call the Process Results GUI
    ProcessResultsGUI(S.Paths.ResultsPath);
  end
  
  %% Convert Images to BMP
  function ConvertToBMP(obj, events)
    % Get a list if image formats
    imgfmt = imformats;
    imgext = strcat('*.',[imgfmt.ext]);
    filterspec = sprintf('%s;',imgext{:});
    
    [fname, pname] = uigetfile([[filterspec {'All Image Files'}];{'*.*','All Files (*.*)'}],'Select Images to Convert to BMP','multiselect','on');
    imgfnames = strcat(pname,fname);
    if ~iscell(imgfnames)
      imgfnames = {imgfnames};
    end
    
    for ii = 1:length(imgfnames)
      [imgpath,imgname]=fileparts(imgfnames{ii});
      
      try
        img = imread(imgfnames{ii});
        newimgname = fullfile(imgpath,[imgname '.bmp']);
        imwrite(img,newimgname,'bmp');
        disp(['Converted ' imgfnames{ii} ' to ' newimgname])
      catch myex
        disp(['Problem converting ' imgfnames{ii}])
        warning(myex.message)
      end
    end
    msgbox('Conversion to bitmap is complete.','Convert Image to BMP')

  end
  
  %% cboRandBalance_change
  function cboRandBalance_change(obj, evt)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandBalance = get(obj,'value');
  end
  
  %% txtRandID_change
  function txtRandID_change(obj, evt)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).Events(WorkingEvent).RandID = get(obj,'string');
  end
  
  %% chkIgnoreFailed_change
  function chkIgnoreFailed_change(obj, evt)
    S.Experiment.Phases(WorkingPhase).IgnoreFailed = get(gui.chkIgnoreFailed,'value');
  end
  
  %% cboRepeatsAllowed_change
  function cboRepeatsAllowed_change(obj, evt)
    S.Experiment.Phases(WorkingPhase).Items(WorkingItem).RepeatsAllowed = get(gui.cboRepeatsAllowed,'value');
  end
  
%   %% Callback for Use PsychPortAudio menu item
%   function UsePsychPortAudio(obj, evt)
%     
%     % Toggle the value
%     S.UsePsychPortAudio = ~S.UsePsychPortAudio;
%     
%     % Set the check to match the value
%     set(obj,'checked',iif(S.UsePsychPortAudio,'on','off'));
%     
%   end
  
%% About Box
  function showAboutBox(obj, evt)    
    msg = {G.ProgramName
      ''
      'gencode.m, gencode_rvalue.m, gencode_substruct.m, hgsave_pre2008a.m (c) 2009 Freiburg Brain Imaging'
      ''
      'All other code (c) 2010, Robert H. Olson'
      'All rights reserved.'
      ''
      'Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:'
      '   *  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.'
      '   *  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.'
      ''
      'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'
      ''};
    %msgbox(msg,'About...','modal');
    
    hDialog = dialog('name',['About ' G.ProgramName]);
    uicontrol(hDialog,'style','edit','units','normalized','position',[.05 .05 .9 .9],'fontsize',gui.fs,'max',2,'string',msg,'backgroundcolor','w','horizontalalign','left');
  end

  %% Help - Users Guide
  function showUsersGuide(obj,evt)
    % Open PDF version of user's guide.
    open(fullfile(fileparts(mfilename('fullpath')), 'help', 'users_guide.pdf'));    
  end
%% Help - Data Structure
  function showDataStructure(obj,evt)
    % Open PDF version of data structure help.
    open(fullfile(fileparts(mfilename('fullpath')), 'help', 'data_structure.pdf'));    
  end
  
  %% Help - Output Format Creation
  function showOutputFormatCreation(obj,evt)
    % Open PDF version of Output Format Creation help.
    open(fullfile(fileparts(mfilename('fullpath')), 'help', 'output_format_creation.pdf'));
  end
  
  %% Update_DateTime
  function Update_DateTime(obj, evt)
    set(gui.txtDateTime,'string',datestr(now(),'yyyy-mm-dd HH:MM'));    
  end
  
  %% chkInfoSlide_change
  function chkInfoSlide_change(obj, evt)
    S.Experiment.ShowInfoSlide = get(obj,'value');
  end
  
  %% cboInfoSlideOL_change
  function cboInfoSlideOL_change(obj, evt)
    S.Experiment.InfoSlideOL = get(obj,'value');
  end
  
  %% tblCondition_select
  function tblCondition_select(obj, evt)
    % Callback fires when the condition table selection changes
    % Track which row is selected (needed for DeleteCondition)
    disp('Condition_select')
    if numel(evt.Indices) > 0
      ConditionRow = evt.Indices(1);
    else
      ConditionRow = [];
    end
  end
  
  %% New Condition
  function NewCondition(obj, evt)
    % Add a row to the condition table.
    condData = get(gui.tblCondition,'data');
    condRows = size(condData,1);
    condData{condRows+1,1} = '';
    set(gui.tblCondition,'Data',condData);
  end
  
  %% Delete Condition
  function DeleteCondition(obj, evt)
    disp('Delete Condition')
    % Delete the selected row from the condition table
    condData = get(gui.tblCondition,'data');
    condData(ConditionRow,:) = []; % Delete a row
    set(gui.tblCondition,'Data',condData);
  end
  
  %% IIF function
  function result=iif(cond, t, f)
    if cond
      result = t;
    else
      result = f;
    end
  end
end % Experiment
