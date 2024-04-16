%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Writes a fake Green's ROM file.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Size of the Grid in grid points
numgpx = 16;
numgpy = 16;
numgpz = 16;

file0 = fopen('./new_greens_rom.m', 'w');

% Loop over each dimension

for i=0:numgpz-1
  for j=0:numgpy-1
    for k=0:numgpx-1
      index = i*numgpx*numgpy + j*numgpx + k;
      fprintf(file0, 'grom(%d+1,%d+1,%d+1)=%f;\n',i,j,k, index);
    end
  end
end



fclose(file0);









