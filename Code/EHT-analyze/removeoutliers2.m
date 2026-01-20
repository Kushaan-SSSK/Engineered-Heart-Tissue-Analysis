function [dataout, timeout, indout] = removeoutliers2(datain, timein, sens)
% Remove outliers using Thompson's Tau method
% Original implementation from EHT ImageJ pipeline

n = length(datain);
if n < 3
    display(['ERROR: There must be at least 3 samples in the' ...
        ' data set in order to use the removeoutliers function.']);
    dataout = datain;
    timeout = timein;
    indout = 1:n;
    return;
end

S = std(datain);
xbar = mean(datain);

% tau is a vector containing values for Thompson's Tau
tau = [1.150 1.393 1.572 1.656 1.711 1.749 1.777 1.798 1.815 1.829 ...
    1.840 1.849 1.858 1.865 1.871 1.876 1.881 1.885 1.889 1.893 ...
    1.896 1.899 1.902 1.904 1.906 1.908 1.910 1.911 1.913 1.914 ...
    1.916 1.917 1.919 1.920 1.921 1.922 1.923 1.924];

% Determine the value of standard deviation x Tau
if n > length(tau)
    TS = sens * S; % For n > 40
else
    TS = tau(n) * S; % For samples of size 3 < n < 40
end

% Sort the input data vector so that removing the extreme values
% becomes an arbitrary task
indices = 1:length(datain);
datain(:,2) = indices;
inds = [];
dataout = sortrows(datain, 1);

% Compare the values of extreme high data points to TS
while abs((max(dataout(:,1)) - xbar)) > TS && size(dataout, 1) > 3
    inds = [inds; dataout(end, 2)];
    dataout = dataout(1:(length(dataout) - 1), :);
    % Determine the NEW value of S times Tau
    S = std(dataout(:,1));
    xbar = mean(dataout(:,1));
    if length(dataout(:,1)) > length(tau)
        TS = sens * S; % For n > 40
    else
        TS = tau(length(dataout(:,1))) * S; % For samples of size 3 < n < 40
    end
end

% Compare the values of extreme low data points to TS.
% Begin by determining the NEW value of S times Tau
S = std(dataout(:,1));
xbar = mean(dataout(:,1));
if length(dataout(:,1)) > length(tau)
    TS = sens * S; % For n > 40
else
    TS = tau(length(dataout(:,1))) * S; % For samples of size 3 < n < 40
end

while abs((min(dataout(:,1)) - xbar)) > TS && size(dataout, 1) > 3
    inds = [inds; dataout(1, 2)];
    dataout = dataout(2:(length(dataout)), :);
    % Determine the NEW value of S times Tau
    S = std(dataout(:,1));
    xbar = mean(dataout(:,1));
    if length(dataout(:,1)) > length(tau)
        TS = sens * S; % For n > 40
    else
        TS = tau(length(dataout(:,1))) * S; % For samples of size 3 < n < 40
    end
end

% Re-adjust indices
x = setdiff(indices, inds);
dataout = datain(x)';
timeout = timein(x);
indout = x;

end
