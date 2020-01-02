function OUTPUT_FORMATS = ProcessResults(fnames, outputformat, batchmode)
  % PROCESSRESULTS - Process results files into analysis file formats.
  %
  % Usage:
  %
  %  ProcessResults(fnames, outputformat, batchmode)
  %    fnames       : results filename or cell array of filenames
  %    outputformat : indicator of type of output file to create
  %                     'format1'
  %                     'headturn'
  %                      ... (TBD)
  %    batchmode    : control whether results are consolidated into a single output file
  %                     'single' - process file-by-file (default)
  %                     'group'  - consolidate results into a single file
  %
  %
  % 2010-08-26 : Created by Robert H. Olson, Ph.D., rolson@waisman.wisc.edu
  
  %% Validate Arguments

  % Make sure outputformat is one of the defined formats
  OUTPUT_FORMATS = {'Format 1' 'Headturn' 'Headturn2' 'Headturn3' 'Habituation' 'Headturn Reliability'};
  if nargin == 0
    return
  end
  
  OFidx = strcmpi(outputformat,OUTPUT_FORMATS);
  if ~any(OFidx)
    OFidx = 1;
    warning('ProcessResults:invalidOutputFormat','Output format %s is invalid; format %s will be used instead.',outputformat,OUTPUT_FORMATS{OFidx});
  end
  
  % fnames is a cell array of strings or a string.
  % If a single string, put in a cell for consistency.
  if ~iscell(fnames)
    fnames = {fnames};
  end
  


  
  % Make sure that batchmode is valid
  BATCH_MODES = {'single' 'group'};
  if nargin < 3
    batchmode = 'single'; % default
  end
  BMidx = strcmpi(batchmode, BATCH_MODES);
  if ~any(BMidx)
    BMidx = 1;
    warning('ProcessResults:invalidBatchMode','Batch mode %s is invalid; mode %s will be used instead.',batchmode,BATCH_MODES{BMidx});
  end
  
  %% Determine output file permissions
  group_output = strcmpi(BATCH_MODES{BMidx},'group'); 
  if group_output
    filepermission = 'a'; % create or append
  else
    filepermission = 'w+'; % create or overwrite
  end
  
  %% Process Files
  
  write_header = true; % only write header once for combined output file
  
  for fileidx = 1:length(fnames)
    fname = fnames{fileidx};
    
    % Read file and evaluate to create structure S
    S = [];
    
    [fid, msg] = fopen(fname,'r');
    if fid < 0
      warning('ProcessResults:fileOpenFailed','Unable to open file %s : %s',fname,msg);
      continue % skip to next file
    end    
    
    ss = textscan(fid,'%[^\n]');
    ss = ss{1};
    fclose(fid);
    eval(sprintf('%s\n',ss{:}));
    
    
    % Process file into suitable form
    switch find(OFidx)
      case 1
        [headers, data, datafmt] = createOutput_format1(S);
      case 2
        [headers, data, datafmt] = createOutput_headturn(S);
      case 3
        [headers, data, datafmt] = createOutput_headturn2(S);
       case 4
        [headers, data, datafmt] = createOutput_headturn3(S);
      case 5
        [headers, data, datafmt] = createOutput_habituation(S); 
      case 6
        [headers, data, datafmt] = createOutput_headturnreliability(S);
      otherwise
        fprintf(1,'find(OFidx) = '), disp(find(OFidx))
        error('ProcessResults:unexpectedValue','find(OFidx) has an unexpected value.')
    end
    
    % Generate a filename based on the old filename and the output format.
    [fppath, fpname] = fileparts(fname);
    if strcmpi(BATCH_MODES{BMidx},'group')
      outputfilename = fullfile(fppath,[datestr(now(),'YYYY-mm-dd') '_Combined_Results_' OUTPUT_FORMATS{OFidx} '.txt']);
    else
      outputfilename = fullfile(fppath,[fpname '_' OUTPUT_FORMATS{OFidx} '.txt']);
    end
    
    % Open file for output
    [ofid, msg] = fopen(outputfilename,filepermission);
    if ofid < 0
      warning('ProcessResults:fileOpenFailed','Unable to open file %s : %s',outputfilename,msg);
      continue % skip to next file
    end
    
    % Write header
    if write_header
      fprintf(ofid,'%s\n',headers);
      if strcmpi(BATCH_MODES{BMidx},'group'), write_header = false; end
    end
    
    % Write output
    fprintf(ofid,datafmt,data{:});
    
    % Close file
    fclose(ofid);
    
  end
end
%% Process results to create output
% createOutput_xxx functions take a results structure and provide three outputs:
%  headers : Delimited header line; will be printed as the first line of the output file.
%  data    : 2-d cell array containing data.  Rows of "data" correspond to columns in the output file.
%  datafmt : format specification string used in writing output: fprintf(fid, datafmt, data{:}).  

