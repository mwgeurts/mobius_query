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
%   list: cell array of structures containing 'css_id', 'patient_name', 
%       'patient_id', 'ct', 'rtdose', 'rtplan', and 'rtstruct' fields
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
    
    % Log query
    if exist('Event', 'file') == 2
        Event(['Querying ', server, ' for DICOM datasets']);
    end
        
    % Execute get function of Python session object to retrieve list of 
    % DICOM patients from Mobius3D
    r = session.get(['http://', server, '/_dicom/patients']);

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
            Event('An error occurred returning the DICOM list', 'ERROR');
        else
            error('An error occurred returning the DICOM list');
        end
    end
    
    % Loop through plans, retrieving number of files
    for i = 1:length(list)
        
        % Log query
        if exist('Event', 'file') == 2
            Event(['Retrieving CT instances for ', list{i}.patient_id]);
        end
        
        % Query CT series
        r = session.get(['http://', server, '/_dicom/series/', ...
            list{i}.patient_id, '/CT']);

        % Retrieve the JSON results
        j = r.json();
       
        % Convert to MATLAB structure
        list{i}.ct = regexp(char(py.json.dumps(j)), ...
            '"([^"]+)": ([0-9]+)', 'tokens');            
        
        % Loop through CT series
        for j = 1:length(list{i}.ct)
            
            % Query SOP instance UIDs
            r = session.get(['http://', server, '/_dicom/sopinsts/', ...
                list{i}.patient_id, '/CT/', list{i}.ct{j}{1}]);

            % Retrieve the JSON results
            k = r.json();
            
            % Convert to MATLAB structure
            list{i}.ct{j}{3} = regexp(char(py.json.dumps(k)), ...
                '"([0-9\.]+)"', 'tokens'); 
        end
        
        % Log query
        if exist('Event', 'file') == 2
            Event(['Retrieving RTDOSE instances for ', ...
                list{i}.patient_id]);
        end

        % Query RTDOSE series
        r = session.get(['http://', server, '/_dicom/series/', ...
            list{i}.patient_id, '/RTDOSE']);

        % Retrieve the JSON results
        j = r.json();

        % Convert to MATLAB structure
        list{i}.rtdose = regexp(char(py.json.dumps(j)), ...
            '"([^"]+)": ([0-9]+)', 'tokens');
        
        % Loop through RTDOSE series
        for j = 1:length(list{i}.rtdose)
            
            % Query SOP instance UIDs
            r = session.get(['http://', server, '/_dicom/sopinsts/', ...
                list{i}.patient_id, '/RTDOSE/', list{i}.rtdose{j}{1}]);

            % Retrieve the JSON results
            k = r.json();
            
            % Convert to MATLAB structure
            list{i}.rtdose{j}{3} = regexp(char(py.json.dumps(k)), ...
                '"([0-9\.]+)"', 'tokens'); 
        end
        
        % Log query
        if exist('Event', 'file') == 2
            Event(['Retrieving RTPLAN instances for ', ...
                list{i}.patient_id]);
        end
        
        % Query RTPLAN series
        r = session.get(['http://', server, '/_dicom/series/', ...
            list{i}.patient_id, '/RTPLAN']);

        % Retrieve the JSON results
        j = r.json();

        % Convert to MATLAB structure
        list{i}.rtplan = regexp(char(py.json.dumps(j)), ...
            '"([^"]+)": ([0-9]+)', 'tokens');  
        
        % Loop through RTPLAN series
        for j = 1:length(list{i}.rtplan)
            
            % Query SOP instance UIDs
            r = session.get(['http://', server, '/_dicom/sopinsts/', ...
                list{i}.patient_id, '/RTPLAN/', list{i}.rtplan{j}{1}]);

            % Retrieve the JSON results
            k = r.json();
            
            % Convert to MATLAB structure
            list{i}.rtplan{j}{3} = regexp(char(py.json.dumps(k)), ...
                '"([0-9\.]+)"', 'tokens'); 
        end
        
        % Log query
        if exist('Event', 'file') == 2
            Event(['Retrieving RTSTRUCT instances for ', ...
                list{i}.patient_id]);
        end
        
        % Query RTSTRUCT series
        r = session.get(['http://', server, '/_dicom/series/', ...
            list{i}.patient_id, '/RTSTRUCT']);

        % Retrieve the JSON results
        j = r.json();

        % Convert to MATLAB structure
        list{i}.rtstruct = regexp(char(py.json.dumps(j)), ...
            '"([^"]+)": ([0-9]+)', 'tokens');  
        
        % Loop through RTSTRUCT series
        for j = 1:length(list{i}.rtstruct)
            
            % Query SOP instance UIDs
            r = session.get(['http://', server, '/_dicom/sopinsts/', ...
                list{i}.patient_id, '/RTSTRUCT/', list{i}.rtstruct{j}{1}]);

            % Retrieve the JSON results
            k = r.json();
            
            % Convert to MATLAB structure
            list{i}.rtstruct{j}{3} = regexp(char(py.json.dumps(k)), ...
                '"([0-9\.]+)"', 'tokens'); 
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
clear r j s i k t;