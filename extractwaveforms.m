
function [waveforms,timestamps,codes,info,directory] = extractwaveforms(dataIdentifier,filterOrder,lowPassCutoff,highPassCutoff,thresholdMultiplier,waveformLength)

%WARNING: THIS IS CODE IN PROGRESS IT DOES NOT RUN CURRENTLY. 
%
%
%EXTRACTWAVEFORMS: given either a specific .continuous or .ADC file or a
%set of .continuous fiels, extract threshold crossing times and waveforms
%for them.

% This function works in steps. (1) Load data (2) Filter data using using
% user specified bandpass cutoffs implemented in a 3rd order Butterworth
% filter (3) calculate spike thresholds using a MAD estimators presented in
% Quiroga et al. 2004. (4) Store threshold crossing times, waveform
% snippets

%INPUT:
%   dataIdentifier:         can either be a filename (including path) to a
%                           specific file you want to spike sort.
%                           Alternatively it can be a folder in which case
%                           the code assumes you have a set of N channels
%                           stored in .continuous format that you want to
%                           spikesort
%
%   filterOrder:            filter order for butterworth filter used to
%                           extract spikeband signal (default 3)
%   
%   lowPassCutoff:          lowpass cutoff in Hz for extracting spikeband
%                           signal (default 500 Hz)
%
%   highPassCutoff:         highpass cutoff in Hz for extracting spikeband
%                           signal (default 5000 Hz)
% 
%   thresholdMultiplier:    scale factor to multiple by sigma obtained from
%                           MAD estimator (default 5)
%
%   waveformLength:         Length (in ms) of waveform snippets to be
%                           extracted
%
%
%OUTPUT:
%   waveforms:              mxn matrix with m corresponding to 2 ms of waveform time

% 
% 
% 
% 
% Author: Ramanujan Raghavan
% Version 1.0
% Date Updated: 06-05-2017
% Post issues to: https://github.com/rtraghavan/oephys2nev/issues



%% ask user for directory of files, and set up basic inputs to reading in data
directory = uigetdir;
prompt = {'Enter channel number:','Low pass filter cutoff:','High pass filter cutoff:','param x std(noise)'};
dlg_title = 'Input';
num_lines = 1;
defaultans = {'32','5000','500','5'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
channel_num = str2num(answer{1});
low_pass = str2num(answer{2});
high_pass = str2num(answer{3});
thresh_inp = str2num(answer{4});
waveforms = [];
timestamps = [];
codes = [];

for z = 1:channel_num

    %read data, requires load_open_ephys_data_faster function that is available
    %on open ephy's website at https://github.com/open-ephys/analysis-tools
    filename = ['100_CH',num2str(z),'.continuous'];
    [data, ~, info] = load_open_ephys_data_faster([directory '/' filename]);
    samplingrate = info.header.sampleRate;
    if mod(samplingrate,2) ~= 0
        disp('an odd sampling rate? that is never a good idea')
    end
    one_ms = round(samplingrate*.001);

    %%
    %filter data
    [b,a] = butter(3,[high_pass low_pass]/(samplingrate/2),'bandpass');
    data_filtered = filter(b,a,data);


    %%3
    %calculate threshold, ignoring initial transient caused by filter
    thresh = median(abs(data_filtered(3*one_ms:end))/.6745) * thresh_inp;

    %%
    %Threshhold crossings are done on the rectified filtered signal, but at
    %some point waveforms need to be aligned to either their maximum or
    %minimum. This section of code goes with whatever makes more sense.
    size1 = length(find(data_filtered>=thresh));
    size2 = length(find(data_filtered<=-thresh));


    % now find the threshold crossing times
    thresh2 = find(abs(data_filtered)>=thresh);
    thresh2(thresh2<one_ms) = []; % takes care of initial transient caused by filtering process
    hstart = [thresh2(1); thresh2(find(diff(thresh2)>one_ms)+1)]; %find when there are threshold crossings, that are at least 1 ms apart


    %% additional control if desired
    %in case you want to detect waveforms based specifically on a negative or
    %positive threshold, comment out the prior lines and use the ones below.

    % if size2>size1
    %     thresh2 = find(data_filtered<=-1*thresh); %negative threshold
    %     thresh2(thresh2<30) = []; % takes care of initial transient caused by filtering process
    %     hstart = [thresh2(1); thresh2(find(diff(thresh2)>30)+1)]; %find when there are threshold crossings, that are at least 1 ms apart
    %
    % else
    %     %same as above, only using a positive threshold
    %     thresh2 = find(data_filtered>=1*thresh);
    %     thresh2(thresh2<30) = [];
    %     hstart = [thresh2(1); thresh2(find(diff(thresh2)>30)+1)];
    % end

    %%
    %prepare to realign waveforms
    %I did something simple, looked 1 ms before and after each threshold
    %crossing. This might be customized in the future.

    pre_post = round(samplingrate*.001);



    %I ignore spikes occuring in the first and last 2 ms of the
    %recording. This is to ensure no bugs during waveform alignment. If
    %spike timing in this period of time is critical (usually never is)
    %another work around will be needed.
    border = .002*samplingrate;
    hstart = hstart(hstart>border & hstart<(length(data_filtered)-border));
    hstart2 = num2cell(hstart);

    %calculate alignments
    aligned = cellfun(@(x) data_filtered(x-pre_post:x+pre_post),hstart2,'UniformOutput',false);
    range_plus_minus = cellfun(@(x) x-pre_post:x+pre_post,hstart2,'UniformOutput',false);

    %align to min if there are more negative thresholds, max if there are
    %more positive thresholds
    if size2>size1
        [~,ind] = cellfun(@(x) min(x),aligned,'UniformOutput',false);
    else
        [~,ind] = cellfun(@(x) max(x),aligned,'UniformOutput',false);
    end

    %realign all waveforms
    hstart3 = cellfun(@(x1,x2) x1(x2),range_plus_minus,ind);
    aligned_final = cell2mat(cellfun(@(x) data_filtered(x-pre_post:x+pre_post),num2cell(hstart3,2),'UniformOutput',false)');
    waveforms_temp = aligned_final;
    timestamps_temp = hstart3;


    %{

    In many cases no spikes are detected. I create a zeroed template
    waveform at time 1 ms that can be rejected later. This is a temporary
    solution, done to ensure compatability with matt smith's spikesort
    program (http://www.smithlab.net/spikesort.html), spike2, AND plexon
    GUI that accept the .nev format. In the future I would like to be able
    to only add channels that have waveforms on them to the final NEV file
    that is the output of this program. Just keep this in mind.

    %}

    if isempty(timestamps_temp)
        timestamps_temp = 1;
        waveforms_temp = zeros(length(-pre_post:pre_post),1);
    end

    waveforms = cat(2,waveforms,waveforms_temp);
    timestamps = cat(1,timestamps,timestamps_temp);
    codes = cat(1,codes,ones(length(timestamps_temp),1)*z);

    if ~isempty(find(find(rem((1:channel_num),ceil(channel_num/5))==0) == z,1))
        fprintf('%d%% filtered ... \n',floor((1/channel_num)*(z)*10)*10);
    end

    clearvars -except channel_num low_pass high_pass thresh_inp waveforms timestamps codes directory info

end

end
