function stopfcn = PlayImage(C,OL,ImageFileName, Callback, CallbackArg)
  % PLAYIMAGE - Display an image at a specified output location.
  %
  % PlayImage(C,OL,VideoFileName)
  % PlayImage(C,OL,VideoFileName,Callback,CallbackArg)
  %
  % C  : Hardware configuration structure (see ConfigureHardware)
  % OL : Output Location number
  % ImageFileName : Full filename of the video to be played
  % Callback : handle to a function to be executed at the end of playback
  % CallbackArg : argument to callback function
  %
  % Dependencies : Psychtoolbox
  % See Also ConfigureHardware, PlayAudio, PlayVideo
  %
  % 2010-09-02 : Created by Robert H. Olson, Ph.D. rolson@waisman.wisc.edu
  
  
  RUNCALLBACK = (nargin == 5); % Check to see if callback was supplied
  frame_java = []; % Initialize variable to set proper scope
  
  [z,z,fileext] = fileparts(ImageFileName);
  
  
  ISBMP = strcmpi(fileext,'.bmp');

  if ISBMP
    img = ImageFileName;
  else
    img = imread(ImageFileName);   % Read image file
  end
  
  mp = OldStyleMonitorPositions(1); % Get monitor positions (necessary to relate OL position to screen ID)
  
  % Check to see if ImageDisplayMode has been set.  If not, use default.
  if ~isfield(C,'ImageDisplayMode'), C.ImageDisplayMode=1; end
  
  for OLidx = 1:length(OL)
    % Must convert OL to a display number
    c = C.OL(OL(OLidx)).DisplayCoords;
    c(3:4) = c(3:4)-c(1:2)+[1 1];
    
    screen_num = find(c(1)<=mp(:,3)&c(1)>=mp(:,1)&c(2)<=mp(:,4)&c(2)>=mp(:,2));
    if isempty(screen_num)
      error('PlayImage:invalidOL','Output Location is not bounded by MonitorPosition')
    end
    
    isfullscreen = C.OL(OL(OLidx)).Fullscreen;
    fullscreen(img,screen_num,isfullscreen,c);           % Prepare image for display
  end
  
  for fjidx = 1:length(frame_java)        % Reveal image
    frame_java{fjidx}.show
  end
  
  
  stopfcn = @StopImage;         % Set output to handle of StopImage function
  
  %% Close image and perform cleanup
  function StopImage()
    closescreen()
    if RUNCALLBACK
      Callback(CallbackArg)
    end
  end
  
  %% Display image fullscreen (obtained from Mathworks File Exchange)
  function fullscreen(image,device_number,isfullscreen,pos)
    %FULLSCREEN Display fullscreen true colour images
    %   FULLSCREEN(C,N) displays matlab image matrix C on display number N
    %   (which ranges from 1 to number of screens). Image matrix C must be
    %   the exact resolution of the output screen since no scaling in
    %   implemented. If fullscreen is activated on the same display
    %   as the MATLAB window, use ALT-TAB to switch back.
    %
    %   If FULLSCREEN(C,N) is called the second time, the screen will update
    %   with the new image.
    %
    %   Use CLOSESCREEN() to exit fullscreen.
    %
    %   Requires Matlab 7.x (uses Java Virtual Machine), and has been tested on
    %   Linux and Windows platforms.
    %
    %   Written by Pithawat Vachiramon
    %
    %   Update (23/3/09):
    %   - Uses temporary bitmap file to speed up drawing process.
    %   - Implemeted a fix by Alejandro Camara Iglesias to solve issue with
    %   non-exclusive-fullscreen-capable screens.
    
    
    if isempty(frame_java)
      fj_idx = 1;
    else
      fj_idx = length(frame_java) + 1;
    end
    
    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    gds = ge.getScreenDevices();
    screenheight = gds(device_number).getDisplayMode().getHeight();
    screenwidth = gds(device_number).getDisplayMode().getWidth();
    
    if ISBMP
      bmpfilename = image;
    else
      bmpfilename = [tempdir 'display.bmp'];
      
      try
        imwrite(image,bmpfilename);
      catch
        error('Image must be compatible with imwrite()');
      end
    end
    
    buff_image = javax.imageio.ImageIO.read(java.io.File(bmpfilename));
    
    old_w = buff_image.getWidth();
    old_h = buff_image.getHeight();
    

    if ~isequal(class(frame_java), 'javax.swing.JFrame')
      frame_java{fj_idx} = javax.swing.JWindow(gds(device_number).getDefaultConfiguration());
      %frame_java{fj_idx} = javax.swing.JFrame(gds(device_number).getDefaultConfiguration());
      %frame_java{fj_idx}.setUndecorated(true);

      % Compute new width/height for scaling transformation
      if isfullscreen
        new_w = screenwidth;
        new_h = screenheight;
      else
        new_w = pos(3);
        new_h = pos(4);
      end

      % Determine scale factors based on Image Display Mode
      switch C.ImageDisplayMode
        case 1 % Center
          w_scale = 1;
          h_scale = 1;
        case 2 % Fit
          w_scale = min(new_w/old_w, new_h/old_h);
          h_scale = w_scale;
        case 3 % Stretch
          w_scale = new_w/old_w;
          h_scale = new_h/old_h;
      end
      
      % Compute translation to center image (for Center and Fit modes)
      tx = (new_w - w_scale * old_w)/2;
      ty = (new_h - h_scale * old_h)/2;

      % Create affine transformation
      affineTrans = java.awt.geom.AffineTransform();
      affineTrans.translate(tx, ty);
      affineTrans.scale(w_scale, h_scale);
      
      % Transform image
      scaleOp = java.awt.image.AffineTransformOp(affineTrans,java.awt.image.AffineTransformOp.TYPE_BILINEAR);
      sized_image = java.awt.image.BufferedImage(new_w,new_h,buff_image.getType());
      sized_image = scaleOp.filter(buff_image, sized_image);
      
      % Put image in frame
      icon_java = javax.swing.ImageIcon(sized_image);
      label = javax.swing.JLabel(icon_java);
      frame_java{fj_idx}.getContentPane.add(label);
      
      % Size frame to OL
      if isfullscreen
        gds(device_number).setFullScreenWindow(frame_java{fj_idx});
      else
        frame_java{fj_idx}.setBounds( pos(1), pos(2), pos(3), pos(4) );
      end
    else
      frame_java{fj_idx}.pack
    end
    
    frame_java{fj_idx}.repaint
    %frame_java{fj_idx}.show
    
  end % fullscreen
  
  
  function closescreen()
    %CLOSESCREEN Dispose FULLSCREEN() window
    %
    
    %global frame_java
    for k = 1:length(frame_java)
      try frame_java{k}.dispose(); end
    end
  end % closescreen
  
  
  
  
  %%
  %   function image_show_psychtoolbox_slow()
  %   t1 = 1; % seconds
  %   tb = 1; % seconds
  %
  %
  %   % Choose a screen for ouptut (based on OL)
  %   screenNumber = 1; % temp
  %
  %   % Create a window for stimulus display
  %   window = Screen('OpenWindow', screenNumber, [200,200,200]);
  %   screenrect = Screen('Rect',window);
  %
  %
  %   % Create textures for the two images
  %   tidx1 = Screen('MakeTexture',window,img);
  %
  %   % display image 1 for t1 seconds
  %   Screen('DrawTexture',window,tidx1); %,[0 0 sz1(1) sz1(2)],rect1);
  %   Screen('Flip',window); % this is when the texture is displayed
  %   WaitSecs(t1);
  %
  %   % display blank screen for tb seconds
  %   Screen('Flip',window);
  %   WaitSecs(tb);
  %
  %
  %   % Clean up
  %   Screen('Close',tidx1);
  %   Screen('Close',window);
  %   end
  
end % PlayImage