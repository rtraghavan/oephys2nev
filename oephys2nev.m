%{
    Script Name: oephys2nev.m
    Script Description: Goal: write nev file from open ephys data

    This relies on a subsidiary function, open_ephys_filt_to_mat.m
    which opens open enphys files, filters them a bit, writes data out

    Then it writes a NEV file using the output of this initial function.

    Based on plx2nev by Matt Smith (http://www.smithlab.net)

    Author: Ramanujan Raghavan
    Version: 1.0
    Last updated: June-1-2017
    Post issues to: https://github.com/rtraghavan/oephys2nev/issues
%}

clear variables
%% Load test data
[waveforms,timestamps,codes,info,directory] = open_ephys_filt_to_mat();

%% now write header for .nev file

%I decided the simplest way was to copy the directory name and let the user
%edit it, this might change in the future.
defaultans = {directory};
[FileName,PathName] = uiputfile('*.nev','Save File As',[defaultans{:} '.nev']);
nevFile = [PathName FileName];
% check to see if the file exists, if it does delete it, otherwise you'll
% be writing over an old file which is a bad idea.
if exist(nevFile,'file') == 2
    delete(nevFile)
    fidWrite = fopen(nevFile, 'w', 'l');
else
    fidWrite = fopen(nevFile, 'w', 'l');
end

%% write content to header
%this section uses large sections of code from the Smith lab's code
%plx2nev.m

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
% need to keep track of locations in each file, number of open-ephys waves that
% were not written, number of waves that were written

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
        
        if type == 1 % It's a spike! Write wave here
            writeCount = writeCount + 1;
            
            fwrite(fidWrite, timestamp, 'uint32'); % Timestamp of spike
            fwrite(fidWrite, channelNum, 'uint16'); % PacketID (electrode ID number)
            fwrite(fidWrite, sortCode, 'uchar'); % Sort Code
            
            if sortCode~=0
                disp('when writing channel, there was a strange sortcode')
            end
            fwrite(fidWrite, 0, 'uchar'); % Reserved for future unit info
            
            %Write waveform
            fwrite(fidWrite, waveform, 'int16'); % Write waveform
            
            % status message as spikes are written
            if rem(writeCount,printFreq)==0
                fprintf('%d%% ... ',floor((writeCount/length(timestamps))*100));
            end
        end
    end % End of numWaveforms loop
    
    
    
end % End of while loop to read/write waves

fclose(fidWrite);
clear variables