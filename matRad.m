% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad script
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

clear
close all
clc

% load patient data, i.e. ct, voi, cst

%load HEAD_AND_NECK
load LIVER.mat
%load PROSTATE.mat
%load LIVER.mat
%load BOXPHANTOM.mat

% meta information for treatment plan

pln.radiationMode   = 'photons';     % either photons / protons / carbon
pln.machine         = 'Generic';

pln.numOfFractions  = 30;

% beam geometry settings
pln.propStf.bixelWidth      = 5; % [mm] / also corresponds to lateral spot spacing for particles
pln.propStf.gantryAngles    = 0; % [?]
pln.propStf.couchAngles     = 0; % [?]
pln.propStf.numOfBeams      = numel(pln.propStf.gantryAngles);
pln.propStf.isoCenter       = ones(pln.propStf.numOfBeams,1) * matRad_getIsoCenter(cst,ct,0);


% optimization settings
pln.propOpt.bioOptimization = 'none'; % none: physical optimization;             const_RBExD; constant RBE of 1.1;
                                      % LEMIV_effect: effect-based optimization; LEMIV_RBExD: optimization of RBE-weighted dose
pln.propOpt.runDAO          = false;  % 1/true: run DAO, 0/false: don't / will be ignored for particles
pln.propOpt.runSequencing   = false;  % 1/true: run sequencing, 0/false: don't / will be ignored for particles and also triggered by runDAO below

%% initial visualization and change objective function settings if desired
matRadGUI

%% wait for input
prompt='If the parameters are settled, press any key to continue.';
input(prompt);

%% initialize beam set
% % generate base information cube B
B.apdim=[12,12,9]; %approximate level
B.stdbeamnum=36; % beam num of the most-beam-held circle
B.dim=ct.cubeDim; 
B.indexratio=B.dim./B.apdim;
B.ratio=prod(B.indexratio);
B.resolution(1)=ct.resolution.x;
B.resolution(2)=ct.resolution.y;
B.resolution(3)=ct.resolution.z;
B.bnv=int64(abs(cos((-(B.stdbeamnum/4):1:(B.stdbeamnum/4))*2*pi/B.stdbeamnum))*B.stdbeamnum);
for i=1:size(B.bnv,2)
    if B.bnv(i)==0
        B.bnv(i)=1;
    end
end
i=1;
j=1;
k=1;
% % generate standard body cube C
% get all target voxel num
C.tg=[]; % target voxel index
C.tgcst=[]; % target constraint
C.oar=[]; % organ-at-risk index
C.oarcst=[]; % organ-at-risk constraint
C.tgc=[]; % target center position
C.tgapi=[]; % target approximate index 
C.tgapp=[]; % target approximate position
for v=cst(:,3)'
    if isequal(v,{'TARGET'}) && ~isempty(cst{j,6})
        C.tg{i}=cst{j,4}{1};
        C.tgcst{i}=cst{j,6};
        C.tgindex(i)=j;
        i=i+1;
    end
    if isequal(v,{'OAR'}) && ~isempty(cst{j,6})
        C.oar{k}=cst{j,4}{1};
        C.oarcst{k}=cst{j,6};
        C.oarindex(i)=j;
        k=k+1;
    end
    j=j+1;
end
% % fix overlapping
i=1;
j=1;
x=size(C.tg,2)+size(C.oar,2);
temp1=[C.tg,C.oar];
for i=1:x
    for j=i+1:x
        temp1{j}=setdiff(temp1{j},temp1{i});
    end
end
i=1;
x=size(C.tg,2);
y=size(C.oar,2);
for i=1:x
    C.tg{i}=temp1{i};
end
for j=1:y
    C.oar{j}=temp1{x+j};
end
%get target central voxel num & cal approximized matrix
for j=1:size(C.tg,2)
    [x1,y1,z1]=ind2sub(B.dim,C.tg{j});
    C.tgc{j}=mean([x1,y1,z1]).*B.resolution;
    C.tgapi{j}=ceil([x1,y1,z1]./B.indexratio);
    temp1=sub2ind(B.apdim,C.tgapi{j}(:,1),C.tgapi{j}(:,2),C.tgapi{j}(:,3));
    C.tgapi{j}=unique(C.tgapi{j},'rows');
    temp2=sub2ind(B.apdim,C.tgapi{j}(:,1),C.tgapi{j}(:,2),C.tgapi{j}(:,3));
    C.tgapsub{j}(:,1)=temp2;
    for i=1:size(C.tgapi{j},1)
        C.tgaps{j}{i}{1}=C.tgapi{j}(i,:);
        C.tgaps{j}{i}{2}=find(temp1==temp2(i));
        C.tgaps{j}{i}{2}=C.tg{j}(C.tgaps{j}{i}{2});
        C.tgaps{j}{i}{3}=size(C.tgaps{j}{i}{2},1);
        C.tgapsub{j}(i,2)=C.tgaps{j}{i}{3}/size(C.tg{j},1);
    end
    C.tgapp{j}=double(C.tgapi{j}).*B.indexratio.*B.resolution;
end
clear x1;
clear y1;
clear z1;
clear temp1;
clear temp2;

