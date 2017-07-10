function [session, rtplan] = GetRTPlan(session, varargin)
% GetRTPlan retrieves the DICOM RT Plan from Mobius3D for a given plan
% check or SOP instance UID. Mobius3D returns the RT plan as a JSON file,
% which in turn is converted into a MATLAB structure. Note that binary tags
% will be excluded in the resulting structure.
%
% The following variables are required for proper execution: 
%
%   session: Python session object created by EstablishConnection
%   varargin: cell array of strings, with first index of either 'plan' or 
%       'sopinst' followed by the plan structure (obtained from 
%       MatchPlanCheck) or SOP instance UID string
%
% The following variables are returned upon succesful completion:
%
%   session: Python session object created by EstablishConnection
%   rtplan: structure containing the RT plan, with DICOM field names
%       defined using the format of the default MATLAB DICOM dictionary
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%
%   % Retrieve RT plan for matched plan check
%   [session, rtplan] = GetRTPlan(session, 'sopinst', 'plansopuid');
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
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

% Start timer
tic;

% Initialize SOP instance UID
sop = '';

% Loop through input arguments
for i = 1:2:nargin
    
    % Store RT plan SOP instance UID
    if strcmpi(varargin{i}, 'plan') && isfield(varargin{i+1}, 'settings')
        sop = varargin{i+1}.settings.plan_dicom.sopinst;
    elseif strcmpi(varargin{i}, 'sopinst')
        sop = varargin{i+1};
    end
end

% If server variables are empty, throw an error
if isempty(session)

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

% Log start
if exist('Event', 'file') == 2
    Event(sprintf('Retrieving RT Plan UID %s', sop));
end

% Attempt to connect to Mobius3D server
try
    
    % Retrieve DICOM RT Plan in JSON format
    r = session.session.get(['http://', session.server, '/_dicom/view/', sop]);

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
        Event(['The request to ', session.server, ' failed'], 'ERROR');
    else
        error(['The request to ', session.server, ' failed']);
    end
end

% Store text
t = char(r.text);

% If a valid RT plan object was returned
if length(t) > 2

    % Search for tag names
    [tokens, matches] = regexp(t, '"\(([0-9a-z]+), ([0-9a-z]+)\)[^"]+":', ...
        'tokens', 'match');
    
    % Loop through each tag
    for i = 1:length(tokens)
        
        % Replace the matched text with the dicom tag
        t = replace(t, matches{i}, ['"', dicomlookup(tokens{i}{1}, ...
            tokens{i}{2}), '":']); 
    end

    % Convert to MATLAB structure
    rtplan = jsondecode(t);
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
clear sop r t i;
