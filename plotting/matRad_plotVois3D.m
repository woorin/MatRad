function patches = matRad_plotVois3D(axesHandle,ct,cst,selection,cMap,pln)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad function that plots 3D structures of the volumes of interest.
% if the 3D-data is not stored in the CT, it will be commputed on the fly
%
% call
%   patches = matRad_plotVois3D(axesHandle,ct,cst,selection,cMap)
%
% input
%   axesHandle  handle to axes the structures should be displayed in
%   ct          matRad ct struct which contains resolution
%   cst         matRad cst struct
%   selection   logicals defining the current selection of contours
%               that should be plotted. Can be set to [] to plot
%               all non-ignored contours.
%   cMap        optional argument defining the colormap, default are the
%               colors stored in the cst
%
% output
%   patches     patch objects created by the matlab 3D visualization
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015 the matRad development team. 
% 
% This file is part of the matRad project. It is subject to the license 
% terms in the LICENSE file found in the top-level directory of this 
% distribution and at https://github.com/e0404/matRad/LICENSES.txt. No part 
% of the matRad project, including this file, may be copied, modified, 
% propagated, or distributed except according to the terms contained in the 
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if size(cst,2) < 8
    cst = matRad_computeAllVoiSurfaces(ct,cst);
end

%Use stored colors or colormap?
if nargin < 5 || isempty(cMap)
    cMapScale = size(cMap,1)-1;
    %determine colors
    voiColors = cMap(round(linspace(1,cMapScale,size(cst,1))),:);
else
    for i = 1:size(cst,1)
      voiColors(i,:) = cst{i,5}.visibleColor;
    end
end

if nargin < 4 || isempty(selection) || numel(selection) ~= size(cst,1)
    selection = logical(ones(size(cst,1),1));
end

cMapScale = size(cMap,1)-1;

axes(axesHandle);
wasHold = ishold();

hold(axesHandle,'on');

numVois = size(cst,1);

patches = cell(0);

CCC=pln.propStf.couchAngles*pi./180;
GGG=pln.propStf.gantryAngles*pi./180;
TTT=pln.propStf.isoCenter;
RRR=40;

for voiIx = 1:numVois
    if selection(voiIx) && ~strcmp(cst{voiIx,3},'IGNORED')
        
        patches{voiIx} = patch(cst{voiIx,8}{1},'VertexNormals',cst{voiIx,8}{2},'FaceColor',voiColors(voiIx,:),'EdgeColor','none','FaceAlpha',0.4,'Parent',axesHandle);
    end
end

fff=0;
bbb=0;
try
    bbb=evalin('base','bbb');
catch
    fff=1;
end
xxx=0;
try
    xxx=evalin('base','xxx');
catch
    xxx=0;
end
if fff==0
    if size(CCC,2)<bbb
        RRR=40;
    end
end

for i=1:size(CCC,2)
    if fff==0
        if i>bbb
            RRR=80;
        end
    end
    if xxx==1
        RRR=120;
    end
    Y1=TTT(i,1)-RRR/2*cos(GGG(i));%TTT(i,2)+RRR*sin(GGG(i))*cos(CCC(i));
    X1=TTT(i,2)+RRR/2*sin(GGG(i))*cos(CCC(i));%TTT(i,1)-RRR*cos(GGG(i));
    Z1=TTT(i,3)-RRR/2*sin(GGG(i))*sin(CCC(i));%TTT(i,3)-RRR*sin(GGG(i))*sin(CCC(i));
    Y2=TTT(i,1)+RRR*cos(GGG(i));%TTT(i,2)-RRR*sin(GGG(i))*cos(CCC(i));
    X2=TTT(i,2)-RRR*sin(GGG(i))*cos(CCC(i));%TTT(i,1)+RRR*cos(GGG(i));
    Z2=TTT(i,3)+RRR*sin(GGG(i))*sin(CCC(i));%TTT(i,3)+RRR*sin(GGG(i))*sin(CCC(i));
    if CCC(i)>=0
        X=[X1,TTT(i,2),X2,NaN];
        Y=[Y1,TTT(i,1),Y2,NaN];
        Z=[Z1,TTT(i,3),Z2,NaN];
    else 
        X=[X2,TTT(i,2),X1,NaN];
        Y=[Y2,TTT(i,1),Y1,NaN];
        Z=[Z2,TTT(i,3),Z1,NaN];
    end
    patch(X,Y,Z,[0.5,0.8,1,NaN],'EdgeColor','interp','Marker','o','MarkerFaceColor','flat','parent',axesHandle);
end

if ~wasHold
    hold(axesHandle,'off');
end


end