function [headers, data, datafmt] = createOutput_format1(S)
  
  
  % Format: one row per event (9 + 2(number of OLs) columns
  % Columns:
  %  1 Experiment ID
  %  2 Subject ID
  %  3 Date/Time
  %  4 Phase
  %  5 Trial
  %  6 Event Name
  %  7 Event Number (this is a little bit ambiguous...)
  %  8 Event Filename
  %  9 Output Location(s)
  %  10, 12, ... OLn Key Count (Number of keypresses during event)
  %  11, 13, ... OLn Key Time  (Total keydown time during event)
  % 
  %
  %  -- Optional Fields --
  %  Gender
  %  Birthdate
  %  List
  %  Condition_1
  %  Condition_2
  %  Condition_3
  
  col_count = 9 + 2*S.OL.NumOL;
  
  
  headers = [sprintf('ExpID\tSubjectID\tDateTime\tPhase\tTrial\tEventName\tEventNo\tEventFile\tOutputLocation\t') ...
    sprintf('OL_%d_Count\tOL_%d_Duration\t',[(1:S.OL.NumOL)' (1:S.OL.NumOL)']')];
  
  datafmt = [repmat('%s\t',1,9) repmat('%d\t%f\t',1,S.OL.NumOL) '\n'];
  
  
  event_ctr = 0;
  
  % Loop over events in S.Results
  
  % First count the events...
  for t = 1:length(S.Results.Trials)
    for evt = 1:length(S.Results.Trials(t).Events)
      event_ctr = event_ctr + 1;
    end
  end
  
  % Create cell array to store results
  data = cell(event_ctr,col_count);
  
  event_ctr = 0;
  for t = 1:length(S.Results.Trials)
    PhaseNumber = find(strcmp(S.Results.Trials(t).PhaseName,{S.Experiment.Phases.Name}),1);
    ItemNumber = find(strcmp(S.Results.Trials(t).ItemName,{S.Experiment.Phases(PhaseNumber).Items.Name}),1);
    
    % Replace empty values of PressTime and ReleaseTime with NaN.
    % This eases filtering of Responses by time.
    empty_press = cellfun('isempty',{S.Results.Trials(t).Responses.PressTime});
    empty_release = cellfun('isempty',{S.Results.Trials(t).Responses.ReleaseTime});
    [S.Results.Trials(t).Responses(empty_press).PressTime] = deal(nan);
    [S.Results.Trials(t).Responses(empty_release).ReleaseTime] = deal(nan);
    
    for evt = 1:length(S.Results.Trials(t).Events)
      event_ctr = event_ctr + 1;
      data{event_ctr,1} = S.Experiment.Name; 
      data{event_ctr,2} = S.Results.SubjectID;
      data{event_ctr,3} = S.Results.DateTime;
      data{event_ctr,4} = S.Results.Trials(t).PhaseName;
      data{event_ctr,5} = S.Results.Trials(t).ItemName;
      data{event_ctr,6} = S.Results.Trials(t).Events(evt).EventName;
      
      EventNumber = find(strcmp(data{event_ctr,6},{S.Experiment.Phases(PhaseNumber).Items(ItemNumber).Events.Name}),1);
      
      data{event_ctr,7} = num2str(EventNumber);
      data{event_ctr,8} = S.Experiment.Phases(PhaseNumber).Items(ItemNumber).Events(EventNumber).StimulusFilename;
      data{event_ctr,9} = num2str(S.Results.Trials(t).Events(evt).Location);
      
      % Response Summary: Count, Duration for each OL key
      for k = 1:S.OL.NumOL
        
        % look for responses where the keypress matches the keypress defined for the k_th OL
        ol_Responses = strcmp(S.OL.OL(k).Key,{S.Results.Trials(t).Responses.Keypress});            % length = # Responses
        
        % Count keypresses with a PressTime between the start and end times of the event
        ol_PressTime = [S.Results.Trials(t).Responses(ol_Responses).PressTime];                    % length = # Responses of current OL
        ol_ReleaseTime = [S.Results.Trials(t).Responses(ol_Responses).ReleaseTime];
        ol_Duration = [S.Results.Trials(t).Responses(ol_Responses).Duration];
        
        
        % Simple approach:  count only keypresses which begin during an event.  
        k_dur = (ol_PressTime > S.Results.Trials(t).Events(evt).StartTime) & ...                   % length = # Responses of current OL
          (ol_PressTime < S.Results.Trials(t).Events(evt).EndTime) & ...
          ~isnan(ol_ReleaseTime); % (and which have a defined release time)
        
        data{event_ctr,8+2*k} = nnz(k_dur);              % Count
        data{event_ctr,9+2*k} = sum(ol_Duration(k_dur)); % Duration
        
      end
      
    end
  end
  
  data = data';
end % createOutput

function [headers, data, datafmt] = createOutput_headturn(S)
  
  % Headturn Experiment Output Filter
  
  % -- Existing Headturn Output Format --
  % Column 1: experiment number (it always says 1, so we can just get rid of this column)
  % Column 2: trial #
  % Column 3: Block #
  % Column 4: Test item #
  % Column 5: Target side (0 = right; 1 = left)
  % Column 6: Total attention time (i.e., time the baby spends looking directly at the side-light minus the 
  %           time the baby looked away). This is the main column we use for data analysis.
  % Column 7: Number of aways lasting < 2 seconds 
  %             0 = the baby never looked away and the trial ended because it maxed out at 15 seconds
  %             1 = the baby turned away once but looked back soon enough that the sound continued playing; 
  %             2 = the baby turned away twice...
  %             etc...
  % Column 8: Test item # (not sure why this column repeats itself - we should just get rid of it)
  % Column 9: Total time the side light blinks *before* the baby turns to look at it (sound does not play during this time)
  % Column 10: Total time the side light blinks *after* the baby turns to look at it (i.e., total time the sound plays regardless of whether the baby is looking)
  
  % -- New Headturn Output Format --
  % Column 1: trial # (1:n)
  % Column 2: Block # (corresponds to phase)
  % Column 3: Item # (placement of item within phase, prior to randomization, etc)
  % Column 4: OL
  % Column 5: Sum of "Correct" for the trial
  % Column 6: Number of "Correct" keypresses - 1
  % Column 7: Time before first "Correct" keypress and after the previous incorrect keypress
  % Column 8: Time after first "Correct" keypress
  
  
  % New columns (12-15-2010):
  % Column 9: Experiment Name (Protocol)
  % Column 10: Subject ID
  % Column 11: Tester
  % Column 12: Gender
  % Column 13: Age at testing (days)
  % Column 14: Comments
  % Column 15-: Condition(s)
  
  % Updates: 1/31/2011
  % Number trials within phase
  % Add column for block number (also numbered within phase?)
  
  % Compute age at testing (in days) outside of the trial loop for efficiency
  if isempty(S.Results.Birthdate) || isempty(S.Results.DateTime)
    AgeInDays = 0;
  else
    AgeInDays = fix(datenum(S.Results.DateTime) - datenum(S.Results.Birthdate));
  end
  
  % Put conditions in a standard format {'Cond. Name 1' 'Condition 1';...}
  if ~iscell(S.Results.Condition)
      S.Results.Condition = {'Condition' S.Results.Condition};
  end
  ConditionCount = size(S.Results.Condition,1); % Number of rows in condition cell array
  
  headers = sprintf(['Trial\tPhase\tItem\tLocation\tBlock\tLooking Time (ms)\tLooks Away\tPreLook (ms)\tPostLook (ms)' ...
      '\tProtocol\tSubject ID\tTester\tGender\tAge (days)\tComments' sprintf('\\t%s',S.Results.Condition{:,1})]);
 
  datafmt = [repmat('%d\t',1,9) repmat('%s\t',1,4) '%d\t' repmat('%s\t',1,1+ConditionCount) '\n'];
  
  nt = length(S.Results.Trials); % Number of trials
  
  data = cell(nt,15+ConditionCount); % Initialize data cell array
  
  % Loop over trials, completing one row in data array per trial
  for t = 1:nt
    PhaseNumber = find(strcmp(S.Results.Trials(t).PhaseName,{S.Experiment.Phases.Name}),1);
    ItemNumber = find(strcmp(S.Results.Trials(t).ItemName,{S.Experiment.Phases(PhaseNumber).Items.Name}),1);
    
    %data{t,1} = t;
    data{t,2} = PhaseNumber;
    data{t,1} = nnz(PhaseNumber == [data{1:t,2}]); % Number trials within each phase
    data{t,3} = ItemNumber; 
    
    ItemsInPhase = length(S.Experiment.Phases(PhaseNumber).Items);
    data{t,5} = ceil(data{t,1}/ItemsInPhase);   % Compute block based on number of items in phase
    
    if length(S.Results.Trials(t).Events) > 1
      data{t,4} = S.Results.Trials(t).Events(2).Location; % The second event is the right or left light, by convention
    else
      continue
    end
    
    if ~isfield(S.Results.Trials(t).Responses,'Correct')
      S.Results.Trials(t).Responses.Correct = 0;
    end
    
    correct_responses = logical([S.Results.Trials(t).Responses.Correct]);
    
    if any(correct_responses)
      data{t,6} = fix(sum([S.Results.Trials(t).Responses(correct_responses).Duration])*1000); % Sum, convert from s to ms  
      data{t,7} = max(nnz(correct_responses)-1, 0); % Number of breaks between correct responses (at least 0)
      
      % Time between end of first event and start of first correct keypress
      firsteventend = S.Results.Trials(t).Events(1).EndTime;
      firstcorrect = S.Results.Trials(t).Responses(find(correct_responses,1)).PressTime;
      data{t,8} = fix(etime(datevec(firstcorrect),datevec(firsteventend)) * 1000);
      
      % Time between first correct keypress and end of second event
      secondeventend = S.Results.Trials(t).Events(2).EndTime;
      data{t,9} = fix(etime(datevec(secondeventend),datevec(firstcorrect)) * 1000);
    else
      data(t,6:9) = {0 0 0 0}; % If no correct responses, set everything to 0
    end
    
    data{t,10} = S.Experiment.Name;
    data{t,11} = S.Results.SubjectID;
    data{t,12} = S.Results.Tester;
    data{t,13} = S.Results.Gender;
    data{t,14} = AgeInDays;
    data{t,15} = S.Results.Comments'; 
    %data{t,16} = S.Audio;
    
    data(t,16:15+ConditionCount) = S.Results.Condition(:,2)';
  end

  data = data';
  
end % createOutput_headturn


function [headers, data, datafmt] = createOutput_headturn2(S)
  
  % Headturn Experiment Output Filter
  
  % -- Existing Headturn Output Format --
  % Column 1: experiment number (it always says 1, so we can just get rid of this column)
  % Column 2: trial #
  % Column 3: Block #
  % Column 4: Test item #
  % Column 5: Target side (0 = right; 1 = left)
  % Column 6: Total attention time (i.e., time the baby spends looking directly at the side-light minus the 
  %           time the baby looked away). This is the main column we use for data analysis.
  % Column 7: Number of aways lasting < 2 seconds 
  %             0 = the baby never looked away and the trial ended because it maxed out at 15 seconds
  %             1 = the baby turned away once but looked back soon enough that the sound continued playing; 
  %             2 = the baby turned away twice...
  %             etc...
  % Column 8: Test item # (not sure why this column repeats itself - we should just get rid of it)
  % Column 9: Total time the side light blinks *before* the baby turns to look at it (sound does not play during this time)
  % Column 10: Total time the side light blinks *after* the baby turns to look at it (i.e., total time the sound plays regardless of whether the baby is looking)
  
  % -- New Headturn Output Format --
  % Column 1: trial # (1:n)
  % Column 2: Block # (corresponds to phase)
  % Column 3: Item # (placement of item within phase, prior to randomization, etc)
  % Column 4: OL
  % Column 5: Sum of "Correct" for the trial
  % Column 6: Number of "Correct" keypresses - 1
  % Column 7: Time before first "Correct" keypress and after the previous incorrect keypress
  % Column 8: Time after first "Correct" keypress
  
  
  % New columns (12-15-2010):
  % Column 9: Experiment Name (Protocol)
  % Column 10: Subject ID
  % Column 11: Tester
  % Column 12: Gender
  % Column 13: Age at testing (days)
  % Column 14: Comments
  % Column 15-: Condition(s)
  
  % Updates: 1/31/2011
  % Number trials within phase
  % Add column for block number (also numbered within phase?)
  
  % Updates: 2/28/2012 (create Headturn2 as a copy of Headturn)
  % Replace Item Number with Item Name (Column 3)
  % Get Output Location from Event 3 rather than Event 2
  
  % Updates: 11/12/2019 (Martin Zettersten)
  % change line "if length(S.Results.Trials(t).Events) > 1" to if
  % "length(S.Results.Trials(t).Events) > 2" to accommodate attention
  % getters/ different trial types during headturn blocks
  
  % Compute age at testing (in days) outside of the trial loop for efficiency
  if isempty(S.Results.Birthdate) || isempty(S.Results.DateTime)
    AgeInDays = 0;
  else
    AgeInDays = fix(datenum(S.Results.DateTime) - datenum(S.Results.Birthdate));
  end
  
  % Put conditions in a standard format {'Cond. Name 1' 'Condition 1';...}
  if ~iscell(S.Results.Condition)
      S.Results.Condition = {'Condition' S.Results.Condition};
  end
  ConditionCount = size(S.Results.Condition,1); % Number of rows in condition cell array
  
  headers = sprintf(['Trial\tPhase\tItem\tLocation\tBlock\tLooking Time (ms)\tLooks Away\tPreLook (ms)\tPostLook (ms)' ...
      '\tProtocol\tSubject ID\tTester\tGender\tAge (days)\tComments' sprintf('\\t%s',S.Results.Condition{:,1})]);
 
  datafmt = ['%d\t%d\t%s\t' repmat('%d\t',1,6) repmat('%s\t',1,4) '%d\t' repmat('%s\t',1,1+ConditionCount) '\n'];
  
  nt = length(S.Results.Trials); % Number of trials
  
  data = cell(nt,15+ConditionCount); % Initialize data cell array
  
  % Loop over trials, completing one row in data array per trial
  for t = 1:nt
    PhaseNumber = find(strcmp(S.Results.Trials(t).PhaseName,{S.Experiment.Phases.Name}),1);
    %ItemNumber = find(strcmp(S.Results.Trials(t).ItemName,{S.Experiment.Phases(PhaseNumber).Items.Name}),1);
    
    %data{t,1} = t;
    data{t,2} = PhaseNumber;
    data{t,1} = nnz(PhaseNumber == [data{1:t,2}]); % Number trials within each phase
    data{t,3} = S.Results.Trials(t).ItemName; %ItemNumber; 
    
    ItemsInPhase = length(S.Experiment.Phases(PhaseNumber).Items);
    data{t,5} = ceil(data{t,1}/ItemsInPhase);   % Compute block based on number of items in phase
    
    %if length(S.Results.Trials(t).Events) > 1
    if length(S.Results.Trials(t).Events) > 2
      data{t,4} = S.Results.Trials(t).Events(3).Location; % The third event supplies the Output Location here.
    else
      continue
    end
    
    if ~isfield(S.Results.Trials(t).Responses,'Correct')
      S.Results.Trials(t).Responses.Correct = 0;
    end
    
    correct_responses = logical([S.Results.Trials(t).Responses.Correct]);
    
    if any(correct_responses)
      data{t,6} = fix(sum([S.Results.Trials(t).Responses(correct_responses).Duration])*1000); % Sum, convert from s to ms  
      data{t,7} = max(nnz(correct_responses)-1, 0); % Number of breaks between correct responses (at least 0)
      
      % Time between end of first event and start of first correct keypress
      firsteventend = S.Results.Trials(t).Events(1).EndTime;
      firstcorrect = S.Results.Trials(t).Responses(find(correct_responses,1)).PressTime;
      data{t,8} = fix(etime(datevec(firstcorrect),datevec(firsteventend)) * 1000);
      
      % Time between first correct keypress and end of second event
      secondeventend = S.Results.Trials(t).Events(2).EndTime;
      data{t,9} = fix(etime(datevec(secondeventend),datevec(firstcorrect)) * 1000);
    else
      data(t,6:9) = {0 0 0 0}; % If no correct responses, set everything to 0
    end
    
    data{t,10} = S.Experiment.Name;
    data{t,11} = S.Results.SubjectID;
    data{t,12} = S.Results.Tester;
    data{t,13} = S.Results.Gender;
    data{t,14} = AgeInDays;
    data{t,15} = S.Results.Comments'; 
    
    data(t,16:15+ConditionCount) = S.Results.Condition(:,2)';
  end

  data = data';
  
end % createOutput_headturn2

function [headers, data, datafmt] = createOutput_headturnreliability(S)
  
  % Headturn Reliability Output Filter
  % filter each response and tally the total duration recorded for right
  % (numpad6) and left (numpad4) looks
  %
  % -- Output Format --
  % Column 1: response # / keypress #
  % Column 2: timestamp from moment key was pressed
  % Column 3: the key that was pressed
  % Column 4: duration of the keypress (in s)
  % Column 5: Experiment Name (Protocol)
  % Column 6: Subject ID
  % Column 7: Tester
  % Column 8: total accumulated keypress time for numpad4 (left looking)
  % Column 9: total accumulated keypress time for numpad6 (right looking)
  headers = sprintf(['ResponseNumber\tPressTime\tKey\tLooking Time (ms)\tProtocol\tSubject ID\tTester\ttotalLeftDuration\ttotalRightDuration']);
 
  datafmt = ['%d\t%.8f\t%s\t%f\t%s\t%s\t%s\t%f\t%f\t\n'];
  
  nt = length(S.Results.Trials.Responses); % Number of responses
  
  data = cell(nt,7); % Initialize data cell array
  
  totalNumpad6Duration = 0; %tracks total duration of pressing numpad 6
  totalNumpad4Duration = 0; %tracks total duration of pressing numpad 6
  
  % Loop over responses, completing one row in data array per response
  for t = 1:nt
    data{t,1} = t;
    data{t,2} = S.Results.Trials.Responses(t).PressTime
    data{t,3} = S.Results.Trials.Responses(t).Keypress
    data{t,4} = S.Results.Trials.Responses(t).Duration
    data{t,5} = S.Experiment.Name;
    data{t,6} = S.Results.SubjectID;
    data{t,7} = S.Results.Tester;
    if S.Results.Trials.Responses(t).Keypress == 'numpad4'
        totalNumpad4Duration = totalNumpad4Duration + S.Results.Trials.Responses(t).Duration;
    elseif S.Results.Trials.Responses(t).Keypress == 'numpad6'
        totalNumpad6Duration = totalNumpad6Duration + S.Results.Trials.Responses(t).Duration;
    end
        
  end
  
  data(:,8) = {totalNumpad4Duration};
  data(:,9) = {totalNumpad6Duration};

  data = data';
  
end % createOutput_headturnreliability


function [headers, data, datafmt] = createOutput_headturn3(S)
  
  % Headturn Experiment Output Filter
  
  % -- Existing Headturn Output Format --
  % Column 1: experiment number (it always says 1, so we can just get rid of this column)
  % Column 2: trial #
  % Column 3: Block #
  % Column 4: Test item #
  % Column 5: Target side (0 = right; 1 = left)
  % Column 6: Total attention time (i.e., time the baby spends looking directly at the side-light minus the 
  %           time the baby looked away). This is the main column we use for data analysis.
  % Column 7: Number of aways lasting < 2 seconds 
  %             0 = the baby never looked away and the trial ended because it maxed out at 15 seconds
  %             1 = the baby turned away once but looked back soon enough that the sound continued playing; 
  %             2 = the baby turned away twice...
  %             etc...
  % Column 8: Test item # (not sure why this column repeats itself - we should just get rid of it)
  % Column 9: Total time the side light blinks *before* the baby turns to look at it (sound does not play during this time)
  % Column 10: Total time the side light blinks *after* the baby turns to look at it (i.e., total time the sound plays regardless of whether the baby is looking)
  
  % -- New Headturn Output Format --
  % Column 1: trial # (1:n)
  % Column 2: Block # (corresponds to phase)
  % Column 3: Item # (placement of item within phase, prior to randomization, etc)
  % Column 4: OL
  % Column 5: Sum of "Correct" for the trial
  % Column 6: Number of "Correct" keypresses - 1
  % Column 7: Time before first "Correct" keypress and after the previous incorrect keypress
  % Column 8: Time after first "Correct" keypress
  
  
  % New columns (12-15-2010):
  % Column 9: Experiment Name (Protocol)
  % Column 10: Subject ID
  % Column 11: Tester
  % Column 12: Gender
  % Column 13: Age at testing (days)
  % Column 14: Comments
  % Column 15-: Condition(s)
  
  % Updates: 1/31/2011
  % Number trials within phase
  % Add column for block number (also numbered within phase?)
  %
  % 2/20/2017
  % Insert column before Protocol with stimulus filename
  
  % Updates: 11/12/2019 (Martin Zettersten)
  % change line "if length(S.Results.Trials(t).Events) > 1" to if
  % "length(S.Results.Trials(t).Events) > 2" to accommodate attention
  % getters/ different trial types during headturn blocks
  
  % Compute age at testing (in days) outside of the trial loop for efficiency
  if isempty(S.Results.Birthdate) || isempty(S.Results.DateTime)
    AgeInDays = 0;
  else
    AgeInDays = fix(datenum(S.Results.DateTime) - datenum(S.Results.Birthdate));
  end
  
  % Put conditions in a standard format {'Cond. Name 1' 'Condition 1';...}
  if ~iscell(S.Results.Condition)
      S.Results.Condition = {'Condition' S.Results.Condition};
  end
  ConditionCount = size(S.Results.Condition,1); % Number of rows in condition cell array
  
  headers = sprintf(['Trial\tPhase\tItem\tLocation\tBlock\tLooking Time (ms)\tLooks Away\tPreLook (ms)\tPostLook (ms)' ...
      '\tSoundFile\tProtocol\tSubject ID\tTester\tGender\tAge (days)\tComments' sprintf('\\t%s',S.Results.Condition{:,1})]);
 
  datafmt = [repmat('%d\t',1,9) repmat('%s\t',1,5) '%d\t' repmat('%s\t',1,1+ConditionCount) '\n'];
  
  nt = length(S.Results.Trials); % Number of trials
  
  data = cell(nt,16+ConditionCount); % Initialize data cell array
  
  % Loop over trials, completing one row in data array per trial
  for t = 1:nt
    PhaseNumber = find(strcmp(S.Results.Trials(t).PhaseName,{S.Experiment.Phases.Name}),1);
    ItemNumber = find(strcmp(S.Results.Trials(t).ItemName,{S.Experiment.Phases(PhaseNumber).Items.Name}),1);
    
    %data{t,1} = t;
    data{t,2} = PhaseNumber;
    data{t,1} = nnz(PhaseNumber == [data{1:t,2}]); % Number trials within each phase
    data{t,3} = ItemNumber; 
    
    ItemsInPhase = length(S.Experiment.Phases(PhaseNumber).Items);
    data{t,5} = ceil(data{t,1}/ItemsInPhase);   % Compute block based on number of items in phase
    
    %if length(S.Results.Trials(t).Events) > 1
    if length(S.Results.Trials(t).Events) > 2 
      data{t,4} = S.Results.Trials(t).Events(2).Location; % The second event is the right or left light, by convention
    else
      continue
    end
    
    if ~isfield(S.Results.Trials(t).Responses,'Correct')
      S.Results.Trials(t).Responses.Correct = 0;
    end
    
    correct_responses = logical([S.Results.Trials(t).Responses.Correct]);
    
    if any(correct_responses)
      data{t,6} = fix(sum([S.Results.Trials(t).Responses(correct_responses).Duration])*1000); % Sum, convert from s to ms  
      data{t,7} = max(nnz(correct_responses)-1, 0); % Number of breaks between correct responses (at least 0)
      
      % Time between end of first event and start of first correct keypress
      firsteventend = S.Results.Trials(t).Events(1).EndTime;
      firstcorrect = S.Results.Trials(t).Responses(find(correct_responses,1)).PressTime;
      data{t,8} = fix(etime(datevec(firstcorrect),datevec(firsteventend)) * 1000);
      
      % Time between first correct keypress and end of second event
      secondeventend = S.Results.Trials(t).Events(2).EndTime;
      data{t,9} = fix(etime(datevec(secondeventend),datevec(firstcorrect)) * 1000);
    else
      data(t,6:9) = {0 0 0 0}; % If no correct responses, set everything to 0
    end
    
    if length(S.Experiment.Phases(PhaseNumber).Items(ItemNumber).Events) >= 3;
      data{t,10} = S.Experiment.Phases(PhaseNumber).Items(ItemNumber).Events(3).StimulusFilename;
    else
       data{t,10} = '-';
    end
    data{t,11} = S.Experiment.Name;
    data{t,12} = S.Results.SubjectID;
    data{t,13} = S.Results.Tester;
    data{t,14} = S.Results.Gender;
    data{t,15} = AgeInDays;
    data{t,16} = S.Results.Comments'; 
    
    data(t,17:16+ConditionCount) = S.Results.Condition(:,2)';
  end

  data = data';
  
end % createOutput_headturn3



function [headers, data, datafmt] = createOutput_habituation(S)
  
  % Headturn Experiment Output Filter
  
  % -- Existing Headturn Output Format --
  % Column 1: experiment number (it always says 1, so we can just get rid of this column)
  % Column 2: trial #
  % Column 3: Block #
  % Column 4: Test item #
  % Column 5: Target side (0 = right; 1 = left)
  % Column 6: Total attention time (i.e., time the baby spends looking directly at the side-light minus the 
  %           time the baby looked away). This is the main column we use for data analysis.
  % Column 7: Number of aways lasting < 2 seconds 
  %             0 = the baby never looked away and the trial ended because it maxed out at 15 seconds
  %             1 = the baby turned away once but looked back soon enough that the sound continued playing; 
  %             2 = the baby turned away twice...
  %             etc...
  % Column 8: Test item # (not sure why this column repeats itself - we should just get rid of it)
  % Column 9: Total time the side light blinks *before* the baby turns to look at it (sound does not play during this time)
  % Column 10: Total time the side light blinks *after* the baby turns to look at it (i.e., total time the sound plays regardless of whether the baby is looking)
  
  % -- New Headturn Output Format --
  % Column 1: trial # (1:n)
  % Column 2: Block # (corresponds to phase)
  % Column 3: Item # (placement of item within phase, prior to randomization, etc)
  % Column 4: OL
  % Column 5: Sum of "Correct" for the trial
  % Column 6: Number of "Correct" keypresses - 1
  % Column 7: Time before first "Correct" keypress and after the previous incorrect keypress
  % Column 8: Time after first "Correct" keypress
  
  
  % New columns (12-15-2010):
  % Column 9: Experiment Name (Protocol)
  % Column 10: Subject ID
  % Column 11: Tester
  % Column 12: Gender
  % Column 13: Age at testing (days)
  % Column 14: Comments
  % Column 15-: Condition(s)
  
  % Updates: 1/31/2011
  % Number trials within phase
  % Add column for block number (also numbered within phase?)
  
  % Updates: 2/28/2012 (create Headturn2 as a copy of Headturn)
  % Replace Item Number with Item Name (Column 3)
  % Get Output Location from Event 3 rather than Event 2
  
  % Updates: 12/12/2012 (create Habituation as a copy of Headturn2)
  % Rename column "Looking Time" to "UncorrectedLook"
  % Add column "CorrectedLook" = sum of on-target looks after end of event 1  
  % Add column "FirstThree" = sum of CorrectedLook for first three trials
  % Add column "LastThree" = sum of CorrectedLook for last three trials of
  % first phase.
  % Remove spaces and punctuation from column names.
  
  % Updates: 8/27/2013 (edit Habituation)
  % Insert new column "TrialsToHabituation" at column 13
  
  % Compute age at testing (in days) outside of the trial loop for efficiency
  if isempty(S.Results.Birthdate) || isempty(S.Results.DateTime)
    AgeInDays = 0;
  else
    AgeInDays = fix(datenum(S.Results.DateTime) - datenum(S.Results.Birthdate));
  end
  
  % Put conditions in a standard format {'Cond. Name 1' 'Condition 1';...}
  if ~iscell(S.Results.Condition)
      S.Results.Condition = {'Condition' S.Results.Condition};
  end
  ConditionCount = size(S.Results.Condition,1); % Number of rows in condition cell array
  
  headers = sprintf(['Trial\tPhase\tItem\tLocation\tBlock\tUncorrectedLook\tCorrectedLook\tLooksAway\tPreLook\tPostLook\tFirstThree\tLastThree' ...
      '\tTrialsToHabituation' ...
      '\tProtocol\tSubjectID\tTester\tGender\tAge\tComments' sprintf('\\t%s',S.Results.Condition{:,1})]);
 
  datafmt = ['%d\t%d\t%s\t' repmat('%d\t',1,9) '%d\t' repmat('%s\t',1,4) '%d\t' repmat('%s\t',1,1+ConditionCount) '\n'];
  
  nt = length(S.Results.Trials); % Number of trials
  
  data = cell(nt,19+ConditionCount); % Initialize data cell array
  
  % Loop over trials, completing one row in data array per trial
  for t = 1:nt
    PhaseNumber = find(strcmp(S.Results.Trials(t).PhaseName,{S.Experiment.Phases.Name}),1);
    %ItemNumber = find(strcmp(S.Results.Trials(t).ItemName,{S.Experiment.Phases(PhaseNumber).Items.Name}),1);
    
    %data{t,1} = t;
    data{t,2} = PhaseNumber;
    data{t,1} = nnz(PhaseNumber == [data{1:t,2}]); % Number trials within each phase
    data{t,3} = S.Results.Trials(t).ItemName; %ItemNumber; 
    
    ItemsInPhase = length(S.Experiment.Phases(PhaseNumber).Items);
    data{t,5} = ceil(data{t,1}/ItemsInPhase);   % Compute block based on number of items in phase
    
    if length(S.Results.Trials(t).Events) > 2
      data{t,4} = S.Results.Trials(t).Events(3).Location; % The third event supplies the Output Location here.
    else
      continue
    end
    
    if ~isfield(S.Results.Trials(t).Responses,'Correct')
      S.Results.Trials(t).Responses.Correct = 0;
    end
    
    correct_responses = logical([S.Results.Trials(t).Responses.Correct]);
    valid_responses = [S.Results.Trials(t).Responses.PressTime] > S.Results.Trials(t).Events(1).EndTime;
    corrected_responses = correct_responses & valid_responses;
    
    if any(correct_responses)
      % UncorrectedLook
      data{t,6} = fix(sum([S.Results.Trials(t).Responses(correct_responses).Duration])*1000); % Sum, convert from s to ms  
      % CorrectedLook
      data{t,7} = fix(sum([S.Results.Trials(t).Responses(corrected_responses).Duration])*1000); % Sum, convert from s to ms  
      
      data{t,8} = max(nnz(correct_responses)-1, 0); % Number of breaks between correct responses (at least 0)
      
      % Time between end of first event and start of first correct keypress
      firsteventend = S.Results.Trials(t).Events(1).EndTime;
      firstcorrect = S.Results.Trials(t).Responses(find(correct_responses,1)).PressTime;
      data{t,9} = fix(etime(datevec(firstcorrect),datevec(firsteventend)) * 1000);
      
      % Time between first correct keypress and end of second event
      secondeventend = S.Results.Trials(t).Events(2).EndTime;
      data{t,10} = fix(etime(datevec(secondeventend),datevec(firstcorrect)) * 1000);
    else
      data(t,6:10) = {0 0 0 0 0}; % If no correct responses, set everything to 0
    end
    
    data{t,14} = S.Experiment.Name;
    data{t,15} = S.Results.SubjectID;
    data{t,16} = S.Results.Tester;
    data{t,17} = S.Results.Gender;
    data{t,18} = AgeInDays;
    data{t,19} = S.Results.Comments'; 
    
    data(t,20:19+ConditionCount) = S.Results.Condition(:,2)';
  end
  
  % Add columns for sum of Corrected look for first three and last three
  % trials in the first phase.
  phase1trials = [data{:,2}] == 1;
  first3 = find(phase1trials, 3);
  last3 = find(phase1trials, 3, 'last');
  trials_to_habituation = nnz(phase1trials);
  
  data(:,11) = num2cell(sum([data{first3,7}]) * ones(nt,1)); % sum of first three corrected looks
  data(:,12) = num2cell(sum([data{last3,7}]) * ones(nt,1)); % sum of last three corrected looks in phase 1
  data(:,13) = num2cell(trials_to_habituation * ones(nt,1)); % number of trials in the first (habituation) phase
  
  data = data';
  
end % createOutput_headturn2
