% Add MIRtoolbox1.8.2 to the MATLAB path
addpath(genpath('MIRtoolbox1.8.2'));
% Specify the folder path
folderPath = 'data';

% Get a list of all files in the folder
files = dir(fullfile(folderPath, '*.wav'));
% Initialize a figure for the subplots
figure;

% Loop through each file and read it
for i = 1:numel(files)
    filePath = fullfile(folderPath, files(i).name);
    audioData = miraudio(filePath, 'TrimEnd', 'TrimThreshold', 0.01);
    mirplay(audioData);
    
    % Process the audio data here
    disp('Audio played');
    % Example: Print the file name and the number of samples
    % fprintf('File: %s, Number of samples: %d\n', files(i).name, size(audioData, 1));
end

% Randomly select four audio files
% randomFiles = dir(fullfile(folderPath, '*3*.wav'));

% randomFiles = datasample(files, 4, 'Replace', false);

% % Loop through each randomly selected file
% for i = 1:numel(randomFiles)
%     % Read the audio data and trim the pseudo silence at the end
%     % Read the audio data
%     filePath = fullfile(folderPath, randomFiles(i).name);
    
%     % % Determine the trimming threshold
%     % last100ms = audioData(end - round(0.5 * sampleRate) + 1:end);
%     % mediumRMS = rms(audioData);
%     % last100msRMS = rms(last100ms);
%     % %t = last100msRMS / mediumRMS;
    
%     t=0.01;
%     % Trim the audio data
%     audioData = miraudio(filePath,'TrimEnd','TrimThreshold', t);
%     sr = get(audioData, 'Sampling');
%     sr = sr{1};
%     audioData = mirgetdata(audioData, 'Data');
    
%     % Create a subplot for the original audio file
%     subplot(4, 2, 2*i-1);
%     plot(audioData);
%     title(filePath);
    
%     % Create a subplot for the trimmed audio file
    
%     [audioData, sampleRate] = audioread(filePath);
%     subplot(4, 2, 2*i);
%     plot(audioData);
%     title('Original Audio');
% end


