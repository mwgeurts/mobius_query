function [session, rtplan] = GetRTPlan(varargin)
% GetRTPlan retrieves the DICOM RT Plan from Mobius3D for a given plan
% check or SOP instance UID. Mobius3D returns the RT plan as a JSON file,
% which in turn is converted into a MATLAB structure. Note that binary tags
% will be excluded in the resulting structure.
%
% The following variables are required for proper execution: 
%   varargin: cell array of strings, with odd indices of 'server',
%       'session', and either 'plan' or 'sopinst' followed by strings 
%       containing the server name/IP, Python session, and plan structure
%       (obtained from MatchPlanCheck) or SOP instance UID
%
% The following variables are returned upon succesful completion:
%   session: Python session object
%   rtplan: structure containing the RT plan, with DICOM field names in the
%       format GXXXXEXXXX, where GXXXX and EXXXX refer to the Group and
%       Element DICOM tags, respectively
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%
%   % Retrieve RT plan for matched plan check
%   [session, rtplan] = GetRTPlan('server', '10.105.1.12', 'session', ...
%       session, 'sopinst', 'plansopuid');
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

% Initialize SOP instance UID
sop = '';

% Loop through input arguments
for i = 1:2:nargin
    
    % Store server variables
    if strcmpi(varargin{i}, 'server')
        server = varargin{i+1};
    elseif strcmpi(varargin{i}, 'session')
        session = varargin{i+1};
    end
    
    % Store RT plan SOP instance UID
    if strcmpi(varargin{i}, 'plan') && isfield(varargin{i+1}, 'settings')
        sop = varargin{i+1}.settings.plan_dicom.sopinst;
    elseif strcmpi(varargin{i}, 'sopinst')
        sop = varargin{i+1};
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

% Verify SOP instance was provided
if isempty(sop)
    
    % Log error
    if exist('Event', 'file') == 2
        Event(['Either a plan check JSON structure or RT Plan SOP ', ...
            'instance UID must be provided to this function'], 'ERROR');
    else
        error(['Either a plan check JSON structure or RT Plan SOP ', ...
            'instance UID must be provided to this function']);
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

% Log start
if exist('Event', 'file') == 2
    Event(sprintf('Retrieving RT Plan UID %s', sop));
end

% Attempt to connect to Mobius3D server
try
    
    % Retrieve DICOM RT Plan in JSON format
    r = session.get(['http://', server, '/_dicom/view/', sop]);

    % Log status
    if exist('Event', 'file') == 2
        Event(sprintf('RT Plan retrieved in %0.3f seconds', ...
            double(r.elapsed.seconds) + ...
            double(r.elapsed.microseconds)/1e6));
    end

    % Log parsing
    if exist('Event', 'file') == 2
        Event('Parsing JSON into MATLAB structure return argument');
    end

% Otherwise, if an error occurred, a connection was not successful
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['The request to ', server, ' failed'], 'ERROR');
    else
        error(['The request to ', server, ' failed']);
    end
end

% If a valid RT plan object was returned
if length(char(py.json.dumps(r.json()))) > 2

    % Replace all tag names with their Group/Element codes, using the
    % format GXXXXEXXXX, and convert to MATLAB structure
    rtplan = loadjson(regexprep(char(py.json.dumps(r.json())), ...
        '"\(([0-9a-z]+), ([0-9a-z]+)\)[^"]+"', '"G$1E$2"'));
else
    
    % Return empty rtplan
    rtplan = [];
    
    % Log an error
    if exist('Event', 'file') == 2
        Event('The returned RT Plan object is empty', 'WARN');
    else
        warning('The returned RT Plan object is empty');
    end
end

% Clear temporary variables
clear sop r i;
