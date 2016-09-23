function [session, list] = GetAnonymizedDICOM(varargin)
% GetAnonymizedDICOM downloads anonymized DICOM files for a patient list
% incuding CT, RT Structure Set, RT Plan, and RT Dose files. The function 
% requires an active Python session, created from EstablishConnection, a 
% server name, list of patient IDs (this list can be generated from
% QueryDICOMList), and destination folder, which can be either a relative 
% or absolute path. The DICOM files will be unzipped and saved to the 
% destination folder in a unqiue subfolder generated from the Mobius3D
% server version and current date/time.
%
% The DICOM files are anonymized by Mobius3D prior to downloading. Mobius3D
% retains UID references between the DICOM files, allowing them to be
% re-submitted to Mobius3D or an RT PACS system.
%
% The following variables are required for proper execution: 
%   varargin: cell array of strings, with odd indices of 'server', 
%       'session', 'list', and 'folder' followed by a string containing the 
%       server name/IP, Python session (created from EstablishConnection), 
%       cell array of structures containing css_id fields, and a string 
%       containing a folder path, respectively. The server and folder 
%       inputs are stored persistently and are not required if this 
%       function is called again.
%
% The following variables are returned upon succesful completion:
%   session: Python session object
%   list: cell array of structures containing 'css_id', 'subfolder', and
%       'files' fields
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%   [session, list] = QueryDICOMList('server', '10.105.1.12', 'session', ...
%       session);
%
%   % Download all DICOM files to the folder /tmp
%   [session, list] = GetAnonymizedDICOM('server', '10.105.1.12', ...
%       'session', session, 'list', list, 'folder', '/tmp');
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2016 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Declare persistent variables
persistent server folder;

% Start timer
tic;

% Loop through input arguments
for i = 1:2:nargin
    
    % Store server variables
    if strcmpi(varargin{i}, 'server')
        server = varargin{i+1};
    elseif strcmpi(varargin{i}, 'session')
        session = varargin{i+1};
    elseif strcmpi(varargin{i}, 'list')
        list = varargin{i+1};
    elseif strcmpi(varargin{i}, 'folder')
        folder = varargin{i+1};
    end
end

% If server variables are empty, throw an error
if exist('server', 'var') == 0 || isempty(server) || ...
        exist('session', 'var') == 0 || isempty(session)

    % Log error
    if exist('Event', 'file') == 2
        Event(['Server information is missing. You must provide server, ', ...
            'and session inputs to this function'], 'ERROR');
    else
        error(['Server information is missing. You must provide server, ', ...
            'and session inputs to this function']);
    end 
end

% If the list variable is empty, throw an error
if exist('list', 'var') == 0 || isempty(list) 

    % Log error
    if exist('Event', 'file') == 2
        Event(['List input is missing. You must provide a cell array of ', ...
            'structures containing patient_id fields to this function.'], ...
            'ERROR');
    else
        error(['List input is missing. You must provide a cell array of ', ...
            'structures containing patient_id fields to this function.']);
    end 
end

% If the folder variable is empty, or is not valid throw an error
if exist('folder', 'var') == 0 || isempty(folder) || ...
        exist(folder, 'file') ~= 7 

    % Log error
    if exist('Event', 'file') == 2
        Event(['Folder input is missing or invalid. You must provide a ', ...
            'valid folder string to this function.'], 'ERROR');
    else
        error(['Folder input is missing or invalid. You must provide a ', ...
            'valid folder string to this function.']);
    end 
end

% Add jsonlab folder to search path
addpath('./jsonlab');

% Check if MATLAB can find loadjson
if exist('loadjson', 'file') ~= 2
    
    % If not, throw an error
    if exist('Event', 'file') == 2
        Event(['The jsonlab/ submodule is missing. Download it from the ', ...
            'MathWorks.com website'], 'ERROR');
    else
        error(['The jsonlab/ submodule is missing. Download it from the ', ...
            'MathWorks.com website']);
    end
end

% Loop through each list item
for i = 1:length(list)

    % If a patient_id field does not exist, warn the user
    if ~isfield(list{i}, 'patient_id')

        % Throw a warning
        if exist('Event', 'file') == 2
            Event(sprintf(['List item %i is missing a patient_id field ', ...
                'and was skipped'], i), 'WARN');
        else
            warning(['List item %i is missing a patient_id field ', ...
                'and was skipped'], i);
        end

        % Skip to the next list item
        continue;
    end
    
    % Log parsing
    if exist('Event', 'file') == 2
        Event(['Creating anonymized compressed file for ', ...
            list{i}.patient_id]);
    end

    % Execute get function of Python session object to initiate the 
    % DICOM anonymization function in Mobius3D
    try
        r = session.get(['http://', server, '/_dicom/anon/create/', ...
            list{i}.patient_id]);
    catch

        % If get fails, throw a warning
        if exist('Event', 'file') == 2
            Event(sprintf(['Mobius3D could not generate DICOM files for ', ...
                '%s, or the server is unavailable.'], list{i}.patient_id), ...
                'WARN');
        else
            warning(['Mobius3D could not generate DICOM files for ', ...
                '%s, or the server is unavailable.'], list{i}.patient_id);
        end

        % Skip to the next list item
        continue;
    end

    % Retrieve the JSON results
    j = r.json();

    % Execute loadjson() to convert the JSON list to a MATLAB structure
    s = loadjson(char(py.json.dumps(j)));

    % Store the returned file_str
    list{i}.folder = regexprep(s.file_str, '\.zip$', '');

    % Make a subfolder based on the file_str response
    try
        mkdir(fullfile(folder, '/', list{i}.folder));
    catch

        % If mkdir fails, throw a warning
        if exist('Event', 'file') == 2
            Event(sprintf('Subfolder %s could not be created.', ...
                fullfile(folder, '/', list{i}.folder)), 'WARN');
        else
            warning('Subfolder %s could not be created.', ...
                fullfile(folder, '/', list{i}.folder));
        end

        % Skip to the next list item
        continue;
    end

    % Once a response is returned, the anonymized .zip file is ready to
    % be downloaded to a temporary file
    try
        
        % Generate a temporary file name to store the .zip file
        t = [tempname, '.zip'];
        
        % Create a Python file handle to the temp file
        f = py.open(t, 'wb');
        
        % Log parsing
        if exist('Event', 'file') == 2
            Event(['Downloading compressed file for ', list{i}.patient_id, ...
                ' to ', t]);
        end
        
        % Download the .zip file from the Mobius3D server to the temp file
        f.write(session.get(['http://', server, ...
            '/_dicom/anon/download/', s.file_str]).content);
        
        % Close the temporary file
        f.close();
        
        % Log parsing
        if exist('Event', 'file') == 2
            Event(['Uncompressing ', t, ' to ', folder]);
        end
        
        % Unzip the temp file into the destination folder, storing the
        % unzipped file names
        list{i}.files = unzip(t, folder);
        
    catch

        % If the above code fails, throw a warning
        if exist('Event', 'file') == 2
            Event(sprintf('Error downloading the file %s.', ['http://', ...
                server, '/_dicom/anon/download/', s.file_str]), 'WARN');
        else
            warning('Error downloading the file %s.', ['http://', ...
                server, '/_dicom/anon/download/', s.file_str]);
        end

        % Skip to the next list item
        continue;
    end
end

% Log a success message
if exist('Event', 'file') == 2
    Event(sprintf(['Successfully downloaded %i patients to %s', ...
        ' in %0.3f seconds'], length(list), folder, toc));
end

% Clear temporary variables
clear r i j s t f;