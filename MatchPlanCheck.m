function [session, check] = MatchPlanCheck(varargin)
% MatchPlanCheck searches through the Mobius3D server for a plan check.
% The function can search on patient ID and plan name or a date range. The
% patient list can be pre-loaded by executing QueryPatientList and then
% passed to this function to improve speed.
%
% The following variables are required for proper execution: 
%   varargin: cell array of strings, with odd indices of 'server',
%       'session', 'list', 'id', 'plan', 'date', 'range', and/or 'utc' and
%       even indices containing the parameters. The inputs 'server',
%       'session', 'id', and one of 'plan' or 'date' are required.
%
% The following variables are returned upon succesful completion:
%   session: Python session object
%   check: structure containing the plan check details
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%   [session, list] = QueryPatientList('server', '10.105.1.12', 'session', ...
%       session);
%   
%   % Search for patient ID 123456 and plan name 'VMAT'
%   [session, check] = MatchPlanCheck('server', '10.105.1.12', 'session', ...
%       session, 'list', list, 'id', '123456', 'plan', 'VMAT');
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

% Initialize plan list cell array
list = [];

% Initialize patient variables
id = [];
check = [];
date = [];

% Set default range to accept matched dates, in hours
range = 72;

% Define server's local UTC offset, in hours
utc = -5; % Central time

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
        
    % Store plan check    
    elseif strcmpi(varargin{i}, 'id')
        id = varargin{i+1};
    elseif strcmpi(varargin{i}, 'plan')
        plan = varargin{i+1};
    elseif strcmpi(varargin{i}, 'date')
        if isdatetime(varargin{i+1})
            date = datenum(varargin{i+1});
        else
            date = varargin{i+1};
        end
        
    % Store date range match variables
    elseif strcmpi(varargin{i}, 'range')
        range = varargin{i+1};
    elseif strcmpi(varargin{i}, 'utc')
        utc = varargin{i+1};
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

% If the patient variable are insufficient, throw an error
if isempty(id) || (isempty(plan) && isempty(date))
    
    % Log error
    if exist('Event', 'file') == 2
        Event(['A patient ID and either a plan or date must be provided ', ...
            'to search on'], 'ERROR');
    else
        error(['A patient ID and either a plan or date must be provided ', ...
            'to search on']);
    end 

% If a patient and plan was provided
elseif ~isempty(id) && ~isempty(plan)

    % Log start
    if exist('Event', 'file') == 2
        Event(['Searching Mobius3D for patient ', id, ' plan ', plan]);
        tic;
    end
    
% If a patient and plan date was provided
elseif ~isempty(id) && ~isempty(date)

    % Log start
    if exist('Event', 'file') == 2
        Event(['Searching Mobius3D for patient ', id, ' around date ', ...
            datestr(date)]);
        tic;
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

% If a patient list was not provided, query it
if isempty(list)
    
    % Attempt to connect to Mobius3D server
    try

        % Execute get function of Python session object to retrieve list of 
        % patients from Mobius3D
        r = session.get(['http://', server, ...
            '/_plan/list?sort=date&descending=1&limit=999999']);

        % Retrieve the JSON results
        j = r.json();

        % Execute loadjson() to convert the JSON list to a MATLAB structure
        s = loadjson(char(py.json.dumps(j)));

        % Retrieve cell array
        if isfield(s, 'patients')
            list = s.patients;

        % If the field does not exist, an error may have occured
        else

            % Log an error
            if exist('Event', 'file') == 2
                Event('An error occurred returning the patient list', ...
                    'ERROR');
            else
                error('An error occurred returning the patient list');
            end
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
    clear result j s;
end

% Loop through patient list
for i = 1:length(list)
    
    % Check if list item is empty, and skip if so
    if isempty(list{i}) || ~isstruct(list{i}) || ...
            ~isfield(list{i}, 'patientId')
        continue;
    end
    
    % If patient ID matches
    if strcmp(char(list{i}.patientId), id)
        
        % If a plan name or date was provided
        if ~isempty(plan) || ~isempty(date)

            % Loop over every plan in the patient
            for j = 1:length(list{i}.plans)

                % Skip if there aren't results (results will be empty)
                if isempty(list{i}.plans{j}.results)
                    continue
                end

                % Calculate MATLAB datenum of plan
                d = str2double(list{i}.plans{j}.created_timestamp) ...
                    / 86400 + datenum(1970,1,1,utc,0,0);

                % If this plan matches the plan check name (in the notes 
                % field), or if the plan date is within the allowed range
                if (~isempty(plan) && strcmpi(char(list{i}.plans{j}.notes), ...
                        plan)) || (~isempty(date) && d > (date - range) ...
                        && d < (date + range))

                    % Log match
                    if exist('Event', 'file') == 2
                        Event('Plan check found, retrieving JSON results');
                    end

                    % Retrieve JSON plan information
                    r = session.get(['http://', server, '/check/details/', ...
                        char(list{i}.plans{j}.request_cid), ...
                        '?format=json']);
                    data = r.json();

                    % Only get data for M3D v1.2 plans and later
                    if data{'version'}{1} < 1 || ...
                            data{'version'}{2} < 2
                        continue
                    end

                    % Retrieve JSON plan data
                    check = loadjson(char(py.json.dumps(data)));

                    % End loop, as matching plan check was found
                    break;
                end
            end
        end

        % End loop, as matching patient was found
        break;
    end
end

% Check if an empty structure was returned
if ~isempty(fieldnames(check))

    % Log success
    if exist('Event', 'file') == 2
        Event(sprintf('JSON plan check was found, cid %s, in %0.3f seconds', ...
            char(list{i}.plans{j}.request_cid), toc));
    end

% Otherwise the field is empty
else

    % Log warning
    if exist('Event', 'file') == 2
        Event('JSON plan check data was not found', 'WARN');
    else
        warning('JSON plan check data was not found');
    end

    % Clear return variable
    check = [];
end

% Clear temporary variables
clear date id list range server utc data i j s r d;