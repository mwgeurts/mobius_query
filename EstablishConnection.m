function session = EstablishConnection(varargin)
% EstablishConnection opens/returns a Python session object to Mobius3D.
% The server name/IP address, username, and password can be passed as input
% arguments during the initial call of this function and are stored
% persistently such that subsequent calls to this function (to re-connect) 
% can be made without inputs. Upon success, this function returns a Python
% session object; upon failure an error is thrown and an empty array is
% returned.
%
% The following variables are required for proper execution: 
%   varargin: cell array of strings, with odd indices of 'server', 'user',
%       or 'pass' followed by a string containing the server name/IP,
%       username, and password, respectively.
%
% The following variables are returned upon succesful completion:
%   session: Python session object
%
% Below is an example of how the function is used:
%
%   session = EstablishConnection('server', '10.105.1.12', 'user', ...
%       'guest', 'pass', 'guest');
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
persistent server user pass;

% Initialize return variable
session = [];

% Start timer
tic;

% Loop through input arguments
for i = 1:2:nargin
    
    % Store server variables
    if strcmpi(varargin{i}, 'server')
        server = varargin{i+1};
    elseif strcmpi(varargin{i}, 'user')
        user = varargin{i+1};
    elseif strcmpi(varargin{i}, 'pass')
        pass = varargin{i+1};
    end
end
    
% If server variables are empty, throw an error
if exist('server', 'var') == 0 || isempty(server) || ...
        exist('user', 'var') == 0 || isempty(user) || ...
        exist('pass', 'var') == 0 || isempty(pass)

    % Log error
    if exist('Event', 'file') == 2
        Event(['Server information is missing. You must provide server, ', ...
            'username, and password inputs to this function'], 'ERROR');
    else
        error(['Server information is missing. You must provide server, ', ...
            'username, and password inputs to this function']);
    end 
end

% Verify Python can be executed
try
    % Execute the Python version function
    version = py.sys.version;
    
    % Log the Python version
    if exist('Event', 'file') == 2
        Event(['MATLAB is configured to use Python ', char(version)]);
    end    
    
    % Clear temporary variables
    clear version;
    
% If a error occurs, Python is most likely not installed
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['Python can not be executed from MATLAB. Verify that a ', ...
            'compatible Python engine is installed.'], 'ERROR');
    else
        error(['Python can not be executed from MATLAB. Verify that a ', ...
            'compatible Python engine is installed.']);
    end
end

% Initialize Python session
try
    % Execute the Python requests library Session() constructor
    session = py.requests.Session();

% If an error occurs, the requests library is most likely not installed
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event('The Python requests library is not installed.', 'ERROR');
    else
        error('The Python requests library is not installed.');
    end
end

% Attempt to connect to Mobius3D server and retrieve some data
try
    
    % Send authentication credentials to the Mobius3D server
    session.post(['http://', server, '/auth/login'], ...
        py.dict(pyargs('username', user, 'password', pass)));
    
    % Attempt to retrieve the patient list
    session.get(['http://', server, ...
        '/_plan/list?sort=date&descending=1&limit=1']);
   
    % If the above function calls work, log a success message
    if exist('Event', 'file') == 2
        Event(sprintf(['A connection was succesfully established to %s ', ...
            'in %0.3f seconds'], server, toc));
    end
    
% Otherwise, if an error occurred, a connection was not successful
catch
    
    % Log an error
    if exist('Event', 'file') == 2
        Event(['The server ', server, ' cannot be reached. Check your ', ...
            'network connection and credentials.'], 'ERROR');
    else
        error(['The server ', server, ' cannot be reached. Check your ', ...
            'network connection and credentials.']);
    end
end