function mp = OldStyleMonitorPositions()
% OldStyleMonitorPositions - Return monitor positions in pre-2014b format

mp = get(0, 'MonitorPositions');
if verLessThan('matlab', '8.4.0')
   % R2014a or earlier
   % Format is already in format [xmin ymin xmax ymax]
else
   % R2014b or later
   % Convert to format [x1 y1 width height]
   mp = sortrows(mp);
   XY = [mp(:,1) -1*mp(:,2)-(mp(:,4)-mp(1,4))+2];
   mp = [XY XY+mp(:,3:4)-1];
end
