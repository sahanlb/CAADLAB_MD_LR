%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Writes the posq_charge,m file with particle charge values..
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Size of the Grid in grid points
numgpx = 64;
numgpy = 64;
numgpz = 64;

file0 = fopen('./posq_charge.m', 'w');

% Total particles
tot_particles = numgpx * numgpy * numgpz;


for i=1:tot_particles
  if(mod(i,2))
    fprintf(file0, 'p_q(%d) = sfi(-1.000000000000000, 32, 10);\n',i);
  else
    fprintf(file0, 'p_q(%d) = sfi(1.000000000000000, 32, 10);\n',i);
  end
end



fclose(file0);









