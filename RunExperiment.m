function R = RunExperiment(S)
  % RUNEXPERIMENT - Run Experiment
  %
  % Usage: R = RunExperiment(S)
  %
  % S : settings structure (includes initialized results in S.Results)
  %
  % 2010-07-13 Created by Robert H. Olson, Ph.D., rolson@waisman.wisc.edu
  
  InitializePsychSound;
  
  % Assign initial values
  R = S.Results;
  
  % Define name of diagnostic logfile (written to results directory)
  logfile = fullfile(S.Paths.ResultsPath,[datestr(now(),'yyyy-mm-dd_HHMM') '.log']);
  
  % The results structure has fields:
  %  .SubjectID
  %  .BlockID
  %  .Tester
  %  .DateTime
  %  .Comments
  %  .Trials()
  %           .PhaseName
  %           .ItemName
  %           .Events()
  %                      .EventName
  %                      .StartTime
  %                      .EndTime
  %                      .Location
  %                      .Outcome  = {Success | Failure}
  %           .Responses()
  %                      .Keypress
  %                      .ResponseTime
  %                      .Duration
  %           .Outcome = {Success | Failure}
  
  
  
  % Create a figure (necessary to capture keypresses during run)
  
  gui.xy = getpref('SaffranExperiment','Position'); % Coordinates of lower left corner of figure
  % Main GUI figure
  f = figure('MenuBar', 'None',  ...
    'Name', 'Run Experiment', ...
    'NumberTitle', 'off', 'IntegerHandle', 'off', ...
    'Position',[gui.xy 1000 800], ...
    'Color',get(0,'defaultUIcontrolBackgroundColor'), ...
    'Resize','off',...                                                        % Disallow resizing window
    'KeyPressFcn', @key_press,...
    'KeyReleaseFcn', @key_release,...
    'WindowStyle','modal',...
    'Interruptible','off',...
    'BusyAction','queue',...                     %  could be 'queue' or 'cancel'
    'CloseRequestFcn', @CloseForm); 
  
  % Get the underlying Java reference (Based on code at undocumentedmatlab.com)
