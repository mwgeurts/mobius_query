function [session, results] = QueryPlanChecks(session, varargin)
% QueryPlanChecks searches through the Mobius3D plan check list
% returning key results in a structure for plans that match the provided
% search criteria. For example, one can search for all plans matching a
% provided plan name machine name. Search parameters can be regular
% expressions. See below for a list of available plan check parameters that
% can be searched.
%
% The results structure includes arrays including plan check status, plan 
% name, date, machine, gamma pass rate, and more. If a structure name is  
% provided as a search parameter, the result array will also include the 
% DVH(s) for that structure as well as volume and gamma pass rate.
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

% Initialize return table
results = table;

% Initialize internal cell array of patient ID/plan IDs. This function will
% only return the latest plan check result for a given combinations
processed = cell(0);

% Initialize plan list array. Can be optionally provided to this function
% (useful when executing this function multiple times)
list = [];

% Initialize search variables
machine  = [];
planname = [];
rot = [];
mlc = [];
energy = [];
structure = [];
limitset = [];

% Turn off table warnings
warning('off', 'MATLAB:table:RowsAddedExistingVars');

% Start timer
tic;

% Loop through input arguments
for i = 1:2:length(varargin)

    % Store search variables
    if strcmpi(varargin{i}, 'list')
        list = varargin{i+1};
    elseif strcmpi(varargin{i}, 'machine')
        machine = varargin{i+1};
    elseif strcmpi(varargin{i}, 'planname')
        planname = varargin{i+1};
    elseif strcmpi(varargin{i}, 'rotation')
        rot = varargin{i+1};
    elseif strcmpi(varargin{i}, 'mlc')
        mlc = varargin{i+1};
    elseif strcmpi(varargin{i}, 'energy')
        energy = varargin{i+1};
    elseif strcmpi(varargin{i}, 'limitset')
        limitset = varargin{i+1};
    elseif strcmpi(varargin{i}, 'structure')
        structure = varargin{i+1};
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

% If a patient list was not provided, query it
if isempty(list)
    
    % Log action
    if exist('Event', 'file') == 2
        Event('Retrieving patient list');
    end
    
    % Attempt to connect to Mobius3D server
    try

        % Execute get function of Python session object to retrieve list of 
        % patients from Mobius3D
        r = session.session.get(['http://', session.server, ...
            '/_plan/list?sort=date&descending=1&limit=999999999']);

        % Convert the JSON list to a MATLAB structure
        s = jsondecode(char(r.text));

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
            Event(['The request to ', session.server, ' failed.'], 'ERROR');
        else
            error(['The request to ', session.server, ' failed.']);
        end
    end

    % Clear temporary variables
    clear r j s;
end

% If a valid screen size is returned (MATLAB was run without -nodisplay)
if usejava('jvm') && feature('ShowFigureWindows')
    
    % Start waitbar
    progress = waitbar(0, 'Searching plan list (0.00%)');
end

