function smoothed = sgolayfilt(data, order, framelen)

if nargin < 3
    error('sgolayfilt requires 3 arguments: data, order, framelen');
end

data = data(:);

if mod(framelen, 2) == 0
    framelen = framelen + 1;
end
if framelen < order + 1
    framelen = order + 1;
    if mod(framelen, 2) == 0
        framelen = framelen + 1;
    end
end

halfwin = (framelen - 1) / 2;
x = (-halfwin:halfwin)';

A = zeros(framelen, order + 1);
for i = 0:order
    A(:, i + 1) = x.^i;
end

coeffs = (A' * A) \ A';
center_coeffs = coeffs(1, :);

smoothed = zeros(size(data));
n = length(data);

for i = 1:n
    i_start = max(1, i - halfwin);
    i_end = min(n, i + halfwin);
    
    window = data(i_start:i_end);
    
    if i <= halfwin
        x_local = (i_start-i:i_end-i)';
        A_local = zeros(length(x_local), order + 1);
        for j = 0:order
            A_local(:, j + 1) = x_local.^j;
        end
        coeffs_local = (A_local' * A_local) \ A_local';
        local_center_coeffs = coeffs_local(1, :);
        smoothed(i) = dot(local_center_coeffs, window);
        
    elseif i > n - halfwin
        x_local = (i_start-i:i_end-i)';
        A_local = zeros(length(x_local), order + 1);
        for j = 0:order
            A_local(:, j + 1) = x_local.^j;
        end
        coeffs_local = (A_local' * A_local) \ A_local';
        local_center_coeffs = coeffs_local(1, :);
        smoothed(i) = dot(local_center_coeffs, window);
        
    else
        smoothed(i) = dot(center_coeffs, window);
    end
end

end
