function mp = OldStyleMonitorPositions(unsorted)
% OldStyleMonitorPositions - Return monitor positions in pre-2014b format

mp = get(0, 'MonitorPositions');
if verLessThan('matlab', '8.4.0')
   % R2014a or earlier
   % Format is already in format [xmin ymin xmax ymax]
else
   % R2014b or later
   % Convert to format [x1 y1 width height]
   [mp, idx] = sortrows(mp);
   XY = [mp(:,1) -1*mp(:,2)-(mp(:,4)-mp(1,4))+2];
   mp = [XY XY+mp(:,3:4)-1];
   if nargin == 1
       % Reverse sort so that playimage works as expected for fullscreen
       u = 1:size(mp, 1);
       newidx(idx) = u;
       mp = mp(newidx, :);
   end
end
