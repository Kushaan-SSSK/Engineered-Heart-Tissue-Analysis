function f = post_force2(d, L, a, R, config)

if nargin < 5 || isempty(config)
    E = 1.7;
else
    if isstruct(config) && isfield(config, 'youngs_modulus')
        E = config.youngs_modulus;
    else
        E = 1.7;
    end
end

f = 1000 * (3*pi*E*R^4) / (2*a^2*(3*L - a)) * d;