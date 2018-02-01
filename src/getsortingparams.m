function [sortingParams] = getsortingparams()

%GETSORTINGPARAMS: a simple function that queries a GUI to carry out the
%following. (1) figure out whether you want to sort a file or a folder (2)
%determine parameters of sorting, filter order, and sorting waveform length
%etc. (3) determine where you want to write final .nev file (4) put these
%parameters into a structure called sortingParams which holds relevant
%values.

%OUTPUT:

% sortingParams: structure with the following subentries
%
%    sortingParams.dataIdentifier: path of folder, or path+filename
%                                  to be sorted
%
%    sortingParams.filterOrder:    order of butterworth filter used to
%                                  extract spikeband signal (default 3)
%
%    sortingParams.lowPassCutoff:  lowpass cutoff in Hz for extracting
%                                  spikeband signal (default 5000 Hz)
%
%    sortingParams.highPassCutoff: highpass cutoff in Hz for extracting
%                                  spikeband signal (default 500 Hz)
%
%    sortingParams.thresholdMult:  scaling of MAD estimate of noise used to
%                                  calculate thresholds (default 5)
%
%    sortingParams.waveformLength: length of threshold crossing waveforms,
%                                  in ms, that are ultimately detected
%                                  (default 2 ms)

choice = questdlg('Are you sorting a file or a collection of files','Step 1','File','Collection','File');

switch choice
    case 'File'
        [filename,pathname] = uigetfile('*','Select either .continuous or .ADC file');
        sortingParams.dataIdentifier = [pathname filename];
    case 'Collection'
        [pathname] = uigetdir('','select directory');
        sortingParams.dataIdentifier = [pathname];
    otherwise
        error('WARNING: invalid selection');
end

prompt = {'Filter Order:','Low pass filter cutoff (Hz):','High pass filter cutoff (Hz):','multiplier x std(noise)','waveformLength (ms)'};
dlg_title = 'sorting parameters';
num_lines = 1;
defaultans = {'3','5000','500','5','2'}; 
answerInStrings = inputdlg(prompt,dlg_title,num_lines,defaultans);
answerInNumbers = cellfun(@(x) str2double(x),answerInStrings,'UniformOutput',false);
[sortingParams.filterOrder,sortingParams.lowPassCutoff,...,
    sortingParams.highPassCutoff,sortingParams.thresholdMult,...,
    sortingParams.waveformLength] = deal(answerInNumbers{:});

%find out where to put file
[savedFileName,savedFilePath] = uiputfile('*.nev','Save File As',[pathname filesep 'output' '.nev']);
sortingParams.nevFileOutput = [savedFilePath savedFileName];
end