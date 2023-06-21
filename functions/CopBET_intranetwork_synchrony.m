% out = CopBET_intranetwork_synchrony(in,atlas,varargin)
%
% Copenhagen Brain Entropy Toolbox: Intranetwork synchrony
% Evaluates intranetwork synchrony as in Carhart-Harris et al., 2014.
% Denoised voxel-wise timeseries are loaded along with a set of ROIs in a
% 4D logical matrix. For each volume, for each roi, the mean os all voxels
% in the ROI is evaluated as well as the variance across voxels. 
% Then, for each ROI, probability mass function
% of the variances over all time points in the
% ROI is established, as well as the Shannon entropy. 
%
% Input:
%   in: char with the path to the input, denoised voxel-wise time series or
%   a table where the first column contains
%   chars (in cells), e.g., different subjects or scan sessions.
%   atlas: The ROIs in a 4D logical matrix. 
%   
%   varargin (name-value pairs):
%   keepdata: Indicates whether the output table also should contain the
%   input data, i.e., by adding an extra column containing entropy values.
%   Defaults to true
%   parallel: Whether to run temporal entropy in parallel (true)
%
% Neurobiology Research Unit, 2023
% Please cite McCulloch, Olsen et al., 2023: "Navigating Chaos in
% Psychedelic Neuroimaging: A Rigorous Empirical Evaluation of the Entropic
% Brain Hypothesis" if you use CopBET in your studies. Please read the
% paper to get a notion of our recommendations regarding the use of the
% specific methodologies in the toolbox.

% ASO 9/3-2023

function out = CopBET_intranetwork_synchrony(in,atlas,varargin)
[out,numworkers,in,NRUspecific] = CopBET_function_init(in,varargin);

%load data
disp('Beginning entropy calculations')

if ndims(atlas)~=4
    error('Please specify the atlas as a 4D matrix')
end

if numel(unique(atlas(:)))~=2
    error('please specify the atlas as a logical matrix')
end

% parfor (ses = 1:height(in),numworkers)
for ses = 1:height(in);
    path = in{ses,1}{1};
    
    data_denoised = niftiread(path); %4D series
%     data_denoised = data_denoised - mean(data_denoised,4);
    
    if NRUspecific
        if ~cellfun(@isempty,regexp(path,'mr001'))
            data_denoised=NRUspecific_downsample_mr001data(data_denoised);
        end
    end
    datasz = size(data_denoised);
    atlassz = size(atlas);
    if ~all(datasz(1:3)==atlassz(1:3))
        error('data and atlas have different sizes')
    end
    
%     ROImeans = nan(size(atlas,4),datasz(4));
%     datadistances = cell(1,size(atlas,4));
    variances = nan(size(atlas,4),datasz(4));
    
    for vol = 1:datasz(4)
        v = data_denoised(:,:,:,vol);
        v(v==0) = nan; % extra-ROI voxels would skew the variance
        
        for ROI = 1:size(atlas,4)
%             ROImeans(ROI,vol) = mean(v(atlas(:,:,:,ROI)),'all');
%             datadistances{ROI}(:,vol) = abs(v(atlas(:,:,:,ROI))-ROImeans(ROI,vol));
            variances(ROI,vol) = nanvar(v(atlas(:,:,:,ROI)));
        end
        
        
    end
    
    entropy_ROI = nan(size(atlas,4),1);
%     Prob = cell(1,size(atlas,4));
    for ROI = 1:size(atlas,4)
%         [Prob{ROI},bins] = histcounts(datadistances{ROI}(:),bins,'Normalization','probability');
%         entropy{ses,ROI} = nansum(-Prob{ROI}.*log(Prob{ROI}));
%         sensible_data_check(entropy{ses,ROI});
        [Prob,bins] = histcounts(variances(ROI,:),'Normalization','probability');
        entropy_ROI(ROI) = nansum(-Prob.*log(Prob));
    end
    entropy{ses} = entropy_ROI;
    sensible_data_check(entropy_ROI);
    
    disp(['Done with session ',num2str(ses),' of ',num2str(height(in))])
end

out.entropy = entropy';
end

%%