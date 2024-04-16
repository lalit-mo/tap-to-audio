%% [DONE] Make sure midi is present 
%% [DONE] First audio is sometimes not fully played 12, 35, 40
%% [DONE] SOme audio contain high frequency
%% [DONE] Assesss audio files of unneccessary silence
%% Refine instructions further for clarity

% Initial Setup for psychWindow
sca;
close all;
clear;

PsychDefaultSetup(2);
rng("shuffle");
Screen('Preference', 'SkipSyncTests', 2);
screenNumber = max(Screen('Screens'));

%-------COLORS-------
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white * 0.75;
darkGrey = grey * 0.8;

red = [white 0 0];
green = [0 white 0];
blue = [0 0 white];

%----------------------------------------------------------------------
%           Login prompt and open file for writing data out
%----------------------------------------------------------------------
prompt = {'Participant ID', 'Group'};
defaults = {'0', 'Control'};
answer = inputdlg(prompt, 'Participant Information', 1, defaults);
[participantID, group] = deal(answer{:});
outputFileName = [participantID '_' group '.xlsx'];

%Check if device present else 
if exist(outputFileName) == 2 % Check to avoid accidental overwriting of files
    fileIssue = inputdlg('File already exists, Overwrite? y/n:', 'Warning', 1, {'n'});
    fileproblem = deal(fileIssue{:});
    if isempty(fileproblem) || fileproblem == 'n'
        disp('File not saved. Ending experiment.');
        sca;
        return;
    elseif fileproblem == 'y'
        disp('File will be overwritten.');
    end
end

% Prepare MIDI device
ioDevices = mididevinfo;

treatment = false;
nRepeat = 15;
if strcmpi(group, 'treatment')
    treatment = true;
elseif strcmpi(group, 'test')
    treatment = true;
    nRepeat = 4;
end
if treatment && isempty(ioDevices.input)
    disp('No MIDI input devices found. Exiting...');
    sca;
    return;
end

disp(group);

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey);
Screen('Flip', window);
smallTextSize = 30;
textSize = 40;
HideCursor;

% Query the inter-frame-interval. This refers to the 
% minimum possible time between drawing to the screen
ifi = Screen('GetFlipInterval', window);
% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

Screen('TextSize', window, textSize);
% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

topPrioritylevel = MaxPriority(window);
Priority(topPrioritylevel);

[xCenter, yCenter] = RectCenter(windowRect);
% Our scale will span a proportion of the screens x dimension
scaleLengthPix = screenYpixels / 1.5;
scaleHLengthPix = scaleLengthPix / 2;

% Coordiantes of the scale left and right ends
leftEnd = [xCenter - scaleHLengthPix yCenter];
rightEnd = [xCenter + scaleHLengthPix yCenter];
scaleLineCoords = [leftEnd' rightEnd'];

% Scale line thickness
scaleLineWidth = 10;

% intra-loop pause time in seconds and frames
pauseTimeSecs = 0.5;
% might not need this as we're dealing with audio only.
% pauseTimeFrames = round(fixTimeSecs / ifi);

% inter trial interval time in seconds and frames
% trialTimeSecs = 5; % Not Needed
% trialTimeFrames = round(trialTimeSecs / ifi); % Not Needed


%----------------------------------------------------------------------
%                       Keyboard information
%----------------------------------------------------------------------

% Define the keyboard keys that are listened for. We will be using the MIDI
% pad as response key for the task and the escape key as a exit/reset key.
escapeKey = KbName('ESCAPE');
SetMouse(xCenter, yCenter, window);
% To Do: Define response key for MIDI pad

%----------------------------------------------------------------------
%                     Likert scale parameters
%----------------------------------------------------------------------
numScalePoints = 7;
xPosScalePoints = linspace(xCenter - scaleHLengthPix, xCenter + scaleHLengthPix, numScalePoints);
yPosScalePoints = repmat(yCenter, 1, numScalePoints);
xyScalePoints = [xPosScalePoints; yPosScalePoints];
sliderLabels = {'Speech', 'Song'};
% Get bounding boxes for the scale end label text
textBoundsAll = nan(2, 4);
for i = 1:2
    [~, ~, textBoundsAll(i, :)] = DrawFormattedText(window, sliderLabels{i}, 0, 0, white);
