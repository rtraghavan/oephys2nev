% Script Name: main_example.m Script Description: Goal: write nev file from
% open ephys data. Each section of the code below executes a specific
% function. The first brings up a dialog box that prompts you for needed
% sorting parameters. The second calculates threshold crossings and
% associated waveforms. Finally the last function writes the file to the
% place where the user specifies the data ought to be stored.
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

[nevFile] = write2nev(sortingParams,waveforms,timestamps,codes,info,0);