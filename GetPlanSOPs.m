function [session, ct, rtss, dose, rtplan] = GetPlanSOPs(session, patient_id)
% GetPlanSOPs retrieves the DICOM SOP instance UIDs from Mobius3D for a 
% given patient ID, returning a cell array. The CT, RTSTRUCT, RTDOSE, and 
% RTPLAN SOPs are returned. Server is stored persistently and does not need
% to be passed each time as an input.
%
% The following variables are required for proper execution: 
%
%   session:    Python session object created from EstablishConnection
%   patient_id: patient ID
%
% The following variables are returned upon succesful completion:
%
%   session:    Python session object created from EstablishConnection
%   ct:         cell array containing the CT SOP instance UIDs
%   rtss:       cell array containing the RTSTRUCT SOP instance UIDs
%   dose:       cell array containing the RTDOSE SOP instance UIDs
%   rtplan:     cell array containing the RTPLAN SOP instance UIDs
%
% Below is an example of how the function is used:
%
%   % Connect to Mobius3D server and retrieve list of DICOM data
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
%
%   % Retrieve RT plan SOPs for patient ID 12345678
%   [session, ~, ~, ~, rtplan] = GetPlanSOPs(session, '12345678');
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

% Verify patient ID was provided
if isempty(patient_id)
    
    % Log error
    if exist('Event', 'file') == 2
        Event('A patient_id must be provided to this function', 'ERROR');
    else
        error('A patient_id must be provided to this function');
    end 
end

% Attempt to connect to Mobius3D server
try
    
    % Log event
    if exist('Event', 'file') == 2
        Event('Retrieving CT SOP instances');
    end
    
    % Retrieve instance UIDs
    r = session.session.get(['http://', session.server, '/_dicom/series/', ...
        patient_id, '/CT']);

	% Convert to MATLAB structure
	ct = regexp(char(r.text), '"([^"]+)": ([0-9]+)', 'tokens');
		
	% Loop through RTPLAN series
    for i = 1:length(ct)
		
		% Query SOP instance UIDs
		r = session.session.get(['http://', session.server, ...
            '/_dicom/sopinsts/', patient_id, '/CT/', ct{i}{1}]);

		% Convert to MATLAB structure
		ct{i}{3} = regexp(char(r.text), '"([0-9\.]+)"', 'tokens'); 
    end
    
    % Log event
    if exist('Event', 'file') == 2
        Event('Retrieving RTSTRUCT SOP instances');
    end
    
    % Retrieve instance UIDs
    r = session.session.get(['http://', session.server, '/_dicom/series/', ...
        patient_id, '/RTSTRUCT']);

	% Convert to MATLAB structure
	rtss = regexp(char(r.text), '"([^"]+)": ([0-9]+)', 'tokens');
		
	% Loop through RTSTRUCT series
    for i = 1:length(rtss)
		
		% Query SOP instance UIDs
		r = session.session.get(['http://', session.server, ...
            '/_dicom/sopinsts/', patient_id, '/RTPLAN/', rtss{i}{1}]);

		% Convert to MATLAB structure
		rtss{i}{3} = regexp(char(r.text), '"([0-9\.]+)"', 'tokens'); 
    end
    
    % Log event
    if exist('Event', 'file') == 2
        Event('Retrieving RTDOSE SOP instances');
    end
    
    % Retrieve instance UIDs
    r = session.session.get(['http://', session.server, '/_dicom/series/', ...
        patient_id, '/RTDOSE']);

	% Convert to MATLAB structure
	dose = regexp(char(r.text), '"([^"]+)": ([0-9]+)', 'tokens');
		
	% Loop through RTSTRUCT series
	for i = 1:length(dose)
		
		% Query SOP instance UIDs
		r = session.session.get(['http://', session.server, ...
            '/_dicom/sopinsts/', patient_id, '/RTDOSE/', dose{i}{1}]);

		% Convert to MATLAB structure
		dose{i}{3} = regexp(char(r.text), '"([0-9\.]+)"', 'tokens'); 
	end
    
    % Log event
    if exist('Event', 'file') == 2
        Event('Retrieving RTPLAN SOP instances');
    end
    
    % Retrieve DICOM RT Plan in JSON format
    r = session.session.get(['http://', session.server, '/_dicom/series/', ...
        patient_id, '/RTPLAN']);

	% Convert to MATLAB structure
	rtplan = regexp(char(r.text), '"([^"]+)": ([0-9]+)', 'tokens');
		
	% Loop through RTPLAN series
	for i = 1:length(rtplan)
		
		% Query SOP instance UIDs
		r = session.session.get(['http://', session.server, ...
            '/_dicom/sopinsts/', patient_id, '/RTPLAN/', rtplan{i}{1}]);

		% Convert to MATLAB structure
		rtplan{i}{3} = regexp(char(r.text), '"([0-9\.]+)"', 'tokens'); 
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

% Clear temporary variables
clear i r;