j=1;
x=size(B.bnv,2);
B.bs=[]; % generate the radial beam sphere
for i=1:x
    if ~isempty(B.bs)
        B.bs{2}=[B.bs{2},(1:B.bnv(i))*360/B.bnv(i)];
        B.bs{1}=[B.bs{1},(-90+(i-1)*360/B.stdbeamnum)*ones(1,B.bnv(i))];
    else
        B.bs{2}=(1:B.bnv(i))*360/B.bnv(i);
        B.bs{1}=(-90+(i-1)*360/B.stdbeamnum)*ones(1,B.bnv(i));
    end
end
B.bs{2}=double(B.bs{2});
% % beam ball B.bs done
% %

% % pln modify
j=size(C.tgc,2);
x=sum(B.bnv); % each target shares how many beams
T=[];
for i=1:j
    if isempty(T)
        %T=[C.tgc{i};C.tgapp{i}];
        T=C.tgc{i};
    else
        %T=[T;C.tgc{i};C.tgapp{i}];
        T=[T;C.tgc{i}];
    end
end
% %%%%%%%%%%%%%%%%%%%%%%%%%% only center
j=size(T,1);
pln.propStf.numOfBeams=j*x;
pln.propStf.isoCenter=[];
pln.propStf.gantryAngles=[];
pln.propStf.couchAngles=[];
for i=1:j
    if ~isempty(pln.propStf.isoCenter)
        pln.propStf.isoCenter=[pln.propStf.isoCenter;ones(x,1).*T(i,:)];
        pln.propStf.gantryAngles=[pln.propStf.gantryAngles,B.bs{2}];
        pln.propStf.couchAngles=[pln.propStf.couchAngles,B.bs{1}];
    else
        pln.propStf.isoCenter=[ones(x,1).*T(i,:)];
        pln.propStf.gantryAngles=[B.bs{2}];
        pln.propStf.couchAngles=[B.bs{1}];
    end
end
% % pln modify done
% %
%% wait
prompt='If the parameters are settled, press enter to continue.';
input(prompt);

%% generate stf and dose calculation
%temp.bixelwidth=pln.propStf.bixelWidth;
temp2.gantryangles=pln.propStf.gantryAngles;
temp2.couchangles=pln.propStf.couchAngles;
temp2.numofbeams=pln.propStf.numOfBeams;
temp2.isocenter=pln.propStf.isoCenter;
pln.propStf.numOfBeams=1;
y=0; %%%
for k=C.tgindex
    t=1;
    for kk=C.tgindex
        if kk~=k
            cst{kk,6}=[];
        else
            cst{kk,4}{1}=double(sub2ind(B.dim,ceil(C.tgc{t}(1)/B.resolution(1)),ceil(C.tgc{t}(2)/B.resolution(2)),ceil(C.tgc{t}(3)/B.resolution(3))));
            cst{kk,6}=C.tgcst{t};
        end
        t=t+1;
    end
    for j=1:x
        pln.propStf.gantryAngles=temp2.gantryangles(j);
        pln.propStf.couchAngles=temp2.couchangles(j);
        pln.propStf.isoCenter=temp2.isocenter(j,:);
        stf = matRad_generateStf(ct,cst,pln);
        if strcmp(pln.radiationMode,'photons')
            dij = matRad_calcPhotonDoseX(ct,stf,pln,cst);
            %dij = matRad_calcPhotonDoseVmc(ct,stf,pln,cst);
        elseif strcmp(pln.radiationMode,'protons') || strcmp(pln.radiationMode,'carbon')
            dij = matRad_calcParticleDose(ct,stf,pln,cst);
        end
        % % simplify dose matrix %%%%%% not simplify, just vector sum
        fprintf('calculating beam %d TARGET dosage and OAR dosage of %d beams\n',j+y,temp2.numofbeams);
        for i=1:size(C.tg,2)
            D.TARGETdose(i,j+y)=sum(sum(dij.physicalDose{1}(C.tg{i},:)));
        end
        for i=1:size(C.oar,2)
            D.OARdose(i,j+y)=sum(sum(dij.physicalDose{1}(C.oar{i},:)));
        end
    end
    y=y+x;
end
t=1;
for k=C.tgindex
    cst{k,6}=C.tgcst{t};
    cst{k,4}{1}=C.tg{t};
    t=t+1;
end
pln.propStf.gantryAngles=temp2.gantryangles;
pln.propStf.couchAngles=temp2.couchangles;
pln.propStf.numOfBeams=temp2.numofbeams;
pln.propStf.isoCenter=temp2.isocenter;
%clear temp2;
%% wait
prompt='If the parameters are settled, press enter to continue.';
input(prompt);

%% full-scale search (greedy)
D.penalty(1,:)=zeros(1,pln.propStf.numOfBeams);
D.penalty(2,:)=1:pln.propStf.numOfBeams;
for i=1:size(C.tgcst,2)
    D.penalty(1,:)=D.penalty(1,:)-D.TARGETdose(i,:).*C.tgcst{i}.penalty;
end
for i=1:size(C.oarcst,2)
    D.penalty(1,:)=D.penalty(1,:)+D.OARdose(i,:).*C.oarcst{i}.penalty;
