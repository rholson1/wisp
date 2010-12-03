function ProcessResultsGUI(searchdir)
  % PROCESSRESULTSGUI - Display a graphical interface to ProcessResults function.
  
  % Create figure
  gui.fs = 10; % font size for UI elements
  gui.xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure
  
  OutputFormats = ProcessResults(); % Run ProcessResults without any arguments to get a list of valid formats
  
  f = figure('Name', 'Process Results', ...
    'Visible', 'on', ...
    'NumberTitle', 'off', ...
    'IntegerHandle', 'off', ...
    'Resize', 'off', ...
    'MenuBar','none', ...
    'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
    'WindowStyle','modal',...
    'Position',[gui.xy+[200 300] 260 300]);
  
  % Add controls
  uicontrol(f,'style','pushbutton','fontsize',gui.fs,'string','Select Files','position',[50 260 160 30],'callback',@btnSelect_press);
  uicontrol(f,'style','text','fontsize',gui.fs,'string','Results Files:','position',[10 225 100 25]);
  gui.lstResultFiles = uicontrol(f,'style','listbox','fontsize',gui.fs,'backgroundcolor','w','position',[30 140 200 90]);
  
  uicontrol(f,'style','text','fontsize',gui.fs,'string','Output Format:','position',[10 100 100 25]);
  gui.cboOutputFormat = uicontrol(f,'style','popupmenu','fontsize',gui.fs,'string',OutputFormats,'position',[30 80 200 25],'backgroundcolor','w');
  gui.chkCombine = uicontrol(f,'style','checkbox','fontsize',gui.fs,'string','Combine Results','position',[70 50 160 25]);
  uicontrol(f,'style','pushbutton','fontsize',gui.fs,'string','Process Files','position',[50 10 160 30],'callback',@btnProcess_press);
  
  
  %% Select Files Button
  function btnSelect_press(obj, events)
    [fname,pname] = uigetfile({'*.txt','Results Files (*.txt)'},'Select results files',searchdir,'multiselect','on');
    if ~isequal(fname,0)
      set(gui.lstResultFiles,'string',strcat(pname,fname));
    end
  end
  
  %% Process Results Button
  function btnProcess_press(obj, events)
    
    % Verify that files have been selected
    fnames = get(gui.lstResultFiles,'string');
    if isempty(fnames)
      msgbox({'No files have been selected!' 'Select files, and try again'},'Process Results')
      return
    end
    
    outputformat = OutputFormats{get(gui.cboOutputFormat,'value')};
    
    if get(gui.chkCombine,'value')
      batchmode = 'group';
    else
      batchmode = 'single';
    end
    
    % Process Files
    ProcessResults(fnames,outputformat,batchmode);
    msgbox('Processing is complete!','Process Results')
    close(f);
  end
  
  
end % ProcessResultsGUI