function [maxtab, mintab] = peakdet2(v, delta, x)

maxtab = [];
mintab = [];

v = v(:);

if nargin < 3
  x = (1:length(v))';
else 
  x = x(:);
    if length(v) ~= length(x)
    error('Input vectors v and x must have same length');
  end
end

mn = Inf; 
mx = -Inf;
mnpos = NaN; 
mxpos = NaN;

lookformax = 1;

for j = 1:length(delta)-1
    for i = delta(j,2):delta(j+1,2)
  this = v(i);
        if this > mx
            mx = this; 
            mxpos = x(i); 
        end
        if this < mn
            mn = this; 
            mnpos = x(i); 
        end
  
  if lookformax
            if this < mx - delta(j,1)
                maxtab = [maxtab; mxpos mx];
                mn = this; 
                mnpos = x(i);
      lookformax = 0;
    end  
  else
            if this > mn + delta(j,1)
                mintab = [mintab; mnpos mn];
                mx = this; 
                mxpos = x(i);
      lookformax = 1;
    end
  end
end
end
