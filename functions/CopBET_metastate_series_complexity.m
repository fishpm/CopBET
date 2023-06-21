% out = CopBET_metastate_series_complexity(in,keepdata,parallel)
%
% Copenhagen Brain Entropy Toolbox: Metastate series complexity
% Evaluates Lempel-Ziv complexity (the LZ76 algorithm) for a binary series
% re
%
% Input:
%   in: a matrix (nxp,n>1) or a table where the first column contains
%   matrices (in cells) to be concatenated before clustering, e.g.,
%   different subjects or scan sessions.
%   TR: TR for applying a narrow filter between 0.04 and 0.07 Hz
%   K: number of clusters for k-means clustering. Defaults to K=3
%   keepdata: Indicates whether the output table also should contain the
%   input data, i.e., by adding an extra column containing entropy values.
%   Defaults to true
%   parallel: Whether to run 200 replicates of k-means in parallel [true]
%
%
% Neurobiology Research Unit, 2023
% Please cite McCulloch, Olsen et al., 2023: "Navigating Chaos in
% Psychedelic Neuroimaging: A Rigorous Empirical Evaluation of the Entropic
% Brain Hypothesis" if you use CopBET in your studies. Please read the
% paper to get a notion of our recommendations regarding the use of the
% specific methodologies in the toolbox.

% ASO 9/3-2023

% potential tests:
% Check that cluster centroids make sense (qualitatively) and correct size
% Check nans/infs

function out = CopBET_metastate_series_complexity(in,keepdata,parallel)

if nargin<2
    keepdata = true;
    parallel = true;
elseif nargin < 3
    parallel = true;
elseif nargin<1
    error('Please specify input data')
end
if keepdata
    if any(strcmp(in.Properties.VariableNames,'entropy'))
        warning('Overwriting entropy column in datatbl')
    end
end

if ~istable(in)
    if ismatrix(in)
        % convert matrix to table with one entry
        tbl = table;
        tbl.in{1} = in;
        in = tbl;
    else
        error(['Please specify the input data as either a matrix (nxp, n>1)', ...
            'or a table of matrices tbl where the FIRST column contains the data',...
            'with a matrix for each row'])
    end
end

% Do LEiDA and concatenate data for clustering
disp('Concatenating data')
datasizes = nan(height(in),1);
for ses = 1:height(in)
    datasizes(ses) = size(in{ses,1}{1},1);
end
data_all = nan(sum(datasizes),size(in{1,1}{1},2));
c = 1;
for ses = 1:height(in)
    tmp = in{ses,1}{1};
    tmp = tmp-mean(tmp);
    data_all(c:c+datasizes(ses)-1,:) = tmp;
    c = c+datasizes(ses);
end

if any(isnan(data_all(:)))
    error('nan')
end

disp('running kmeans and LZ calculations')
entropy = run_singleton_clustering(datasizes,data_all,parallel);

if keepdata
    out = in;
    out.entropy = entropy;
else
    out = table;
    out.entropy = entropy;
end


end

%% functions
function entropy = run_singleton_clustering(datasizes,ts_all,parallel)
nreps = 200; % how many times to repeat clustering. will choose lowest error solution
distanceMethod = 'correlation';
maxI = 1000; % how many times you allow kmeans to try to converge

numClusters = 4;
if parallel
[partition,centroids] = kmeans(ts_all,numClusters,'Distance',distanceMethod,'Replicates',nreps,'MaxIter',maxI,...
    'Display','final','Options',statset('UseParallel',1));
else
    [partition,centroids] = kmeans(ts_all,numClusters,'Distance',distanceMethod,'Replicates',nreps,'MaxIter',maxI,...
    'Display','final');
end

% group states
possible_states = 1:numClusters;
cencorr = corr(centroids');
for k = 1:numClusters
    [~,idx(k)] = min(cencorr(:,k));
end
for k = 1:numClusters
    if idx(idx(k))~=k
        error('Wrong metastate grouping')
    end
end

partition1 = [1,idx(1)];
partition2 = setdiff(possible_states,partition1);

newPartition = false(size(partition));
newPartition(ismember(partition,partition2)) = true;

tpts_traversed = 0;
entropy = nan(length(datasizes),1);
for h = 1:length(datasizes)
    
    T = tpts_traversed+1:tpts_traversed+datasizes(h);
    entropy(h) = calc_lz_complexity(newPartition(T),'exhaustive',1);
    
    tpts_traversed = tpts_traversed + datasizes(h);
%     disp(['Calculating LZ for #',num2str(h),' of ',num2str(height(tbl))])
end


end