
function [waveforms,timestamps,codes,info] = extractwaveforms(dataIdentifier,filterOrder,lowPassCutoff,highPassCutoff,thresholdMult,waveformLength)

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
%   dataIdentifier:         can either be a filename (INCLUDING path) to a
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
%                           signal (default 5000 Hz)
%
%   highPassCutoff:         highpass cutoff in Hz for extracting spikeband
%                           signal (default 500 Hz)
% 
%   thresholdMult:          scale factor to multiple by sigma obtained from
%                           MAD estimator (default 5)
%
%   waveformLength:         Length (in ms) of waveform snippets to be
%                           extracted
%
%
%OUTPUT:
%   waveforms:              mxn matrix with m corresponding to user
%                           selected ms of waveform time
%
%   timestamps:             nx1 matrix of timestamps, where n is the number
%                           of detected threshold crossings
%   
%   codes:                  nx1 matrix of codes corresponding to which
%                           channel a given spike was detected on
% 
%   info:                   info output given by third argument in
%                           load_open_ephys_data_faster.m
%       
%
%
% Author: Ramanujan Raghavan
% Version 1.0
% Date Updated: 01-31-2018
% Post issues to: https://github.com/rtraghavan/oephys2nev/issues




%%

inputValue = exist(dataIdentifier);
if inputValue == 7 %it's a folder
    listing = dir(dataIdentifier); %assumes you're looking at multiple .continuous files
    findChanFiles = cellfun(@(x) ~isempty(strfind(x,'CH')),{listing.name});
    onlyChannels = listing(findChanFiles);
    onlyChannelsWithPath = cellfun(@(x) [dataIdentifier filesep x],{onlyChannels.name},'UniformOutput',false);
    listingChanFiles = cell2struct(onlyChannelsWithPath,'pathPlusFile');
    channelNumber = length(listingChanFiles);
elseif inputValue == 2 %it's a file
    listingChanFiles = struct;
    listingChanFiles(1).pathPlusFile = dataIdentifier;
    channelNumber = 1;
else
    error('neither folder nor file seems to have been selected')
end

    

waveformsUnsorted = [];
timestampsUnsorted = [];
codesUnsorted = [];

for z = 1:channelNumber

    %read data, requires load_open_ephys_data_faster function that is available
    %on open ephy's website at https://github.com/open-ephys/analysis-tools
    filenameToOpen = listingChanFiles(z).pathPlusFile;
    if exist('info','var') == 1
        [data, ~, ~] = load_open_ephys_data_faster(filenameToOpen);
    else
        [data, ~, info] = load_open_ephys_data_faster(filenameToOpen);
    end
    samplingrate = info.header.sampleRate;
    if mod(samplingrate,2) ~= 0
        disp('an odd sampling rate? that is never a good idea')
    end
    one_ms = round(samplingrate*.001);


    %filter data
    [b,a] = butter(filterOrder,[highPassCutoff lowPassCutoff]/(samplingrate/2),'bandpass');
    spikeBandSignal = filter(b,a,data);

    %calculate threshold, ignoring initial transient caused by filter
    thresh = median(abs(spikeBandSignal)/.6745) * thresholdMult;

    %Threshhold crossings are done on the rectified filtered signal, but at
    %some point waveforms need to be aligned to either their maximum or
    %minimum. This section of code goes with whatever makes more sense.
    size1 = length(find(spikeBandSignal>=thresh));
    size2 = length(find(spikeBandSignal<=-thresh));


    % now find the threshold crossing times
    thresh2 = find(abs(spikeBandSignal)>=thresh);
    thresh2(thresh2<one_ms) = []; % takes care of initial transient caused by filtering process
    hstart = [thresh2(1); thresh2(find(diff(thresh2)>one_ms)+1)]; %find when there are threshold crossings, that are at least 1 ms apart


    % additional control if desired
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


    
    %prepare to realign waveforms
    %I did something simple, looked a certain amount of time before and
    %after the spike. It is symmetric currently, another option would be to
    %use a specific time before or after. Future work is needed here.

    pre_post = one_ms * (waveformLength/2);

    %The following lines of code take care of things if there are spikes
    %detected very early or more likely filter transients driven by the
    %fact I do not zero pad before filtering. Which I should in future
    %releases.
    
    border = one_ms*(waveformLength/2)+1;
    hstart = hstart(hstart>border & hstart<(length(spikeBandSignal)-border));
    hstart2 = num2cell(hstart);

    %calculate alignments
    aligned = cellfun(@(x) spikeBandSignal(x-pre_post:x+pre_post),hstart2,'UniformOutput',false);
    waveformsUnaligned = cellfun(@(x) x-pre_post:x+pre_post,hstart2,'UniformOutput',false);

    %align to min if there are more negative thresholds, max if there are
    %more positive thresholds
    if size2>size1
        [~,ind] = cellfun(@(x) min(x),aligned,'UniformOutput',false);
    else
        [~,ind] = cellfun(@(x) max(x),aligned,'UniformOutput',false);
    end

    %realign all waveforms
    hstart3 = cellfun(@(x1,x2) x1(x2),waveformsUnaligned,ind);
    aligned_final = cell2mat(cellfun(@(x) spikeBandSignal(x-pre_post:x+pre_post),num2cell(hstart3,2),'UniformOutput',false)');
    waveforms_temp = aligned_final;
    timestamps_temp = hstart3;




    % In many cases no spikes are detected. I create a zeroed template
    % waveform at time 1 ms that can be rejected later. This ensures
    % compatability with multiple spike sorting programs. In the future I
    % would like to be able to only add channels that have waveforms on them
    % to the final NEV file that is the output of this program. Just keep
    % this in mind.



    if isempty(timestamps_temp)
        timestamps_temp = 1;
        waveforms_temp = zeros(length(-pre_post:pre_post),1);
    end

    waveformsUnsorted = cat(2,waveformsUnsorted,waveforms_temp);
    timestampsUnsorted = cat(1,timestampsUnsorted,timestamps_temp);
    
    %get code number from file if needbe
    if z >1
        currentCode = str2double(filenameToOpen(strfind(filenameToOpen,'CH')+2:strfind(filenameToOpen,'.')-1));
    else
        currentCode = 1;
    end
    
    codesUnsorted = cat(1,codesUnsorted,ones(length(timestamps_temp),1)*currentCode);

    if ~isempty(find(find(rem((1:channelNumber),ceil(channelNumber/5))==0) == z,1))
        fprintf('%d%% filtered ... \n',floor((1/channelNumber)*(z)*10)*10);
    end

    clearvars aligned aligned_final data hstart* spikeBandSignal range waveformsUnaligned
end
    %sort codes finally.
    [~,sortedCodes] = sort(codesUnsorted);
    codes = codesUnsorted(sortedCodes);
    codes = codes(:); 
    waveforms = waveformsUnsorted(:,sortedCodes);
    timestamps = timestampsUnsorted(sortedCodes);
    timestamps = timestamps(:);
end