%   warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
%   jFig = get(f, 'JavaFrame');
%   jAxis = jFig.getAxisComponent;
  
  % Set the focus event callback
  %set(jAxis,'FocusLostCallback',{@figLostFocus,f});
  %set(jAxis,'FocusGainedCallback',{@figGotFocus,f});
  
  
  gui.fs = 14;
  % Create uicontrols for displaying status information
  gui.txtStatus = uicontrol(f,'style','text','fontsize',gui.fs,'fontweight','bold','position',[20 400 960 30]);

  gui.txtPhase = uicontrol(f,'style','text','fontsize',gui.fs,'fontweight','bold','position',[20 600 960 30]);
  gui.txtTrial = uicontrol(f,'style','text','fontsize',gui.fs,'fontweight','bold','position',[20 560 960 30]);
  gui.txtEvent = uicontrol(f,'style','text','fontsize',gui.fs,'fontweight','bold','position',[20 520 960 30]);
  gui.txtCountdown = uicontrol(f,'style','text','fontsize',gui.fs,'fontweight','bold','position',[20 480 960 30]);
  
  
  % Define some state variables to track stimulus and response records
  TrialNum = 0;
  PhaseTrialNum = 0;
  PhaseName = '';
  REPEATING_TRIAL = false;
  
  ActiveOL = zeros(1,S.OL.NumOL); % State vector for tracking active output locations
  % Increment counter to track users of a given OL to allow possibility of
  % multiple concurrent users of an OL (e.g. Video + Audio or Audio + Audio)
  
  % Create list of valid response keys
  OLkeys = {S.OL.OL.Key};
  otherkeys = cellfun(@(x)S.Keys.(x),fieldnames(S.Keys)','uniformoutput',false);
  validkeys = [OLkeys otherkeys];
  
  % Create abstract list of responses -- Note there are two more symbolic
  % responses: Correct and Incorrect
  %OLsymbols = strcat('OL_',cellstr(num2str((1:length(S.OL.OL))')))';
  OLsymbols = strcat('OL_',{S.OL.OL.Name});
  othersymbols = fieldnames(S.Keys)';
  responsesymbols = [{'Correct' 'Incorrect'} OLsymbols othersymbols];
  
  % Define variable to store key press information
  KeyData = zeros(length(responsesymbols),6);
  % Each row corresponds to a key
  % Columns are:
  %    1: time of last keypress
  %    2: time of last key release
  %    3: accumulated keypress time for the trial
  %    4: state variable (true if pressed)
  %    5: index into response array (needed to correctly store key release)
  %    6: "correct" flag (applies to OL keys)
  
  % Define variable to store random vectors for event output locations
  RandIDs = {};      % vector identifiers    (cell array of strings)
  RandVectors = {};  % vectors               (cell array of vectors)
  
  
  % Define variables to control program flow
  flag_Pause = false;
  flag_EndTrial = false;
  flag_EndPhase = false;
  flag_EndExperiment = false;
  
  
  
  % --- Determine phase sequence ---
  PhaseCount = length(S.Experiment.Phases);
  if strcmpi(S.Experiment.PhaseOrder,'Random')
    PhaseSequence = randperm(PhaseCount);        % Random Phase Order
  else
    PhaseSequence = 1:PhaseCount;                % Sequential Phase Order
  end
  
  m = 0;
  if S.Experiment.ShowInfoSlide, ShowInfoSlide, end
  if S.Experiment.ShowTrialSlide, gui.TrialInfo = ShowTrialSlide(true); end
  
  % --- Run each phase ---
  for m = 1:PhaseCount
    RunPhase(S.Experiment.Phases(PhaseSequence(m)))
    
    if flag_EndExperiment
      break
    end
  end
  
  if S.Experiment.ShowTrialSlide, ShowTrialSlide(false), end
  if S.Experiment.ShowInfoSlide, ShowInfoSlide, end
  
  % it might be a good idea to present some summary information about the
  % experiment before returning to the main program.
  
  
  % Prompt user for comments
  %-------------------------
  % Pre-fill comment box with comments entered before running experiment.
  updatedComment = inputdlg('Enter Experiment Comments','Comments',4,{R.Comments},'on');
  if ~isempty(updatedComment)
    R.Comments = updatedComment{1};
  end
  
  % When all phases have completed, delete the figure
  delete(f)
  
  %% RunPhase
  function RunPhase(phase)
    
    PhaseName = phase.Name;
    PhaseTrialNum = 0; % Reset Phase Trial Number
    set(gui.txtPhase,'string',['Phase: ' PhaseName]);  % Display phase name
    if S.Experiment.ShowTrialSlide
      set(gui.TrialInfo.txtPhase,'string',['Phase: ' PhaseName]);
    end    
    
    % Compute Nominal Trial Sequence
    
    ItemCount = length(phase.Items);
    Reps = phase.Repetitions;
    TrialCount = ItemCount * Reps; % A Trial is an instance of an Item
    
    TrialSequence = zeros(1,TrialCount);
    BlockSequence = ceil((1:TrialCount)/ItemCount);
    
    switch phase.ItemOrder
      case 1 % Sequential
        TrialSequence = repmat(1:ItemCount,1,Reps);
      case 2 % Random with Replacement
        TrialSequence = ceil(rand(1,TrialCount)*ItemCount);
      case 3 % Random without Replacement
        TrialSequence = repmat(1:ItemCount,1,Reps);         % Sequential
        TrialSequence = TrialSequence(randperm(TrialCount)); % Randomly shuffled
      case 4 % Random within Blocks
        for i = 1:Reps
          TrialSequence((i-1)*ItemCount+1:i*ItemCount) = randperm(ItemCount);
        end
      otherwise
        error('RunExperiment: Unexpected value of phase.ItemOrder')
    end
    
    
    
    %-------------------------------------
    % -- Improved Random Event Handling --  START
    %-------------------------------------
    
    % first, identify all events which have an OutputLocationType of Random
    
    % Create a list of RandIDs (used to identify distinct random vectors)
    
    rr = 0;
    RandIDList = {};
    BalanceType = [];
    OLList = {};
    for ii = 1:length(phase.Items)
      for ee = 1:length(phase.Items(ii).Events)
        if phase.Items(ii).Events(ee).OutputLocationType == 2 % Random within Selected
          rr = rr + 1;
          RandID = strtrim(phase.Items(ii).Events(ee).RandID);
          if isempty(RandID)
            % assign a unique ID for future reference
            newID = num2str(fix(rand()*1e6));
            phase.Items(ii).Events(ee).RandID = newID;
            RandIDList{rr} = newID;
          else
            % add the ID to the list (duplicates are ok, for now)
            RandIDList{rr} = RandID;                                                                   
          end
          BalanceType(rr) = phase.Items(ii).Events(ee).RandBalance;
          OLList{rr} = phase.Items(ii).Events(ee).OutputLocation;
        end
      end
    end
    
    [RandIDs,uniqueIdx] = unique(RandIDList); % list of unique IDs
    BalanceType = BalanceType(uniqueIdx);
    RandRange = cellfun(@length,OLList(uniqueIdx));
    
    
    RandIDcount = cellfun(@(x)nnz(strcmp(x,RandIDList)),RandIDs); % Number of occurrences of each ID
    RandVectors = cell(1,length(RandIDs)); % Cell array to store random vectors
    
    for ii = 1:length(RandIDs)
      RandVecLength = RandIDcount(ii) * phase.Repetitions;
      switch BalanceType(ii)
        case 1 % No Balancing
          RandVectors{ii} = ceil(RandRange(ii) * rand(1,RandVecLength));
        case 2 % Balance within Blocks
          for bb = 1:phase.Repetitions
            % Each block should have an even distribution of choices
            rv = repmat(1:RandRange(ii),1,ceil(RandIDcount(ii)/RandRange(ii))); % Create shortest vector with equal distribution
            rv = rv(randperm(length(rv))); % shuffle vector
            RandVectors{ii}(RandIDcount(ii)*(bb-1)+1:RandIDcount(ii)*bb) = rv(1:RandIDcount(ii));
          end
        case 3 % Balance over all Trials (but not necessarily within blocks)
          rv = repmat(1:RandRange(ii),1,ceil(RandVecLength/RandRange(ii)));
          rv = rv(randperm(length(rv)));
          RandVectors{ii} = rv(1:RandVecLength);
      end
    end
    
    %-------------------------------------
    % -- Improved Random Event Handling --  END
    %-------------------------------------
    
    
    % Initialize Countdown display
    switch phase.PhaseEnd
      case 'Fixed'
        set(gui.txtCountdown,'string',[num2str(length(TrialSequence)) ' trials remaining in phase.'])
      case 'Time'
        set(gui.txtCountdown,'string',[num2str(phase.TimeLimit) ' seconds remaining in phase.'])
      case 'Contingent'
        % no countdown display
    end
    
    
    tidx = 1;
    while tidx <= length(TrialSequence)
      REPEATING_TRIAL = BlockSequence(tidx)<=0 || BlockSequence(tidx)~=fix(BlockSequence(tidx));
      
      % Run Trial
      trialSucceeded = RunTrial(phase.Items(TrialSequence(tidx)));
      
      if ~trialSucceeded && fix(BlockSequence(tidx)) % do not repeat if BlockSequence(tidx)==0
        
        if phase.Items(TrialSequence(tidx)).RepeatsAllowed == 1
          % Repeat once
          newblockid = 0;
        else
          % Repeat until successful
          newblockid = -1 * abs(fix(BlockSequence(tidx)));
          
          % Repeated trials in the current block should have a positive blockid (used to identify the end of the block)
          % Repeated trials NOT in current block should have a negative blockid (not used to identify end of the block)
        end
        
        % if repeating the trial is required, handle it here
        switch phase.Items(TrialSequence(tidx)).RepeatOnFail
          case 1 % None
            % no action required
            
          case 2 % Immediate
            % insert after current position
            TrialSequence = insertVec(TrialSequence,TrialSequence(tidx),tidx);
            BlockSequence = insertVec(BlockSequence,newblockid,tidx); % Assign block #0 to repeated trials
            
          case 3 % End of Phase
            TrialSequence = [TrialSequence TrialSequence(tidx)];
            BlockSequence = [BlockSequence newblockid]; 
            
          case 4 % Random within Phase
            % repeated trial should occur in range (after current trial:after last trial)
            r = tidx:length(TrialSequence);
            r = r(ceil(rand()*length(r)));
            TrialSequence = insertVec(TrialSequence,TrialSequence(tidx),r);
            BlockSequence = insertVec(BlockSequence,newblockid,r);
            
          case 5 % End of Block
            % place repeated trial after last trial in current block
            r = find(fix(BlockSequence) == fix(BlockSequence(tidx)),1,'last');
            r = max(r,tidx); % Don't insert before current position
            TrialSequence = insertVec(TrialSequence,TrialSequence(tidx),r);
            BlockSequence = insertVec(BlockSequence,-1*newblockid+0.1,r); 
            
          case 6 % Random within Block
            r = tidx:find(fix(BlockSequence) == fix(BlockSequence(tidx)),1,'last');
            r = r(ceil(rand()*length(r)));
            r = max(r,tidx);
            TrialSequence = insertVec(TrialSequence,TrialSequence(tidx),r);
            BlockSequence = insertVec(BlockSequence,-1*newblockid+0.1,r);
            
        end
      end
      
      
      
      
      % Check to see if phase end condition is satisfied.  If so, set flag_EndPhase to True.
      switch phase.PhaseEnd
        case 'Fixed'
          % update trial countdown
          set(gui.txtCountdown,'string',[num2str(length(TrialSequence)-tidx) ' trials remaining in phase.'])
          
        case 'Time'
          % compare current time to start of phase
          % first identify the first trial in the current phase
          first_trial_idx = find(strcmp(phase.Name,{R.Trials.PhaseName}),1);
          
          phase_duration = etime(clock(),datevec(R.Trials(first_trial_idx).StartTime));
          if phase_duration > phase.TimeLimit
            flag_EndPhase = true;
          end
          
        case 'Contingent'
          % Evaluate contingency expression.
          
          phasetrialsLogical = strcmp(phase.Name,{R.Trials.PhaseName});
          goodtrialsLogical = [R.Trials.Outcome];
          
          if phase.IgnoreFailed
            phasetrials = find(phasetrialsLogical & goodtrialsLogical);
          else
            phasetrials = find(phasetrialsLogical);
          end
          
          trialcount = length(phasetrials);
          
          ontarget = arrayfun(@(x)sum([x.Responses.Correct].*[x.Responses.Duration]),R.Trials(phasetrials));
          
          % Only evaluate condition of required minimum number of trials have run
          if (phase.GroupA == 3 || trialcount >= phase.nA) && (phase.GroupB == 3 || trialcount >= phase.nB)
            
            % Compute expressions A and B (in a loop to avoid repeating code)
            phaseMeasureAB = [phase.MeasureA phase.MeasureB];
            phaseGroupAB = [phase.GroupA phase.GroupB];
            nAB = [phase.nA phase.nB];
            MeasureAB = zeros(1,2);
            
            for zz = 1:2
              switch phaseMeasureAB(zz)
                case 1
                  MeasureFun = @sum;
                case 2
                  MeasureFun = @mean;
              end
              
              switch phaseGroupAB(zz)
                case 1 % First n trials
                  MeasureAB(zz) = MeasureFun(ontarget(1:nAB(zz)));
                case 2 % Last n trials
                  MeasureAB(zz) = MeasureFun(ontarget(end-nAB(zz)+1:end));
                case 3 % All trials
                  MeasureAB(zz) = MeasureFun(ontarget);
              end
            end
            
            % Now put it all together
            switch phase.Operator
              case 1 % >
                PEcondition = MeasureAB(1) + phase.Multiplier * MeasureAB(2) > phase.Scalar;
              case 2 % <
                PEcondition = MeasureAB(1) + phase.Multiplier * MeasureAB(2) < phase.Scalar;
              case 3 % =
                PEcondition = MeasureAB(1) + phase.Multiplier * MeasureAB(2) == phase.Scalar;
            end
            
            % If condition is true, end the phase
            if PEcondition, flag_EndPhase = true; end
          end
          
        otherwise
          % something is wrong
          error('Unexpected value of phase.PhaseEnd')
      end
      
      

      
      if flag_Pause
        flag_Pause = false; % reset flag
        set(gui.txtStatus,'string',' -- Paused:  Press any key to continue --')
        pause
        %ff = msgbox('Press OK to continue...','Paused');
        %uiwait(ff); % wait for a keypress
        set(gui.txtStatus,'string',' ')
      end
      
      if flag_EndPhase
        flag_EndPhase = false; % reset flag
        break % exit for; continue to next phase
      end
      
      tidx = tidx + 1; % increment trial counter
    end % while
    
    
    
  end
  
  %% RunTrial
  function outcome = RunTrial(trial)
    
    % Init new trial
    TrialNum = length(R.Trials) + 1;     % Overall trial number
    PhaseTrialNum = PhaseTrialNum + 1;   % Number of trial within phase
    %set(gui.txtTrial,'string',['Trial ' num2str(PhaseTrialNum) ' : ' trial.Name]); % Display name of trial
    set(gui.txtTrial,'string',['Trial ' num2str(PhaseTrialNum)]); % Display number of trial
    if S.Experiment.ShowTrialSlide
      set(gui.TrialInfo.txtTrial,'string',['Trial ' num2str(PhaseTrialNum)]);
      set(gui.TrialInfo.txtSoundOn,'string',''); % reset at beginning of trial
    end    
    
    R.Trials(TrialNum).PhaseName = PhaseName; % Set in RunPhase
    R.Trials(TrialNum).ItemName = trial.Name;
    R.Trials(TrialNum).StartTime = now();
    R.Trials(TrialNum).Responses = [];
    
    KeyData = zeros(size(KeyData)); % Reset keypress information
    
    % Process events.
    EventCount = length(trial.Events);
    
    % Create State Vectors
    EventStarted = false(1,EventCount);
    EventCompleted = false(1,EventCount);
    EventFailed = false(1,EventCount);
    StopFcns = cell(1,EventCount);

    % Loop while not all events have been completed
    while ~all(EventCompleted)

      pause(0.01)
      
      % If the phase end condition is Time, then update the phase countdown
      phaseidx = find(strcmp(PhaseName,{S.Experiment.Phases.Name}),1);                    % Phase number
      if strcmp(S.Experiment.Phases(phaseidx).PhaseEnd,'Time') 
        trialidx = find(strcmp(PhaseName,{R.Trials.PhaseName}),1);                        % Trial number (in results)
        phase_duration = etime(clock(),datevec(R.Trials(trialidx).StartTime));            % Time since phase began (seconds)
        time_remaining = round(S.Experiment.Phases(phaseidx).TimeLimit - phase_duration); % Time left before limit is reached
        set(gui.txtCountdown,'string',[num2str(time_remaining) ' seconds remaining in phase.']);
      end
      
      % make the "run" figure current so that it can capture keypresses
      figure(f)
      %drawnow % flush event queue (automatically handled by figure())
      
      TestConditions()
      
      if flag_EndTrial
        flag_EndTrial = false; % reset flag
        % Call StopFcn for any running events
        for ix = 1:EventCount
          if EventStarted(ix) && ~EventCompleted(ix)
            feval(StopFcns{ix});
            EventCompleted(ix) = true;
          end
        end
        break % Exit event loop
      end
    end
    
    % Record end of any keys which are still pressed
    for kidx = 1:length(validkeys)
      if KeyData(kidx+2,4)        % If key is pressed...
     
        evtk = [];                % Simulate the key release event object.
        evtk.Key = validkeys(kidx);
      
        key_release([],evtk);     % Run key_release code as though key was released.
      end
    end
    
    % Outcome is success (true) if no event failed
    outcome = ~any(EventFailed);
    R.Trials(TrialNum).Outcome = outcome;
    
    %% TestConditions (event loop)
    function TestConditions()
      
      for i = 1:EventCount
        
        % Test the start condition for ~EventStarted
        if ~EventStarted(i) && ConditionIsSatisfied(i,'start')
          % --- Start Event i ---
          
          R.Trials(TrialNum).Events(i).EventName = trial.Events(i).Name;
          R.Trials(TrialNum).Events(i).StartTime = now();
          
          logwrite(['Starting Event ' trial.Events(i).Name])
          
          if S.Experiment.ShowTrialSlide && S.Experiment.TrialSlideEvents
            set(gui.TrialInfo.txtTrial,'string',['Trial ' num2str(PhaseTrialNum) ' :: ' trial.Events(i).Name]);
          end
          
          if ConditionIsSatisfied(i,'stop')
            % --- Stop Event i (before really starting) ---
            logwrite(['Stopping event ' trial.Events(i).Name])
            % no need to call stop function
            EventCompleted(i) = true;
            R.Trials(TrialNum).Events(i).EndTime = now();
            EventFailed(i) = ConditionIsSatisfied(i,'fail');
            R.Trials(TrialNum).Events(i).Outcome = EventFailed(i);
            
            if ConditionIsSatisfied(i,'stoptrial')
              flag_EndTrial = true;
            end
          else
            % Really start event
            
            % Determine OL
            switch trial.Events(i).OutputLocationType
              case 1 % All selected
                OL = trial.Events(i).OutputLocation;
              case 2 % Random within selected
                
                % If the current trial is a repeat (from a Repeat On Failure) then randomly select an output location.
                % Otherwise, use balanced random vector.
                
                if REPEATING_TRIAL
                  n_sel = length(trial.Events(i).OutputLocation);
                  OL = trial.Events(i).OutputLocation(ceil(n_sel * rand(1)));  % Starting in R2008b, could use randi(n_sel)
                else
                  % New Random Selection Code:
                  rv = strcmp(trial.Events(i).RandID,RandIDs); % index of the random vector for this event
                  vp = find(RandVectors{rv},1);                % position of the first non-zero element in the random vector
                  % Use the random vector to choose one of the selected output locations.
                  % The "min" is used to prevent "index out of bounds" errors
                  OL = trial.Events(i).OutputLocation(min(RandVectors{rv}(vp),length(trial.Events(i).OutputLocation)));
                  RandVectors{rv}(vp) = 0; % set the used value to 0 so find( ,1) finds the next element
                end
                
              case 3 % Match Event
                relatedEventID = find(strcmp(trial.Events(i).RelatedEvent,{R.Trials(TrialNum).Events.EventName}));
                if any(relatedEventID)
                  OL = R.Trials(TrialNum).Events(relatedEventID).Location;
                else
                  error('Related Event was not found in RunExperiment\TestConditions')
                end
            end
            R.Trials(TrialNum).Events(i).Location = OL;
            
            CBdata.TrialID = TrialNum;
            CBdata.EventID = i;
            CBdata.OL = OL;
            
            % Mark output locations as active (increment counter)
            ActiveOL(OL) = ActiveOL(OL) + 1;
            
            % Test filename to see if audio (.wav) or video file
            if regexpi(trial.Events(i).StimulusFilename,'\.wav') % If filename ends in .wav ...
              % Audio
              if S.Experiment.ShowTrialSlide, set(gui.TrialInfo.txtSoundOn,'string','Sound On'); end
              if S.OL.UsePsychPortAudio
                StopFcns{i} = PlayAudio(S.OL, OL, trial.Events(i).StimulusFilename, @EndEvent, CBdata, trial.Events(i).Loop);
              else
                %disp('PlayAudio2')
                if ~isfield(trial.Events(i),'Loop'), trial.Events(i).Loop = 0; end
                StopFcns{i} = PlayAudio2(S.OL, OL, trial.Events(i).StimulusFilename, @EndEvent, CBdata, trial.Events(i).Loop);
              end
            elseif regexpi(trial.Events(i).StimulusFilename,'\.bmp|\.gif|\.jpg|\.jpeg|\.png')
              % Image
              StopFcns{i} = PlayImage(S.OL, OL, trial.Events(i).StimulusFilename, @EndEvent, CBdata);
            else
              % Video
              %disp('PlayVideo')
              if ~isfield(trial.Events(i),'Loop'), trial.Events(i).Loop = 0; end
              StopFcns{i} = PlayVideo(S.OL, OL, trial.Events(i).StimulusFilename, @EndEvent, CBdata, trial.Events(i).Loop);
            end
            
            EventStarted(i) = true;
          end
        end
        
        % Test the stop condition for EventStarted & ~EventCompleted
        if EventStarted(i) && ~EventCompleted(i) 
          if ConditionIsSatisfied(i,'stop')
            % --- Stop Event i ---
            
            logwrite(['Stopping Event ' trial.Events(i).Name])
            
            % Call stop function
            feval(StopFcns{i});
            
            EventCompleted(i) = true;
          end
          if ConditionIsSatisfied(i,'stoptrial')
            flag_EndTrial = true;
          end
        end
      end
      
    end
    
    %% EndEvent - callback which fires at end of event
    function EndEvent(event_args)
      
      % event_args must include trial index and event index
      t_id = event_args.TrialID;
      e_id = event_args.EventID;
      ol_id = event_args.OL;
      
      % Set Events.EndTime to now()
      R.Trials(t_id).Events(e_id).EndTime = now();
      
      % Mark event as completed
      EventCompleted(e_id) = true;
      
      % Mark output locations as inactive (decrement counter)
      ActiveOL(ol_id) = ActiveOL(ol_id) - 1;
      
      % Test fail condition
      EventFailed(e_id) = ConditionIsSatisfied(e_id,'fail');
      
      % Store event outcome in results set
      R.Trials(t_id).Events(e_id).Outcome = EventFailed(e_id);
      
    end
    
    %% ConditionIsSatisfied - Test start, stop, and failure conditions
    function [ConditionValue] = ConditionIsSatisfied(evtidx,ConditionType)
      % Have access to "trial" from parent function.
      % Have access to "R" from grandparent
      
      switch ConditionType
        case 'start'
          sc = trial.Events(evtidx).StartCondition;
        case 'stop'
          sc = trial.Events(evtidx).StopCondition;
        case 'fail'
          sc = trial.Events(evtidx).FailCondition;
        case 'stoptrial'
          if isfield(trial.Events(evtidx),'StopTrialCondition')
            sc = trial.Events(evtidx).StopTrialCondition;
          else
            sc = '';
          end
        otherwise
          error('Unexpected ConditionType in RunExperiment/ConditionIsSatisfied')
      end
      
      logwrite(['   Testing condition ' ConditionType ' for event ' sprintf('%d',evtidx) ' : ' sc])
      
      % Empty conditions should evaluate as false
      if isempty(deblank(sc))
        sc = '0';
      end
      
      %disp(['Testing Condition ' sc ' for eventidx = ' num2str(evtidx)])
      
      ConditionValue = false; % Default
      
      
      % Extract expression labels from Condition string (e1, e2, etc...)
      exprLabels = regexp(sc,'e\d+','match');
      % Extract numeric parts of labels
      exprID = str2double(cellfun(@(x)x(2:end),exprLabels,'UniformOutput',false));
      
      % Now try to interpret and evaluate the identified expressions
      
      % Expression Key:
      %
      % ExpressionID
      % ObjectA - name of the object (event, key, trial) cell array of strings
      % ObjectB
      % EventTypeA  - index into G.EventTypes
      % EventOperator - index into G.Operators
      % Multiplier - scalar
      % EventTypeB - index into G.EventTypes
      % RelOperator - index into G.Comparison
      % EventScalar - scalar
      
      % Note that the interpretation of ObjectA/B depends on EventTypeA/B
      
      exprValue = false(1,length(exprID)); % array to store expression values
      
      for k = 1:length(exprID)
        expidx = find(trial.Events(evtidx).ExpressionID==exprID(k));
        
        if isempty(expidx)
          error('Expression ID not found in RunExperiment/ConditionIsSatisfied.  Verify that the expression exists.')
        end
        
        % Copy expression to local variables for convenience
        ObjectAB = cell(2);
        ObjectAB{1} = trial.Events(evtidx).ObjectA{expidx};
        ObjectAB{2} = trial.Events(evtidx).ObjectB{expidx};
        EventTypeAB(1) = trial.Events(evtidx).EventTypeA(expidx);
        EventTypeAB(2) = trial.Events(evtidx).EventTypeB(expidx);
        EventOperator = trial.Events(evtidx).EventOperator(expidx);
        Multiplier = trial.Events(evtidx).Multiplier(expidx);
        RelOperator = trial.Events(evtidx).RelOperator(expidx);
        EventScalar = trial.Events(evtidx).EventScalar(expidx);
        
        
        % Form of relation is:
        % expr(1) (opr) scalar x expr(2) (relopr) scalar
        expr=NaN(1,2);
        for q=1:2 % evaluate expr(q)
          % Evaluate object expressions (all units are seconds)
          switch EventTypeAB(q)
            case 1 % trial.StartTime: Time since trial(x) began
              
              if R.Trials(TrialNum).StartTime > 0
                expr(q) = etime(clock(),datevec(R.Trials(TrialNum).StartTime));
              end
              
            case 2 % event.StartTime: Time since event(x) began

              objidx = find(strcmp(ObjectAB{q},{R.Trials(TrialNum).Events.EventName})); % Index of event
              if any(objidx) && R.Trials(TrialNum).Events(objidx).StartTime > 0
                expr(q) = etime(clock(),datevec(R.Trials(TrialNum).Events(objidx).StartTime));
              end
              
            case 3 % event.StopTime: Time since event(x) stopped

              objidx = find(strcmp(ObjectAB{q},{R.Trials(TrialNum).Events.EventName})); % Index of event
              if any(objidx) && EventCompleted(objidx)
                expr(q) = etime(clock(),datevec(R.Trials(TrialNum).Events(objidx).EndTime));
              end
              
            case 4 % key.PressTime: Time since key(x) was last pressed
              
              objidx = find(strcmp(ObjectAB{q},responsesymbols)); % Find index of key
              if any(objidx) && KeyData(objidx,1) > 0
                expr(q) = etime(clock(),datevec(KeyData(objidx,1)));
              end
              
            case 5 % key.Duration: Duration of last keypress of key(x)
              
              objidx = find(strcmp(ObjectAB{q},responsesymbols)); % Find index of key
              if any(objidx) && KeyData(objidx,1) > 0
                if KeyData(objidx,4) % key is pressed
                  expr(q) = etime(clock(),datevec(KeyData(objidx,1))); % length of ongoing keypress
                else
                  expr(q) = etime(datevec(KeyData(objidx,2)),datevec(KeyData(objidx,1))); % length of last keypress
                end
              end
              
            case 6 % key.TrialDuration: Accumulated keypress time for the trial
              
              objidx = find(strcmp(ObjectAB{q},responsesymbols)); % Find index of key
              if any(objidx)
                if KeyData(objidx,4) % key is pressed
                  expr(q) = etime(clock(),datevec(KeyData(objidx,1))) + KeyData(objidx,3); % length of ongoing keypress + accumulated time
                else
                  expr(q) = KeyData(objidx,3); % accumulated time (could be 0)
                end
              end
              
            case 7 % key.ReleaseTime: Time elapsed since key(x) was last released
              
              objidx = find(strcmp(ObjectAB{q},responsesymbols)); % Find index of key
              if any(objidx) && KeyData(objidx,2) > 0 
                expr(q) = etime(clock(),datevec(KeyData(objidx,2)));
              end
              
              if KeyData(objidx,4) % Key is pressed
                expr(q) = 0;
              end
              
            otherwise
              error('Unexpected value of EventTypeAB(q) in RunExperiment/ConditionIsSatisfied')
          end
          
          logwrite(['       e' sprintf('%d',expidx) '.' sprintf('%d',q) ' = ' num2str(expr(q))])
          
        end
        
        
        if Multiplier == 0          % Since invalid expressions are set to NaN, must 
          expr(2) = 0;              % set value to a real number so that 0*NaN doesn't 
        end                         % invalidate an otherwise reasonable expression.
        
        % G.Operators = {' +' ' -' ' *' ' /'};
        % G.Comparison = {' >' ' <' ' ='};
        switch EventOperator
          case 1 % +
            lefthandside = expr(1) + (Multiplier * expr(2));
          case 2 % -
            lefthandside = expr(1) - (Multiplier * expr(2));
          case 3 % *
            lefthandside = expr(1) * (Multiplier * expr(2));
          case 4 % /
            lefthandside = expr(1) / (Multiplier * expr(2));
          otherwise
            error('Unexpected value for EventOperator in RunExperiment/ConditionIsSatisfied')
        end
        
        switch RelOperator
          case 1 % >
            exprValue(k) = lefthandside > EventScalar;
          case 2 % <
            exprValue(k) = lefthandside < EventScalar;
          case 3 % ==
            exprValue(k) = lefthandside == EventScalar;
          otherwise
            error('Unexpected value for RelOperator in RunExperiment/ConditionIsSatisfied')
        end
      end
      
      % Now all expressions have been evaluated.  Insert into condition
      % string, and evaluate that.
      
      % Must perform substitution in descending numerical order (so that
      % there is no false match for e1 in e10, for example)
      
      for k = length(exprID):-1:1
        sc = regexprep(sc,exprLabels{k},num2str(exprValue(k)));
      end
      
      logwrite(['   After substitution, sc = ' sc])
      
      % Now evaluate the condition
      ConditionValue = eval(sc);
      
      % DEBUG
      %fprintf(1,' Condition: %s evaluates to %d\n',sc,ConditionValue)
      
    end % ConditionIsSatisfied
  end % RunTrial
  
  %% key_press - capture key press events
  function key_press(obj, events)
    logwrite(['Keypress: ' events.Key])
    
    % Handle flow control keys
    switch events.Key
      case S.Keys.Pause
        flag_Pause = true;
        %return
      case S.Keys.EndTrial
        flag_EndTrial = true;
        %return
      case S.Keys.EndPhase
        flag_EndPhase = true;
        flag_EndTrial = true;
        %return
      case S.Keys.EndExperiment
        flag_EndExperiment = true;
        flag_EndPhase = true;
        flag_EndTrial = true;
        %return
    end
    
    % Check to see if key is tracked
    keyidx = find(strcmp(events.Key,validkeys));
    if any(keyidx)
      keyidx = keyidx + 2; % offset to find corresponding response symbol
      
      % Check to see if key is already pressed; if so, do nothing.
      % Apparently, calls to figure() result in a new key_press event even
      % if the figure already has the focus
      if KeyData(keyidx,4)
        %disp('Key is already pressed')
        return
      end
      
      % Set time of key press
      KeyData(keyidx,1) = now();
      % Set state of key
      KeyData(keyidx,4) = true; % Key is pressed
      
      % Create new Response
      ResponseNum = length(R.Trials(TrialNum).Responses) + 1;
      % Store ResponseNum
      KeyData(keyidx,5) = ResponseNum;
      
      R.Trials(TrialNum).Responses(ResponseNum).Keypress = events.Key;
      R.Trials(TrialNum).Responses(ResponseNum).SymbolicKey = responsesymbols{keyidx};
      R.Trials(TrialNum).Responses(ResponseNum).PressTime = now();
      %R.Trials(TrialNum).Responses(ResponseNum).Correct = 0; % Default to incorrect (Would [] be better?)


      % Is this an OL-type response?
      if keyidx - 2 <= S.OL.NumOL
        % Is the response correct (correspond to current output)?
        if ActiveOL(keyidx - 2) > 0
          KeyData(keyidx,6) = true; % Correct
          R.Trials(TrialNum).Responses(ResponseNum).Correct = 1;
          
          % Update "Correct" virtual key with keypress time
          KeyData(1,1) = KeyData(keyidx,1);
          KeyData(1,4) = true;  % virtual "correct" key is pressed
        else
          KeyData(keyidx,6) = false; % Incorrect
          R.Trials(TrialNum).Responses(ResponseNum).Correct = 0;
          
          % Update "Incorrect" virtual key with keypress time
          KeyData(2,1) = KeyData(keyidx,1);
          KeyData(2,4) = true;  % virtual "incorrect" key is pressed
          
        end
      else
        % Non-OL keys should be coded as incorrect to avoid breaking
        % "Contingent" phase end condition code.
        R.Trials(TrialNum).Responses(ResponseNum).Correct = 0;
      end
      
    end
  end
  
  %% key_release - capture key release events
  function key_release(obj, events)

    % Check to see if key is tracked
    keyidx = find(strcmp(events.Key,validkeys));
    if any(keyidx)
      keyidx = keyidx + 2; % offset to account for virtual responses: {'Correct' 'Incorrect'}
      
      % If the key was pressed before the start of the trial, ignore the keypress
      if KeyData(keyidx,5) == 0
        % The key was pressed before the start of the trial -- there is no associated response
        return
      end
      
      % Set time of key release
      KeyData(keyidx,2) = now();
      % Update accumulated keypress time with duration of this keypress
      keyduration = etime(datevec(KeyData(keyidx,2)),datevec(KeyData(keyidx,1)));
      KeyData(keyidx,3) = KeyData(keyidx,3) + keyduration;
      % Set state of key
      KeyData(keyidx,4) = false; % Key is not pressed
      
      % Update Response
      ResponseNum = KeyData(keyidx, 5); % was stored in key press event
      try
      R.Trials(TrialNum).Responses(ResponseNum).ReleaseTime = KeyData(keyidx,2);
      catch ME
        disp(ME.message)
        keyboard
      end
      R.Trials(TrialNum).Responses(ResponseNum).Duration = keyduration;
      
      % Update virtual key based on "correct" KeyData field
      if KeyData(keyidx,6) % if Correct...
        KeyData(1,2) = KeyData(keyidx,2);             % key release time
        KeyData(1,3) = KeyData(1,3) + keyduration;    % accumulated time
        KeyData(1,4) = false;                         % key not pressed
      else % Incorrect
        KeyData(2,2) = KeyData(keyidx,2);
        KeyData(2,3) = KeyData(2,3) + keyduration;
        KeyData(2,4) = false;
      end
    end
  end
  
  %% logwrite - write a line to the logfile
  function logwrite(s)
    return % turn off logging
    fid = fopen(logfile,'a');
    if fid > 0
      if ischar(s),fprintf(fid,'%s\n',s);end
    end
    fclose(fid);
  end
  
  
  %% figLostFocus - Callback for figure losing focus
  function figLostFocus(jAxis, jEventData, hFig)   
    if ishandle(hFig) % if the figure handle is valid (i.e., figure has not closed)

      figure(hFig)    % then make the figure active --> restore focus
      tic;disp('tic')
      drawnow;
      toc
    end
    
  end
  %% figGotFocus - Callback for figure losing focus
  function figGotFocus(jAxis, jEventData, hFig)
  end
  
  %% Close Form
  function CloseForm(obj, evt)
    %End the experiment
    flag_EndExperiment = true;
    flag_EndPhase = true;
    flag_EndTrial = true;
    
    if m==0, delete(f), end; % Allows for a graceful exit if something goes wrong before the experiment starts.
  end
  
  %% Show Info Slide
  function ShowInfoSlide()
    % Display information about a particular experiment run.
    % - Experiment Name
    % - Condition
    % - Subject Number
    % - Date
    
    % Create a figure and use proportional scaling to use the space

    % Determine the coordinates of the figure from the OL    
    OLcoords = S.OL.OL(S.Experiment.InfoSlideOL).DisplayCoords;
    
    mp = get(0,'monitorposition'); % Get position of monitors
    
    % If fullscreen, get the coordinates of the screen
    if S.OL.OL(S.Experiment.InfoSlideOL).Fullscreen
      mpidx = mp(:,1)<=OLcoords(1) & mp(:,2)<=OLcoords(2) & mp(:,3)>=OLcoords(3) & mp(:,4)>=OLcoords(4);
      OLcoords = mp(mpidx,:);
    end
    
    % OLcoords have format [x1 y1 x2 y2] measured from upper left corner of primary screen.
    % Position has format [x y w h], where x and y are measured from lower left corner of primary screen.
    figpos = [OLcoords(1) mp(1,4)-OLcoords(4)+1 OLcoords(3)-OLcoords(1)+1 OLcoords(4)-OLcoords(2)+1];
    
    if iscell(S.Results.Condition)
        if size(S.Results.Condition,1) > 0
            ConditionToShow = S.Results.Condition{1,2};
        else
            ConditionToShow = '';
        end
    else
        ConditionToShow = S.Results.Condition;
    end
    
    infoslidefig = figure('position',figpos,'menubar','none','Name','Information');
    uicontrol(infoslidefig,'style','text','units','normalized','position',[0 0.75 1 0.25],'string',S.Experiment.Name,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
    uicontrol(infoslidefig,'style','text','units','normalized','position',[0 0.50 1 0.25],'string',ConditionToShow,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
    uicontrol(infoslidefig,'style','text','units','normalized','position',[0 0.25 1 0.25],'string',S.Results.SubjectID,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
    uicontrol(infoslidefig,'style','text','units','normalized','position',[0 0.00 1 0.25],'string',S.Results.DateTime,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
    
    % If fullscreen, maximize the window using undocumented feature.
    % See http://undocumentedmatlab.com/blog/minimize-maximize-figure-window/
    if S.OL.OL(S.Experiment.InfoSlideOL).Fullscreen
        drawnow;
        pause(.1);
        jFrame = get(handle(infoslidefig),'JavaFrame');
        jFrame.setMaximized(true);
    end
    
    % Close the figure after 2 seconds
    pause(2)
    delete(infoslidefig);
  end


  %% Control display of trial information slide
  function TrialInfo = ShowTrialSlide(displaySlide)
    if displaySlide
      % Create Trial Information figure

      % Determine the coordinates of the figure from the OL
      OLcoords = S.OL.OL(S.Experiment.TrialSlideOL).DisplayCoords;
      
      mp = get(0,'monitorposition'); % Get position of monitors
      
      % If fullscreen, get the coordinates of the screen
      if S.OL.OL(S.Experiment.TrialSlideOL).Fullscreen
        mpidx = mp(:,1)<=OLcoords(1) & mp(:,2)<=OLcoords(2) & mp(:,3)>=OLcoords(3) & mp(:,4)>=OLcoords(4);
        OLcoords = mp(mpidx,:);
      end
      
      % OLcoords have format [x1 y1 x2 y2] measured from upper left corner of primary screen.
      % Position has format [x y w h], where x and y are measured from lower left corner of primary screen.
      figpos = [OLcoords(1) mp(1,4)-OLcoords(4)+1 OLcoords(3)-OLcoords(1)+1 OLcoords(4)-OLcoords(2)+1];

      TrialInfo.f = figure('position',figpos,'menubar','none','Name','Trial Information');
      
      uicontrol(TrialInfo.f,'style','text','units','normalized','position',[0 0.80 1 0.20],'string',S.Experiment.Name,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
      uicontrol(TrialInfo.f,'style','text','units','normalized','position',[0 0.60 1 0.20],'string',S.Results.SubjectID,'fontunits','normalized','fontsize',.5,'backgroundcolor','w');
      TrialInfo.txtPhase = uicontrol(TrialInfo.f,'style','text','units','normalized','position',[0 0.40 1 0.20],'string','Phase Name','fontunits','normalized','fontsize',.5,'backgroundcolor','w');
      TrialInfo.txtTrial = uicontrol(TrialInfo.f,'style','text','units','normalized','position',[0 0.20 1 0.20],'string','Subject ID','fontunits','normalized','fontsize',.5,'backgroundcolor','w');
      TrialInfo.txtSoundOn = uicontrol(TrialInfo.f,'style','text','units','normalized','position',[0 0.00 1 0.20],'string','Sound On','fontunits','normalized','fontsize',.5,'backgroundcolor','w');
      
      % If fullscreen, maximize the window using undocumented feature.  
      % See http://undocumentedmatlab.com/blog/minimize-maximize-figure-window/
      if S.OL.OL(S.Experiment.TrialSlideOL).Fullscreen
          drawnow;
          pause(.1);
          jFrame = get(handle(TrialInfo.f),'JavaFrame');
          jFrame.setMaximized(true);
      end
      
    else
      % Delete Trial Information figure
      delete(gui.TrialInfo.f)
    end
  end
    
end % RunExperiment

%% INS - insert a vector into another vector at a specified position
function result = insertVec(A,B,pos)
  result = [A(1:pos) B A(pos+1:end)];
end

