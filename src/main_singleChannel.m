% 
% Script Name: main_singleChannel.m Script Description: Goal: write nev
% file from open ephys data. In this variant of the code, write from a
% channel stored in ADC_4.continuous. This is a situation that we encounter
% in Movshon lab when we record using single electrodes.
% 
% 
% This relies on a subsidiary function, extractwaveforms.m which opens open
% enphys files (either .continuous or a single ADC file), filters them,
% writes data out to a matlab structure which is in turn converted into
% .nev code by the code below.
% 
% Based on plx2nev by Matt Smith (http://www.smithlab.net)
% 
% Author: Ramanujan Raghavan
% Version: 1.0
% Last updated: January 30, 2018
% Post issues to: https://github.com/rtraghavan/oephys2nev/issues


clear variables
%% Determine parameters
[sortingParams] = getsortingparams();

%% Run through extractwaveforms

[waveforms,timestamps,codes,info] = extractwaveforms(sortingParams.dataIdentifier,...,
    sortingParams.filterOrder,sortingParams.lowPassCutoff,sortingParams.highPassCutoff,...,
    sortingParams.thresholdMult,sortingParams.waveformLength);

%% Run through write2nev

[nevFile] = write2nev(sortingParams,waveforms,timestamps,codes,info,1);