end
D.penalty=(D.penalty)';
t=4; % t is the number of beams of each tumor
temp.numOfBeams=pln.propStf.numOfBeams;
temp.isoCenter=pln.propStf.isoCenter;
temp.gantryAngles=pln.propStf.gantryAngles;
temp.couchAngles=pln.propStf.couchAngles;
pln.propStf.numOfBeams=t*size(C.tg,2);
pln.propStf.isoCenter=[];
pln.propStf.gantryAngles=[];
pln.propStf.couchAngles=[];
y=0;
for kk=1:size(C.tg,2)
    D.penaltytemp=sortrows(D.penalty(((kk-1)*x+1):(kk*x),:),1);
    D.pick=(D.penaltytemp(1:t,2))';
    for k=1:t
        pln.propStf.isoCenter(k+y,:)=temp.isoCenter(D.pick(k),:);
        pln.propStf.gantryAngles=[pln.propStf.gantryAngles,temp.gantryAngles(D.pick(k))];
        pln.propStf.couchAngles=[pln.propStf.couchAngles,temp.couchAngles(D.pick(k))];
    end
    y=y+t;
end
%% generate stf and dose calculation (again)
kkk=0;
dij=[];
stf=[];
clear temp;
temp.numOfBeams=pln.propStf.numOfBeams;
temp.isoCenter=pln.propStf.isoCenter;
temp.gantryAngles=pln.propStf.gantryAngles;
temp.couchAngles=pln.propStf.couchAngles;
pln.propStf.numOfBeams=t;
pln.propStf.isoCenter=[];
pln.propStf.gantryAngles=[];
pln.propStf.couchAngles=[];
for k=C.tgindex
%for j=1:temp2.numofbeams
    tt=1;
    for kk=C.tgindex
        if kk~=k
            cst{kk,6}=[];
        else
            cst{kk,6}=C.tgcst{tt};
        end
        tt=tt+1;
    end
    pln.propStf.gantryAngles=temp.gantryAngles(kkk*t+1:kkk*t+t);
    pln.propStf.couchAngles=temp.couchAngles(kkk*t+1:kkk*t+t);
    pln.propStf.isoCenter=temp.isoCenter(kkk*t+1:kkk*t+t,:);
    stftemp = matRad_generateStf(ct,cst,pln);
    if strcmp(pln.radiationMode,'photons')
        temp3 = matRad_calcPhotonDose(ct,stftemp,pln,cst);
        %dij = matRad_calcPhotonDoseVmc(ct,stf,pln,cst);
    elseif strcmp(pln.radiationMode,'protons') || strcmp(pln.radiationMode,'carbon')
        temp3 = matRad_calcParticleDose(ct,stftemp,pln,cst);
    end
    if isempty(dij)
        dij=temp3;
    else
        dij.numOfBeams=dij.numOfBeams+temp3.numOfBeams;
        dij.numOfRaysPerBeam=[dij.numOfRaysPerBeam,temp3.numOfRaysPerBeam];
        dij.totalNumOfBixels=dij.totalNumOfBixels+temp3.totalNumOfBixels;
        dij.totalNumOfRays=dij.totalNumOfRays+temp3.totalNumOfRays;
        dij.bixelNum=[dij.bixelNum;temp3.bixelNum];
        dij.rayNum=[dij.rayNum;temp3.rayNum];
        dij.beamNum=[dij.beamNum;temp3.beamNum+kkk*t];
        dij.physicalDose{1}=[dij.physicalDose{1},temp3.physicalDose{1}];
    end
    if isempty(stf)
        stf=stftemp;
    else
        stf=horzcat(stf,stftemp);
    end
    kkk=kkk+1;
end
t=1;
for k=C.tgindex
    cst{k,6}=C.tgcst{t};
    t=t+1;
end
pln.propStf.gantryAngles=temp.gantryAngles;
pln.propStf.couchAngles=temp.couchAngles;
pln.propStf.numOfBeams=temp.numOfBeams;
pln.propStf.isoCenter=temp.isoCenter;
%% inverse planning for imrt
%resultGUI = matRad_fluenceOptimization(dij,cst,pln);

%% sequencing
%if strcmp(pln.radiationMode,'photons') && (pln.propOpt.runSequencing || pln.propOpt.runDAO)
 %   %resultGUI = matRad_xiaLeafSequencing(resultGUI,stf,dij,5);
  %  %resultGUI = matRad_engelLeafSequencing(resultGUI,stf,dij,5);
   % resultGUI = matRad_siochiLeafSequencing(resultGUI,stf,dij,5);
%end

%% DAO
%if strcmp(pln.radiationMode,'photons') && pln.propOpt.runDAO
 %  resultGUI = matRad_directApertureOptimization(dij,cst,resultGUI.apertureInfo,resultGUI,pln);
 %  matRad_visApertureInfo(resultGUI.apertureInfo);
%end

%% start gui for visualization of result
%matRadGUI

%% indicator calculation and show DVH and QI
%[dvh,qi] = matRad_indicatorWrapper(cst,pln,resultGUI);
