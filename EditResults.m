function EditResults(resultsdir)
% EDITRESULTS - Update descriptive information in a WISP results file.
%
%
% 2010-12-17 : Created by Robert H. Olson, Ph.D. rolson@waisman.wisc.edu

%% Global Variables
S = []; % Results structure

gui.xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure
gui.fs = 10; % Font size for GUI elements

ConditionRow = []; % Keep track of which row in Condition table is selected (if any)

%% Load results file

if nargin == 0
  resultsdir = pwd;
end

[fname,pname] = uigetfile('*.txt','Load Experiment Results File',resultsdir);
if ~isequal(fname,0)
  setpref('SaffranExperiment','SettingsDir',pname);
  SettingsFile = [pname fname];
  LoadSettings()
else
  return
end


%% Create form
f = figure('MenuBar', 'None',  ...
  'Name', 'Edit Results File', ...
  'NumberTitle', 'off', 'IntegerHandle', 'off', ...
  'Position',[gui.xy 1000 800], ...
  'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
  'HandleVisibility','callback',...
  'Resize','off');

uicontrol(f,'style','text','string','Experiment ID','fontsize',gui.fs,'position',[100 700 120 25])
uicontrol(f,'style','text','string','Subject ID','fontsize',gui.fs,'position',[100 660 120 25])
uicontrol(f,'style','text','string','Date/Time','fontsize',gui.fs,'position',[100 620 120 25])
uicontrol(f,'style','text','string','Tester','fontsize',gui.fs,'position',[100 580 120 25])
uicontrol(f,'style','text','string','Comments','fontsize',gui.fs,'position',[100 540 120 25])

uicontrol(f,'style','text','string','Gender','fontsize',gui.fs,'position',[600 660 120 25]);
uicontrol(f,'style','text','string','Birthdate','fontsize',gui.fs,'position',[600 620 120 25]);

gui.txtExperimentID = uicontrol(f,'style','text','fontsize',gui.fs,'position',[220 705 160 25]);%,'backgroundcolor','w');
gui.txtSubjectID = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[220 665 160 25],'backgroundcolor','w');
gui.txtDateTime = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[220 625 160 25],'backgroundcolor','w');
gui.txtTester = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[220 585 160 25],'backgroundcolor','w');
gui.txtComments = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[220 505 320 65],'backgroundcolor','w',...
  'max',2,'horizontalalignment','left');

gui.txtGender = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[720 665 160 25],'backgroundcolor','w');
gui.txtBirthdate = uicontrol(f,'style','edit','fontsize',gui.fs,'position',[720 625 160 25],'backgroundcolor','w');

% Condition Table
gui.tblCondition = uitable(f,'fontsize',gui.fs,'position',[600 450 300 120],...
  'ColumnName',{'Condition Name','Value'},...
  'ColumnEditable',true,...
  'ColumnFormat',{'char','char'},...
  'Data',{'',''},...
  'ColumnWidth',{100 160},...
  'CellSelectionCallback',@tblCondition_select);

uicontrol(f,'style','pushbutton','fontsize',gui.fs,'position',[600 420 140 25],...
  'string','New Condition','callback',@NewCondition);
uicontrol(f,'style','pushbutton','fontsize',gui.fs,'position',[760 420 140 25],...
  'string','Delete Condition','callback',@DeleteCondition);


uicontrol(f,'style','pushbutton','fontsize',gui.fs,'position',[220 280 320 30],...
  'string','Save Changes and Exit','Callback',@SaveAndExit);

%% Populate controls with data from results file
set(gui.txtExperimentID,'string',S.Experiment.Name);
set(gui.txtSubjectID,'string',S.Results.SubjectID);
set(gui.txtDateTime,'string',S.Results.DateTime);
set(gui.txtTester,'string',S.Results.Tester);
set(gui.txtComments,'string',S.Results.Comments);
set(gui.txtGender,'string',S.Results.Gender);
set(gui.txtBirthdate,'string',S.Results.Birthdate);
if ~iscell(S.Results.Condition)
  S.Results.Condition = {'Condition',S.Results.Condition};
end
set(gui.tblCondition,'data',S.Results.Condition);
  

%% SaveSettings: Save Results File
  function SaveAndExit(~, ~)
    % Update S.Results from UI controls
    S.Results.SubjectID = get(gui.txtSubjectID,'string');
    S.Results.DateTime = get(gui.txtDateTime,'string');
    S.Results.Tester = get(gui.txtTester,'string');
    S.Results.Comments = get(gui.txtComments,'string');
    S.Results.Gender = get(gui.txtGender,'string');
    S.Results.Birthdate = get(gui.txtBirthdate,'string');
    S.Results.Condition = get(gui.tblCondition,'data');
    
    % Write S to original file.
    ss = gencode(S);
    
    fid = fopen(SettingsFile,'w');
    fprintf(fid,'%s\n',ss{:});
    fclose(fid);

    delete(f) % Close form
  end

%% LoadSettings: Load Results File
  function LoadSettings(~, ~)
    if exist(SettingsFile,'file')
      fid = fopen(SettingsFile);
      ss = textscan(fid,'%[^\n]');
      ss = ss{1};
      fclose(fid);
      S = [];
      eval(sprintf('%s\n',ss{:}));
    end
    
  end

 %% tblCondition_select
  function tblCondition_select(~, evt)
    % Callback fires when the condition table selection changes
    % Track which row is selected (needed for DeleteCondition)
    if numel(evt.Indices) > 0
      ConditionRow = evt.Indices(1);
    else
      ConditionRow = [];
    end
  end
  
  %% New Condition
  function NewCondition(~, ~)
    % Add a row to the condition table.
    condData = get(gui.tblCondition,'data');
    condRows = size(condData,1);
    condData(condRows+1,:) = {'',''};
    set(gui.tblCondition,'Data',condData);
  end
  
  %% Delete Condition
  function DeleteCondition(~, ~)
    % Delete the selected row from the condition table
    condData = get(gui.tblCondition,'data');
    try
        condData(ConditionRow,:) = []; % Delete a row.  Do nothing if error.
    end
    set(gui.tblCondition,'Data',condData);
  end
  

end % EditResults
