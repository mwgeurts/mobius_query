function [session, dvh] = GetPlanCheckDVH(session, varargin)
% GetPlanCheckDVH retrieves the Mobius3D plan check DVH chart structure 
% containing Mobius3D-calculated DVH curves for each ROI.
%
% The following variables are required for proper execution:
%
%   session:    Python session object from EstablishConnection
%   varargin:   cell array of strings, with fixed index either 'plan' or 
%               'cid' followed by plan structure (obtained from 
%               MatchPlanCheck) or request CID string
%
% The following variables are returned upon succesful completion:
%
%   session:    Python session object from EstablishConnection
%   dvh:        structure containing the DVH data
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%   
%   % Search for plan check
%   [session, check] = MatchPlanCheck(session, 'id', '123456', ...
%       'plan', 'VMAT');
%
%   % Retrieve DVHs for matched plan check
%   [session, rtplan] = GetPlanCheckDVH(session, 'plan', plan);
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

% Initialize CID
cid = '';

% Loop through input arguments
for i = 1:2:length(varargin)
    
    % Store plan check CID
    if strcmpi(varargin{i}, 'plan') && isfield(varargin{i+1}, 'request')
        cid = varargin{i+1}.request.x_id;
    elseif strcmpi(varargin{i}, 'cid')
        cid = varargin{i+1};
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

% Verify CID was provided
if isempty(cid)
    
    % Log error
    if exist('Event', 'file') == 2
        Event(['Either a plan check JSON structure or plan check CID ', ...
            'must be provided to this function'], 'ERROR');
    else
        error(['Either a plan check JSON structure or plan check CID ', ...
            'must be provided to this function']);
    end 
end

% Log start
if exist('Event', 'file') == 2
    Event(sprintf('Retrieving DVH for plan check request CID %s', cid));
end

% Attempt to connect to Mobius3D server
try
    
    % Retrieve DVH chart in JSON format
    r = session.session.get(['http://', session.server, ...
        '/check/attachment/', cid, '/dvhChart_data.json']);

    % Log status
    if exist('Event', 'file') == 2
        Event(sprintf('DVH retrieved in %0.3f seconds', ...
            double(r.elapsed.seconds) + ...
            double(r.elapsed.microseconds)/1e6));
    end

% Otherwise, if an error occurred, a connection was not successful
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['The request to ', session.server, ' failed.'], 'ERROR');
    else
        error(['The request to ', session.server, ' failed.']);
    end
end

% Attempt to parse results
try
    
    % Log parsing
    if exist('Event', 'file') == 2
        Event('Parsing JSON into MATLAB structure return argument');
    end

    % Convert the JSON list to a MATLAB structure
    s = jsondecode(char(r.text));   
    dvh = s.data;

% Otherwise, if an error occurred, a connection was not successful
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['Could not parse the return data from http://', session.server, ...
            '/check/attachment/', cid, '/dvhChart_data.json'], 'ERROR');
    else
        error(['Could not parse the return data from http://', session.server, ...
            '/check/attachment/', cid, '/dvhChart_data.json']);
    end
end
    
% Clear temporary variables
clear cid i r s;