% Loop through patient list
for i = 1:length(list)
    
    % Update progress bar
    if exist('progress', 'var') && ishandle(progress)
        waitbar(i/length(list), progress, ...
            sprintf('Searching plan list (%0.2f%%)', i/length(list)*100));
    end
    
    % Check if list item is empty, and skip if so
    if isempty(list(i)) || ~isstruct(list(i)) || ...
            ~isfield(list(i), 'plans')
        continue;
    end
    
    % Loop through each plan
    for j = 1:length(list(i).plans)
    
        % Check if status is waiting or error, and skip if so
        if strcmpi(list(i).plans(j).status, 'waiting') || ...
                strcmpi(list(i).plans(j).status, 'error') || ...
                strcmpi(list(i).plans(j).status, 'critical')
            continue;
        end
        
        % Check if plan name has already been parsed, and skip if so
        if any(strcmp(processed, [list(i).patientId, ...
                list(i).plans(j).notes]))
            continue;
        end
   
        % Add plan to processed list
        processed{length(processed)+1} = [list(i).patientId, ...
            list(i).plans(j).notes];
        
        % If a planname parameter exists and doesn't match this plan
        if ~isempty(planname)
            if iscell(planname)
                found = false;
                for k = 1:length(planname)
                    if ~isempty(regexpi(list(i).plans(j).notes, ...
                            planname{k}))
                        found = true;
                    end
                end
                if ~found
                    continue;
                end
            else
                if isempty(regexpi(list(i).plans(j).notes, ...
                        planname))
                    continue;
                end
            end
        end
        
        % Execute get function of Python session object to retrieve plan
        % check JSON
        r = session.session.get(['http://', session.server, '/check/details/', ...
            list(i).plans(j).request_cid, '?format=json']);
        
        % Remove long couchable keys, as they cause errors
        t = char(r.text);
        t = regexprep(t, ['couchable:key:tuple:(''dvhLimit_result'', ', ...
            '''roi_num2dvh_dict'', '], 'couchable');
        t = regexprep(t, ['couchable:key:tuple:(''strayVoxel_result'', ', ...
            '''roi_num2strayVoxel_dict'', '], 'couchable');
        t = regexprep(t, ['couchable:key:tuple:(''targetCoverage_result'', ', ...
            '''roi_num2targetCoverage_dict'', '], 'couchable');
        
        % Convert the JSON list to a MATLAB structure
        try
            s = jsondecode(t);
        catch
            if exist('Event', 'file') == 2
                Event(['JSON decode error occurred for plan cid ', ...
                    list(i).plans(j).request_cid], 'WARN');
            else
                warning(['JSON decode error occurred for plan cid ', ...
                    list(i).plans(j).request_cid]);
            end
            continue;
        end
        
        % Execute remaining steps in try/catch
        try
        
        % If a machine parameter exists and doesn't match this plan
        if ~isempty(machine)
            if ~isfield(s.data, 'fractionGroup_info') || ...
                ~isfield(s.data.fractionGroup_info, ...
                    'fractionGroup_num2info_dict') || ~isfield(s.data...
                    .fractionGroup_info.fractionGroup_num2info_dict, ...
                    'x1')
                continue;
            end
            if iscell(machine)
                found = false;
                for k = 1:length(machine)
                    if ~isempty(regexpi(s.data.fractionGroup_info...
                            .fractionGroup_num2info_dict.x1.TreatmentMachineName, ...
                            machine{k}))
                        found = true;
                    end
                end
                if ~found
                    continue;
                end
            else
                if isempty(regexpi(s.data.fractionGroup_info...
                        .fractionGroup_num2info_dict.x1.TreatmentMachineName, ...
                        machine))
                    continue;
                end
            end
        end
        
        % If a limitset parameter exists and doesn't match this plan
        if ~isempty(limitset)
            if ~isfield(s.data.limitSet_data, 'humanReadableLimitSet_str')
                continue;
            end
            if iscell(limitset)
                found = false;
                for k = 1:length(limitset)
                    if ~isempty(regexpi(s.data.limitSet_data...
                            .humanReadableLimitSet_str, ...
                            limitset{k}))
                        found = true;
                    end
                end
                if ~found
                    continue;
                end
            else
                if isempty(regexpi(s.data.limitSet_data...
                        .humanReadableLimitSet_str, limitset))
                    continue;
                end
            end
        end
        
        % If a rotation parameter exists and doesn't match this plan
        if ~isempty(rot)
            fnames = fieldnames(s.data.beam_info.beam_num2info_dict);
            for k = 1:length(fnames)
                if iscell(rot)
                    found = false;
                    for l = 1:length(rot)
                        if ~isempty(regexpi(s.data.beam_info...
                                .beam_num2info_dict.(fnames{k})...
                                .rotationType_str, rot{l}))
                            found = true;
                        end
                    end
                    if ~found
                        continue;
                    end
                else
                    if isempty(regexpi(s.data.beam_info...
                            .beam_num2info_dict.(fnames{k})...
                            .rotationType_str, rot))
                        continue;
                    end
                end
            end
        end
        
        % If an MLC type parameter exists and doesn't match this plan
        if ~isempty(mlc)
            fnames = fieldnames(s.data.beam_info.beam_num2info_dict);
            for k = 1:length(fnames)
                if iscell(mlc)
                    found = false;
                    for l = 1:length(mlc)
                        if ~isempty(regexpi(s.data.beam_info...
                                .beam_num2info_dict.(fnames{k})...
                                .mlcType_str, mlc{l}))
                            found = true;
                        end
                    end
                    if ~found
                        continue;
                    end
                else
                    if isempty(regexpi(s.data.beam_info...
                            .beam_num2info_dict.(fnames{k})...
                            .mlcType_str, mlc))
                        continue;
                    end
                end
            end
        end
        
        % If an energy type parameter exists and doesn't match this plan
        if ~isempty(energy)
            fnames = fieldnames(s.data.beam_info.beam_num2info_dict);
            for k = 1:length(fnames)
                found = false;
                for l = 1:length(energy)
                    if s.data.beam_info.beam_num2info_dict.(fnames{k})...
                            .energy.value == energy(1)
                        found = true;
                    end
                end
                if ~found
                    continue;
                end
            end
        end
        
        % If a structure is included, and the structure does not exist in
        % this plan, skip it
        if ~isempty(structure)
            fnames = fieldnames(s.data.roiInfo_data.roi_num2basic_dict);
            found = false;
            for k = 1:length(fnames)
                if regexpi(s.data.roiInfo_data.roi_num2basic_dict...
                        .(fnames{k}).ROIName, structure)
                    found = true;
                end
            end
            if ~found
                continue;
            end
        end
        
        % If the code has gotten this far, add this plan to the results
        n = size(results,1) + 1;
        results.patientId{n,1} = list(i).patientId;
        results.planName{n,1} = list(i).plans(j).notes;
        if isfield(s, 'request') && ...
                isfield(s.request, 'planReceived_timestamp')
            results.timestamp{n,1} = s.request.planReceived_timestamp;
        end
        if isfield(s.data.limitSet_data, 'humanReadableLimitSet_str')
            results.limitSet{n,1} = ...
                s.data.limitSet_data.humanReadableLimitSet_str;
        else
            results.limitSet{n,1} = '';
        end
        if isfield(s.data, 'fractionGroup_info')
            results.machine{n,1} = s.data.fractionGroup_info...
                .fractionGroup_num2info_dict.x1.TreatmentMachineName;
        else
            results.machine{n,1} = '';
        end
        if isfield(s, 'version')
            results.version{n,1} = s.version{length(s.version)};
        else
            results.version{n,1} = '';
        end
        if isfield(s.data, 'treatmentPlanningSystem_info')
            results.tpsVersion{n,1} = s.data.treatmentPlanningSystem_info...
                .softwareVersion_str;
            results.tpsName{n,1} = s.data.treatmentPlanningSystem_info...
                .planningSystemName_str;
        else
            results.tpsVersion{n,1} = '';
            results.tpsName{n,1} = '';
        end
        if isfield(s.data, 'ct_info') && ...
                isfield(s.data.ct_info, 'patientPosition')
            results.patientPosition{n,1} = s.data.ct_info.patientPosition;
        else
            results.patientPosition{n,1} = '';
        end
        if isfield(s.request.taskProc_dict, ...
                'mms_worker_task_compute_dose_ComputeDicomDose')
            results.doseCalcTime{n,1} = s.request.taskProc_dict...
                .mms_worker_task_compute_dose_ComputeDicomDose.elapsed_time;
        else
            results.doseCalcTime{n,1} = 0;
        end
        if isfield(s.data.gamma_summary, 'criteria')
            results.gammaDose{n,1} = s.data.gamma_summary.criteria.dose.value;
            results.gammaDTA{n,1} = s.data.gamma_summary.criteria.maxDTA_mm.value;
            results.gammaHist{n,1} = horzcat(s.data.gamma_summary.histogram...
                .histEdge_list, vertcat(s.data.gamma_summary.histogram...
                .histCount_list, 0));
            results.gammaPass{n,1} = s.data.gamma_summary.passingRate.value;
        else
            results.gammaDose{n,1} = 0;
            results.gammaDTA{n,1} = 0;
            results.gammaHist{n,1} = [];
            results.gammaPass{n,1} = 0;
        end
        if isfield(s.data.strayVoxel_result, 'orig_result')
            results.strayVoxels{n,1} = s.data.strayVoxel_result.orig_result;
        else
            results.strayVoxels{n,1} = 'ok';
        end
        
        % Store number of fractions
        fxs = 0;
        if isfield(s.data, 'fractionGroup_info')
            fnames = fieldnames(s.data.fractionGroup_info...
                .fractionGroup_num2info_dict);
            for k = 1:length(fnames)
                fxs = fxs + s.data.fractionGroup_info...
                    .fractionGroup_num2info_dict.(fnames{k})...
                    .NumberofFractionsPlanned;
            end
        end
        results.numFractions{n,1} = fxs;
        
        % Store beam information
        if isfield(s.data, 'beam_info') && ...
                isfield(s.data.beam_info, 'beam_num2info_dict')
            fnames = fieldnames(s.data.beam_info.beam_num2info_dict);
            results.numBeams{n,1} = length(fnames);
        else
            results.numBeams{n,1} = 0;
        end
        
        % If a structure is included
        if ~isempty(structure) && isfield(s.data, 'roiInfo_data') && ...
                isfield(s.data.roiInfo_data, 'roi_num2basic_dict')
            fnames = fieldnames(s.data.roiInfo_data.roi_num2basic_dict);
            for k = 1:length(fnames)
                if regexpi(s.data.roiInfo_data.roi_num2basic_dict...
                        .(fnames{k}).ROIName, structure)
                    results.structName{n,1} = s.data.roiInfo_data...
                        .roi_num2basic_dict.(fnames{k}).ROIName;
                    results.structVolume{n,1} = s.data.roiInfo_data...
                        .roi_num2basic_dict.(fnames{k}).volume.value;
                    break;
                end
            end
            
            % Execute get function of Python session object to retrieve DVH
            r = session.session.get(['http://', session.server, ...
                '/check/attachment/', list(i).plans(j).request_cid, ...
                '/dvhChart_data.json']);

            % Convert the JSON list to a MATLAB structure
            s = jsondecode(char(r.text));
            
            % Loop through DVH
            for k = 1:length(s.data)
                
                % If this DVH structure mathes the above one, store its DVH
                % data
                if strcmp(s.data{k}.name, results.structName{n,1})
                    results.structHist{n,1} = s.data{k}.data;
                end
            end
        end
        
        % Catch runtime errors (will almost always be missing field errors)
        catch
            if exist('Event', 'file') == 2
                Event(['Missing field error occurred for plan cid ', ...
                    list(i).plans(j).request_cid], 'WARN');
            else
                warning(['Missing field error occurred for plan cid ', ...
                    list(i).plans(j).request_cid]);
            end
            continue;
        end
    end
end
  
% Update progress bar
if exist('progress', 'var') && ishandle(progress)
    close(progress);
end

% Log success
if exist('Event', 'file') == 2
    Event(sprintf('%i plans matched search criteria in %0.3f seconds', ...
        size(results,1), toc));
end

% Clear temporary variables
clear i j k l r s json;