end

% Width and height of the scale end label text bounding boxs
textWidths = textBoundsAll(:, 3)';
halfTextWidths = textWidths / 2;
textHeights = range([textBoundsAll(:, 2) textBoundsAll(:, 4)], 2)';
halfTextHeights = textHeights / 2;

% Do the same for the numbers that we will put on the buttons. Here we
% toggle first to the smaller text size we will be using for the labels for
% the buttons then reinstate the standard text size
Screen('TextSize', window, smallTextSize);
numBoundsAll = nan(numScalePoints, 4);
for i = 1:numScalePoints
    [~, ~, numBoundsAll(i, :)] = DrawFormattedText(window, num2str(i), 0, 0, white);
end
Screen('TextSize', window, textSize);

% Width and height of the scale number text bounding boxs
numWidths = numBoundsAll(:, 3)';
halfNumWidths = numWidths / 2;
numHeights = [range([numBoundsAll(:, 2) numBoundsAll(:, 4)], 2)]';
halfNumHeights = numHeights / 2;

% Dimensions of the dots on our scale
dim = 40;
hDim = dim / 2;

% Position of the scale text so that it is at the ends of the scale but does
% not overlap with the scales points. Make sure it is also
% centered in the y dimension of the screen. To do this we used the bounding
% boxes of the text, plus a little gap so that the text does not completely
% edge the slider toggle in the x dimension
textPixGap = 50;
leftTextPosX = xCenter - scaleHLengthPix - hDim - textWidths(1) - textPixGap;
rightTextPosX = xCenter + scaleHLengthPix + hDim + textPixGap;

leftTextPosY = yCenter + halfTextHeights(1);
rightTextPosY = yCenter + halfTextHeights(2);

