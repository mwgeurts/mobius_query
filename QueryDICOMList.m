function [session, list] = QueryDICOMList(varargin)
% QueryDICOMList returns the list of DICOM patient data stored in Mobius3D.
% The function requires an active Python session, created from
% EstablishConnection, and a server name. It will then query the Mobius3D
% server and return the list of patient IDs and names for which DICOM RT 
% plan data exists.
%
% The following variables are required for proper execution: 
%   varargin: cell array of strings, with odd indices of 'server' and 
%       'session' followed by a string containing the server name/IP
%       and Python session (created from EstablishConnection), 
%       respectively. The server input is stored persistently and is not 
%       required if this function is called again.
%
% The following variables are returned upon succesful completion:
%   session: Python session object
%   list: cell array of structures containing css_id, patient_name, and
%       patient_id fields
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%   [session, list] = QueryDICOMList('server', '10.105.1.12', 'session', ...
%       session);
%   
%   % Loop through data, printing the patient ID
%   for i = 1:length(list)
%       fprintf('%s\n', list{i}.patient_id);
%   end
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
persistent server;

% Start timer
tic;

% Loop through input arguments
for i = 1:2:nargin
    
    % Store server variables
    if strcmpi(varargin{i}, 'server')
        server = varargin{i+1};
    elseif strcmpi(varargin{i}, 'session')
        session = varargin{i+1};
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

% Attempt to connect to Mobius3D server
try
    
    % Execute get function of Python session object to retrieve list of 
    % DICOM patients from Mobius3D
    result = session.get(['http://', server, '/_dicom/patients']);

    % Retrieve the JSON results
    j = result.json();
    
    % Execute loadjson() to convert the JSON list to a MATLAB structure
    s = loadjson(char(py.json.dumps(j)));
    
    % Retrieve cell array
    if isfield(s, 'patients')
        list = s.patients;
    
    % If the field does not exist, an error may have occured
    else
        
        % Log an error
        if exist('Event', 'file') == 2
            Event('An error occurred returning the DICOM list', 'ERROR');
        else
            error('An error occurred returning the DICOM list');
        end
    end
    
    % If the above function calls work, log a success message
    if exist('Event', 'file') == 2
        Event(sprintf(['DICOM list retrieved successfully containing %i ', ...
            'entries in %0.3f seconds'], length(list), toc));
    end

% Otherwise, if an error occurred, a connection was not successful
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['The request to ', server, ' failed.'], 'ERROR');
    else
        error(['The request to ', server, ' failed.']);
    end
end

% Clear temporary variables
clear server result j s;