function [nevFile] = write2nev(sortingParams,waveforms,timestamps,codes,info,adcChannel)
%WRITE2NEV: final stage of sorting, takes output from extract waveforms and
%writes it to a .nev file that can be open in many programs.
%
%
%This code is heavily based on plx2nev, written by Matt Smith for his
%program SpikeSort (http://www.smithlab.net)
%
%INPUT:
%
%       sortingParams:  structure produced by getsortingparams that has
%                       important variables in it relevant to this function. See
%                       getsortingparams.m for more detail.
%
%       waveforms:      mxn matrix with m corresponding to user
%                       selected ms of waveform time
%
%       timestamps:     nx1 matrix of timestamps, where n is the number
%                       of detected threshold crossings
%
%       codes:          nx1 matrix of codes corresponding to which
%                       channel a given spike was detected on
%
%       info:           info output given by third argument in
%                       load_open_ephys_data_faster.m. This is a function
%                       used by extractwaveforms.m to load data.
%
%       adcChannel:     this is a flag, in one session single electrodes
%                       sent through ADC4.continuous had an odd voltage
%                       scaling that needed to be corrected. For almost
%                       everyone else this would likely take a default
%                       value of 0
%
%
%OUTPUT:
%       A .nev file is written by this code that can be read using plexon
%       offline sorter or a number of other programs including Spike2, Matt
%       Smiths Spikesort, and likely (though not currently tested) the BOSS
%       spike sorter provided by Blackrock.



%final file name stored in sortingParams
nevFile = sortingParams.nevFileOutput;

% (1)  Write header
% check to see if the file exists, if it does delete it, otherwise you'll
% be writing over an old file which is a bad idea.
if exist(nevFile,'file') == 2
    delete(nevFile)
    fidWrite = fopen(nevFile, 'w', 'l');
else
    fidWrite = fopen(nevFile, 'w', 'l');
end

% (2) write content to header

%this section borrows heavily from  Matt Smith lab's code plx2nev.m

nWordsinWave = size(waveforms,1);
numExtHdr = length(unique(codes)); % number of channels, which is the number of uniquely identified channels.
extHdrBytes = 32;
basicHdrBytes = 336;
fwrite(fidWrite, 'NEURALEV', 'char');   % file type ID
fwrite(fidWrite, [0;0], 'uchar'); % File Spec
fwrite(fidWrite, 0, 'uint16'); % additional flags
headerSize = basicHdrBytes + (numExtHdr * extHdrBytes);
fwrite(fidWrite, headerSize, 'uint32'); % add up bytes in basic and extended header for header size
fwrite(fidWrite, 8+(2*nWordsinWave), 'uint32'); %% Bytes in data packets (8 + nBytesinWaveform)

fwrite(fidWrite, info.header.sampleRate, 'uint32'); % time resolution of time stamps
fwrite(fidWrite, info.header.sampleRate, 'uint32'); % Time resolutions of samples (sampling frequency)

%section specifically extracts dates from the info output of load_open_ephys_faster.m
date_converted = datevec(info.header.date_created,'dd-mmm-yyyy HHMMSS'); % year, month, date, hour, minute, second
date = info.header.date_created(1:strfind(info.header.date_created,' ')-1);
DayNumber = weekday(date,'dd-mmm-yyyy');

% write date information to .nev header
fwrite(fidWrite, date_converted(1), 'uint16'); % Year
fwrite(fidWrite, date_converted(2), 'uint16'); % Month
fwrite(fidWrite, DayNumber, 'uint16'); % DayOfWeek
fwrite(fidWrite, date_converted(3), 'uint16'); % Day
fwrite(fidWrite, date_converted(4), 'uint16'); % Hour
fwrite(fidWrite, date_converted(5), 'uint16'); % Minute
fwrite(fidWrite, date_converted(6), 'uint16'); % Second
fwrite(fidWrite, 0, 'uint16'); % Millisecond

%additional header writing information
fwrite(fidWrite, char(strcat({blanks(28)}, {'NULL'})), 'char'); % String labeling program that created file
fwrite(fidWrite, char(strcat({blanks(196)}, {'NULL'})), 'char'); % Comment field, null terminated
fwrite(fidWrite, blanks(52), 'char');   % reserved for future information
fwrite(fidWrite, 0, 'uint32'); % Processor timeStamp
fwrite(fidWrite, numExtHdr, 'uint32'); % # of extended Headers

%% write extended header
% note that some of these values are guesses or just default filler values
for iHeader=1:numExtHdr
    fwrite(fidWrite, 'NEUEVWAV', 'char'); % Packet ID (always set to 'NEUEVWAV')
    fwrite(fidWrite, iHeader, 'uint16'); % Electrode ID
    fwrite(fidWrite, 1, 'uchar'); % Front end ID
    fwrite(fidWrite, iHeader, 'uchar'); % Front end connector pin
    fwrite(fidWrite, 600, 'uint16'); %% Neural amp digitization factor (nVolt per Bit)
    fwrite(fidWrite, 0, 'uint16'); % Energy Threshold
    fwrite(fidWrite, 0, 'int16'); % High Threshold
    fwrite(fidWrite, 0, 'int16'); % Low threshold
    fwrite(fidWrite, 0, 'uchar'); % Number of sorted units (set to 0)
    fwrite(fidWrite, 2, 'uchar'); % Number of bytes per waveform sample
    fwrite(fidWrite, 0, 'float'); % Stim Amp Digitization factor
    fwrite(fidWrite, blanks(6), 'uchar'); % Remaining bytes reserved
end
%% Sequential read and writing of spikes
% need to keep track of locations in each file, number of open-ephys waves
% that were not written, number of waves that were written

%Read and write: timestamp, waveform, sort code


spikeCount = 0;
eventCount = 0;
contCount = 0;
writeCount = 0;
totalCount = 0;
printFreq = ceil(length(timestamps)/5); % print a status message every this many spikes

fprintf('oephys2nev: Writing spikes into NEV ... ');

for i = 1:length(timestamps)

    % Read in data block header - 16 bytes
    type = 1; % 1 = spike, 4 = event, 5 = continuous
    upperByte = 0;
    timestamp = timestamps(i);
    channelNum = codes(i); %%
    sortCode = 0; %% %treat everything as unclassified
    numWaveforms = 1; % number of waveforms in following data block
    sampleNWordsinWave = nWordsinWave;
    spikeCount = spikeCount + 1;
    totalCount = totalCount + 1;


    % convert timestamp to int32
    ts = cast(bitshift(upperByte,32),'uint64') + cast(timestamp,'uint64');
    ts = cast(ts,'uint32');

    if numWaveforms > 0 % continuous data follows
        waveform = waveforms(:,i)'; %Read in wave

        %comment out the above and uncomment below to take into account
        %bit2volt conversion
        
        %waveform = waveforms(:,i)'*info.header.bitVolts;
        if type == 1 % It's a spike! Write wave here
            writeCount = writeCount + 1;

            fwrite(fidWrite, timestamp, 'uint32'); % Timestamp of spike
            fwrite(fidWrite, channelNum, 'uint16'); % PacketID (electrode ID number)
            fwrite(fidWrite, sortCode, 'uchar'); % Sort Code

            if sortCode~=0
                disp('when writing channel, there was a strange sortcode')
            end
            fwrite(fidWrite, 0, 'uchar'); % Reserved for future unit info

            %Write waveform. In the case that we take in data via ADC
            %channels on open ephys, there is a voltage conversion
            %difference that gets washed out by conversion to int16. Just
            %in case scale amplitude by 500 to ensure resolution.

            if adcChannel == 1
                waveform = waveform*500;
            end

            fwrite(fidWrite, waveform, 'int16'); % Write waveform

            % status message as spikes are written
            if rem(writeCount,printFreq)==0
                fprintf('%d%% ... ',floor((writeCount/length(timestamps))*100));
            end
        end
    end % End of numWaveforms loop



end % End of while loop to read/write waves

fclose(fidWrite);
disp('done!');

end
