function [session, list] = QueryDICOMList(session)
% QueryDICOMList returns the list of DICOM patient data stored in Mobius3D.
%
% The following variables are required for proper execution: 
%
%   session: Python session object created by EstablishConnection
%
% The following variables are returned upon succesful completion:
%
%   session: Python session object created by EstablishConnection
%   list: cell array of structures containing 'css_id', 'patient_name', 
%       and 'patient_id' fields
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%   [session, list] = QueryDICOMList(session);
%   
%   % Loop through data, printing the patient ID
%   for i = 1:length(list)
%       fprintf('%s\n', list(i).patient_id);
%   end
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

% Attempt to connect to Mobius3D server
try
    
    % Log query
    if exist('Event', 'file') == 2
        Event(['Querying ', session.server, ' for DICOM datasets']);
    end
        
    % Execute get function of Python session object to retrieve list of 
    % DICOM patients from Mobius3D
    r = session.session.get(['http://', session.server, '/_dicom/patients']);

    % Convert to MATLAB structure
    s = jsondecode(char(r.text));
    
    % If the return arg was empty
    if ~isfield(s, 'patients')
       
        % Log an error
        if exist('Event', 'file') == 2
            Event('An error occurred returning the DICOM list', 'ERROR');
        else
            error('An error occurred returning the DICOM list');
        end
    end
    
    % Find indices of unique patient IDs
    [~, i, ~] = unique({s.patients(:).patient_id});
    
    % Create unique list
    list = struct('patient_id', {s.patients(i).patient_id}, 'patient_name', ...
        {s.patients(i).patient_name}, 'css_id', {s.patients(i).css_id});
    
    % If the above function calls work, log a success message
    if exist('Event', 'file') == 2
        Event(sprintf(['DICOM list retrieved successfully containing %i ', ...
            'entries in %0.3f seconds'], length(list), toc));
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

% Clear temporary variables
clear r s i;