% The numbers are aligned to be directly under the relevent button (tops of
% their bounding boxes "numShiftDownPix" below the button y coordinate, and
% aligned laterally such that the centre of the text bounding boxes aligned
% with the x coordinate of the button
numShiftDownPix = 80;
xNumText = xPosScalePoints - halfNumWidths;
yNumText = yPosScalePoints + halfNumHeights + numShiftDownPix;

% Colors for the likert scale buttons when pressed (blue to red)
br = linspace(0, 1, numScalePoints);
bg = zeros(1, numScalePoints);
bb = abs(1 - br);
bRGB = [br; bg; bb];

% Number of frames to wait before updating the screen
waitframes = 1; % Not needed

% Sync us and get a time stamp. We blank the window first to remove the
% text that we drew to get the bounding boxes.
Screen('FillRect', window, grey);
Screen('Flip', window);

%---------------------------------------------------
%                   Main Experiment
%---------------------------------------------------

% Prepare audio files
folderPath = './data/';
% Get a list of all the mp3 files in the folder
fileList = dir(fullfile(folderPath, '*.wav'));
allFiles = [];
for i = 1:numel(fileList)
    allFiles = [allFiles {fullfile(folderPath, fileList(i).name)}];
end

catchTrials = {'catch_trial_1.wav', 'catch_trial_3.wav', 'catch_trial_5.wav'};

if strcmpi(group, 'test')
    allFiles = allFiles(1:4);
end
% Prepare shuffled array of trials as stimuli set
nTrials = numel(allFiles);
trialOrder = randperm(nTrials);

%----------------------------------------------------------------------
%                             Procedure
%----------------------------------------------------------------------

% First, the participant will be asked to tap spontaneously on the MIDI pad
% three times in the practice session. Main Session requires participants to
% listen to an audio stimuli while simultaneously tapping to the rhythm of 
% audio stimuli on the MIDI pad. The stimulus onset time and midi responses
% are to be accurately recorded. The participant will be asked to rate the stimuli
% on a likert scale between speech and song and how easy it was to tap to the audio.
% This will occur at first presentation, after 10 repetitions and after 20 repetitions.


% Display instructions based on group
% -----------------------------------
Screen('TextSize', window, smallTextSize);
if treatment
    % Display treatment instructions
    DrawFormattedText(window, ['Thank you for joining our experiment!\n\n' ...
    'You will listen to some audio samples and tell us if they sound like speech or song.\n\n' ...
    'After hearing each sample, you will hear it repeated a few times.\n\n' ...
    'During these repetitions, tap along with any beat/rhythm you hear on the MIDI pad O.\n' ...
    'A cross (+) will be shown while you listen.\n\n' ...
    'After the repetitions, you will rate the samples again\nbased on whether they sound like speech or song.\n\n' ...
    'Before the Main experiment, we will record your spontaneous tapping rate first.\n\n\n' ...
    'Feel free to ask if you need any help.\n' ...
    '\n\n' ...
    'Press the <ENTER> key to continue.'], 'center', 'center', black);
else
    % Display control instructions
    DrawFormattedText(window, ['Thank you for joining our experiment!\n\n' ...
    'You will listen to some audio samples and tell us if they sound like speech or song.\n\n' ...
    'After hearing each sample, you will hear it repeated a few times.\n\n' ...
    'A cross (+) will be shown while you listen.\n\n' ...
    'After the repetitions, you will rate the samples again\nbased on whether they sound like speech or song.\n\n' ...
    '\nFeel free to ask if you need any help.\n' ...
    '\n\n' ...
    'Press the <ENTER> key to continue.'], 'center', 'center', black);
end
% Flip to the screen
Screen('Flip', window);
% Wait for a key press
KbStrokeWait(-1);
Screen('TextSize', window, textSize);
%----------------------------------------------------------------------
%                       Data Preparation
%----------------------------------------------------------------------
% Initialize empty arrays for data
trialNumbers = [];
phases = [];
repetitions = [];
audioStarts = [];
deviceStarts = [];
midiMessages = {};
ratings = [];
tapRatings = [];
audioNames = [];

% Run spontaneous tapping recording
% ---------------------------------

% TO DO - TO DO - TO DO - TO DO
if treatment
    DrawFormattedText(window, 'Spontaneous Tapping\n\nBe ready to tap on the MIDI pad\n\n Press ANY KEY when ready.', 'center', 'center', black);
    Screen('Flip', window);
    % Define the duration of the silent audio in seconds
    duration = 6;
    % Define the sampling frequency (44.1 kHz is a common choice)
    fs = 44100;
    % Generate the silent audio
    silent_audio = zeros(round(duration * fs), 1);
    player = audioplayer(silent_audio, fs);
    start = 1;
    stop = numel(silent_audio) - (0.5 * player.SampleRate);
    KbStrokeWait(-1);
    for pracTrial = 1:2
        % Display the rhombus to signal for the participant to tap
        DrawFormattedText(window, 'Start tapping on the pad now!', 'center', 'center', black);
        Screen('Flip', window);
        % Record spontaneous tapping from midi device
        [midiMsgs, audioStart, deviceStart] = syncMIDIData(true, ioDevices, player, duration);

        % Save spontaneous tapping timestamps to experiment object
        trialNumbers = [trialNumbers; 0];
        phases = [phases; pracTrial];
        repetitions = [repetitions; 0];
        audioStarts = [audioStarts; audioStart];
        deviceStarts = [deviceStarts; deviceStart];
        midiMessages = [midiMessages; midiMsgs];
        ratings = [ratings; 0];
        tapRatings = [tapRatings; 0];
        audioNames = [audioNames; {'SpontaneousTapping'}];

        if pracTrial == 1
            DrawFormattedText(window, 'Great! Let us do that one more time. \n\n Press ANY KEY when ready.', 'center', 'center', black);
            Screen('Flip', window);
            KbStrokeWait(-1);
        end
    end
    DrawFormattedText(window, 'Great! You have completed Spontaneous Tapping.', 'center', 'center', black);
    Screen('Flip', window);
    WaitSecs(3);
end
%----------------------------------------------------------------------
%                       Experimental loop
%----------------------------------------------------------------------
DrawFormattedText(window, 'Beginning the main experiment...', 'center', 'center', black);
Screen('Flip', window);
WaitSecs(3);
for trial = 1:nTrials
    [mx, my, buttons] = GetMouse(window);
    HideCursor;
    if trial == 1

        % DRAWING the instructions
        DrawFormattedText(window, ['At the start of each trial we will play the audio once, \nfor you to provide your initial perception of audio.\n\n' ...
                                    'Press ANY KEY to begin.'], 'center', 'center', black);
        % Flip to the screen
        Screen('Flip', window);
        % Wait for a key press
        KbStrokeWait(-1);
    else
        DrawFormattedText(window, ['Starting Next Trial...'], 'center', 'center', black);
        Screen('Flip', window);
        WaitSecs(3);
    end
    
    % DRAWING + Flip the screen grey
    Screen('FillRect', window, grey);
    Screen('Flip', window);
    
    t=0.01;
    afk = trialOrder(trial);
    audioName = allFiles{afk};
    audioData = miraudio(audioName,'TrimEnd','TrimThreshold', t);
    fs = get(audioData, 'Sampling');
    fs = fs{1};
    audioData = mirgetdata(audioData, 'Data');
    disp([audioName fs]);
    % TO DO: Filter upto 5000Hz only
    cutoff = 5000; % Cutoff frequency in Hz
    normCutoff = cutoff / (fs / 2); % Normalized cutoff frequency
    [b, a] = butter(6, normCutoff, 'low'); % 6th order Butterworth low-pass filter
    
    % Apply the low-pass filter to the audio data
    audioData = filter(b, a, audioData);

    % Play audio once.
    player = audioplayer(audioData, fs);
    duration = numel(audioData) / fs;
    % start = 1;
    % stop = numel(audioData); % - (0.5 * player.SampleRate);
    
    % ------------------------Fixation Point---------------------------------------------
    % fixationPointDuration = numel(audioData) / fs; % Duration of fixation point display in seconds
    fixCrossDimPix = 40;
    % Now we set the coordinates (these are all relative to zero we will let
    % the drawing routine center the cross in the center of our monitor for us)
    xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
    yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
    allCoords = [xCoords; yCoords];
    % Set the line width for our fixation cross
    lineWidthPix = 4;
    % Draw the fixation cross in white, set it to the center of our screen and set good quality antialiasing
    Screen('DrawLines', window, allCoords,lineWidthPix, white, [xCenter yCenter], 2);
    % Flip to the screen
    Screen('Flip', window);
    % playblocking(player, [start_p, stop_p]);
    [midiMsgs, audioStart, deviceStart] = syncMIDIData(false, ioDevices, player, duration);
    
    % Take response on likert scales
    % Display radio button likert scale to rate the audio between speech and song
    phaseRating = runLikertScaleAnimation(window, scaleLineCoords, sliderLabels, xyScalePoints, bRGB, dim, numScalePoints, waitframes, ifi, xNumText, yNumText);
    
    % Populate first phase data
    trialNumbers = [trialNumbers; trial];
    phases = [phases; 1];
    repetitions = [repetitions; 0];
    audioStarts = [audioStarts; audioStart];
    deviceStarts = [deviceStarts; deviceStart];
    midiMessages = [midiMessages; midiMsgs];
    disp([audioName, class(audioName)]);
    ratings = [ratings; phaseRating];
    tapRatings = [tapRatings; 0];
    audioNames = [audioNames; {audioName}];

    % DRAWING + flip to grey after likert scale of first presentation
    Screen('FillRect', window, grey);
    Screen('Flip', window);
    
    if ~ismember(audioName, catchTrials)
        % loop audio nRepeat x 2 times while also recording tapping responses
        % To Do: Repetition phase instructions
        for phase = 2:3
            % To Do: Wait before starting the next phase
            countDown(treatment, window, ifi, black); 
            tic;
            for nPlay = 1:nRepeat
                
                % ------------------------Fixation Point---------------------------------------------
                % fixationPointDuration = numel(audioData) / fs; % Duration of fixation point display in seconds
                fixCrossDimPix = 40;
                % Now we set the coordinates (these are all relative to zero we will let
                % the drawing routine center the cross in the center of our monitor for us)
                xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
                yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
                allCoords = [xCoords; yCoords];
                % Set the line width for our fixation cross
                lineWidthPix = 4;
                % Draw the fixation cross in white, set it to the center of our screen and set good quality antialiasing
                Screen('DrawLines', window, allCoords,lineWidthPix, white, [xCenter yCenter], 2);
                % Flip to the screen
                Screen('Flip', window);
                % To Do: Record spontaneous tapping from midi device
                
                % Play audio
                % playblocking(player, [start, stop]);
                [midiMsgs, audioStart, deviceStart] = syncMIDIData(treatment, ioDevices, player, duration);

                % Populate current repetition data
                trialNumbers = [trialNumbers; trial];
                phases = [phases; phase];
                repetitions = [repetitions; nPlay];
                audioStarts = [audioStarts; audioStart];
                deviceStarts = [deviceStarts; deviceStart];
                midiMessages = [midiMessages; midiMsgs];
                audioNames = [audioNames; audioName];

            end
            
            % 2. To Do: Display likert scale for participant to rate the audio between speech and song
            phaseRating = runLikertScaleAnimation(window, scaleLineCoords, sliderLabels, xyScalePoints, bRGB, dim, numScalePoints, waitframes, ifi, xNumText, yNumText);
            
            % Populate rating for current phase
            ratings = [ratings; repmat(phaseRating, nRepeat, 1)];
            tapRatings = [tapRatings; repmat(0, nRepeat, 1)];

            % 3. To Do: Another Likert scale to rate how easy was it to tap to the audio
            % Save all responses to Session object for looped audio
            
            % DRAWING + flip after repetition phase
            Screen('FillRect', window, grey);
            Screen('Flip', window);
        end
    end   
    if trial == 15
        DrawFormattedText(window, 'Take a small break before continuing.\n\n Press any key when ready', 'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait(-1);
    end
end

%----------------------------------------------------------------------
%                       Save Data
%----------------------------------------------------------------------

data = table(trialNumbers, phases, repetitions, audioNames, audioStarts, deviceStarts, midiMessages, ratings, tapRatings, 'VariableNames', {'Trial', 'Phase', 'Repetition', 'Audio', 'AudioStart', 'DeviceStart', 'MIDIData', 'Rating', 'TapRating'});
writetable(data, outputFileName);
DrawFormattedText(window, 'Thank you for participating in this experiment.', 'center', 'center', black);
Screen('Flip', window);
WaitSecs(5);
Screen('Flip', window);
disp('Experiment Completed');
close all;
sca;

function posCircle = runLikertScaleAnimation(window, scaleLineCoords, sliderLabels, xyScalePoints, bRGB, dim, numScalePoints, waitframes, ifi, xNumText, yNumText)
    % Initialize variables
    posCircle = [];
    ShowCursor('Hand');

    % Set text properties
    % textSize = Screen('TextSize', window);
    % smallTextSize = textSize * 0.5;
    screenYpixels = RectHeight(Screen('Rect', window));
    leftTextPosX = xyScalePoints(1, 1) - dim * 3;
    leftTextPosY = xyScalePoints(2, 1) - dim * 2;
    rightTextPosX = xyScalePoints(1, end) - dim;
    rightTextPosY = xyScalePoints(2, end) - dim * 2;

    % Colors
    white = [1 1 1];
    blue = [0 0 1] * 0.75;
    red = [1 0 0] * 0.75;
    grey = white * 0.75;
    darkGrey = grey / 2;
    black = [0 0 0];

    % Loop the animation until a key is pressed
    while true
        % Get the current position of the mouse
        [mx, my, buttons] = GetMouse(window);

        % Check if the mouse is within any of the circles
        inCircles = sqrt((xyScalePoints(1, :) - mx).^2 + (xyScalePoints(2, :) - my).^2) < dim;

        % Identify the index of the circle if we are in one and get its coordinates
        weInCircle = sum(inCircles) > 0;
        if weInCircle
            [~, posCircle] = max(inCircles);
            coordsCircle = xyScalePoints(:, posCircle);
        else
            posCircle = [];
            coordsCircle = [];
        end

        % Draw the scale line
        Screen('DrawLines', window, scaleLineCoords, 2, grey);

        % Text for the ends of the slider
        DrawFormattedText(window, sliderLabels{1}, leftTextPosX, leftTextPosY, blue);
        DrawFormattedText(window, sliderLabels{2}, rightTextPosX, rightTextPosY, red);

        % Draw the title for the slider
        DrawFormattedText(window, 'What does the audio feel like?', 'center', screenYpixels * 0.25, black);

        % If we are in a circle, identify it with a frame
        if weInCircle
            Screen('DrawDots', window, coordsCircle, dim * 1.2, white, [], 2);
        end

        % Draw the likert scale points
        Screen('DrawDots', window, xyScalePoints, dim, darkGrey, [], 2);

        % If we are clicking a circle, highlight it
        if weInCircle && sum(buttons) > 0
            % Highlight the pressed button
            Screen('DrawDots', window, coordsCircle, dim * 1.2, bRGB(:, posCircle), [], 2);
            break; % Exit the loop when a circle is clicked
        end

        % Draw a white dot where the mouse cursor is
        Screen('DrawDots', window, [mx my], 10, white, [], 2);
        % Draw the numbers for the scale: First toggling to the smaller text
    % size and then reverting back to the standard text size

        for thisNum = 1:numScalePoints
            DrawFormattedText(window, num2str(thisNum), xNumText(thisNum), yNumText(thisNum), black);
        end
        % Flip to the screen
        Screen('Flip', window);
    end
end

function [midiMsgs, audioStart, deviceStart] = syncMIDIData(record, ioDevices, player, duration)
    %Initialize MIDI device

    % Start audio playback asynchronously
    audioStart = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
    play(player);
    midiMsgs = {false};
    deviceStart = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
    if record == true
        deviceStart = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
        device = mididevice(ioDevices.input(1).ID);
        tic;
        while toc < duration
            % wait for the duration of audio
        end
        midiData = midireceive(device);
        midiMsgs = pasrseMidi(midiData);
        clear device;
    else
        tic;
        while toc < duration
            % wait for the duration of audio
        end
    end
    stop(player);
end 

function midiMessages = pasrseMidi(msg)
    midiMessages = {false};
    if ~isempty(msg)
        midiMessages = [];
        for i = 1:numel(msg)
            
            if (msg(i).Type == midimsgtype.NoteOn || msg(i).Type == midimsgtype.NoteOff)
                midiMsg = [string(msg(i).Type), ...
                            string(msg(i).Velocity), ...
                            string(msg(i).Timestamp)];
                midiMsg = strjoin(midiMsg, ',');
                midiMessages = [midiMessages midiMsg];
            end
        end
        midiMessages = strjoin(midiMessages, '\n');
    end
end

function countDown(treatment, window, ifi, color)
    presSecs = 1;
    waitframes = round(presSecs / ifi);

    % Starting number
    currentNumber = 3;

    % Maximum priority level
    topPriorityLevel = MaxPriority(window);
    Priority(topPriorityLevel);

    % Flip to the vertical retrace rate
    vbl = Screen('Flip', window);

    % We use a while loop to count down. On each iteration of the loop we use a
    % waitframes value greater than 1 so that each number is presented for one
    % second
    while currentNumber >= 0

        % Convert our current number to display into a string
        numberString = num2str(currentNumber);

        % Draw our number to the screen
        DrawFormattedText(window, numberString, 'center', 'center', color);
        DrawFormattedText(window, 'Repeating in:\n\n', 'center', 'center', color);
        if treatment
            DrawFormattedText(window, '\n\nBe ready to tap', 'center', 'center', color);
        end


        % Flip to the screen
        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);

        % Increment the number
        currentNumber = currentNumber - 1;
    end
end