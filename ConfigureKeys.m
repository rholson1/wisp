function K = ConfigureKeys(K_init)
% CONIFGUREKEYS - Assign keys to several functions
%
% 2010-06-30 Created by Robert H. Olson, Ph.D., rolson@waisman.wisc.edu


gui.fs = 10; % font size for UI elements
gui.xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure

f = figure('Name', 'Configure Keys', ...
  'Visible', 'on', ...
  'NumberTitle', 'off', ...
  'IntegerHandle', 'off', ...
  'Resize', 'off', ...
  'MenuBar','none', ...
  'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
  'WindowStyle','modal',...
  'Position',[gui.xy+[200 300] 300 200]);

KeyList = {'End Trial' 'End Phase' 'End Experiment' 'Pause'};
KeyFieldList = regexprep(KeyList,'\ ','');
nK = length(KeyList); % Number of keys

% Set initial values of the keys
if nargin == 0
  for i = 1:nK
    K.(KeyFieldList{i}) = '';
  end
else
  K = K_init;
end

uicontrol('style','text','fontsize',gui.fs,'position',[10 160 280 25],...
  'string','Assign keys to actions');

gui.txt = zeros(1,nK); % textbox handles
for i = 1:nK
  uicontrol('style','text','string',KeyList{i},'fontsize',gui.fs,'position',[10 30+30*(nK-i) 120 25])
  gui.txt(i) = uicontrol('style','edit','fontsize',gui.fs,'backgroundcolor','w',...
    'position',[130 35+30*(nK-i) 120 25],'tag',num2str(i),...
    'keypressfcn',@txtKeyPress,'string',K.(KeyFieldList{i}));
end

% Do not return until figure closes
uiwait(f)
%% Subfunctions and Callbacks

%% txtKeyPress - Callback for keypresses on text boxes
  function txtKeyPress(obj, events)
    idx = str2double(get(obj, 'tag'));
    set(obj,'string',events.Key);
    K.(KeyFieldList{idx}) = get(gui.txt(idx),'string');
    
  end

end % ConfigureKeys