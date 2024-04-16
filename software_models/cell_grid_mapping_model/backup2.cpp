#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <math.h>
#include "main.h"
using namespace std;

int main() {
	int i, j, k;

  // Check if sub-grids are suitably sized so than only immediate neighbor cells should be considered
  //if(SUB_GRID_POINTS * GRID_DIST > CUTOFF_RADIUS){
  //  cout << "Sub grid larger than a cell. Exiting simulation." << endl;
  //  return 0;
  //}

	// Declare a raw position data matrix (2d)
	float** raw_pos_data;
	raw_pos_data = new float* [3];
	for (i = 0; i < 3; i++) {
		raw_pos_data[i] = new float[TOTAL_PARTICLE];
	}

	// Declare a position data matrix for shifted data (2d)
	float** pos_data;
	pos_data = new float* [3];
	for (i = 0; i < 3; i++) {
		pos_data[i] = new float[TOTAL_PARTICLE];
	}


	string input_file_path = get_input_path(INPUT_FILE_NAME);							// Get the input file path


	cout << "*** Start reading data from input file:" << " ***" << endl;
	cout << input_file_path << endl;
	read_initial_input(input_file_path, raw_pos_data);							// Read the initial position
	cout << "*** Particle data loading finished ***\n" << endl;


	string OUTPUT_FILE_PATH;
	if (ENABLE_OUTPUT_FILE) {
		OUTPUT_FILE_PATH = get_output_path();		// Set the output path
	}


	ofstream output_file;
	output_file.open(OUTPUT_FILE_PATH, ofstream::app);


	shift_to_first_quadrant(raw_pos_data, pos_data);					// Shift the positions to the 1st quadrant

  // test print
  for(i = 0; i< TOTAL_PARTICLE; i++){
    output_file << pos_data[0][i] << "\t" << pos_data[1][i] << "\t" << pos_data[2][i] << endl; 
  }

  // Find simulation space boundaries
  float max_x = 0.0; 
  float max_y = 0.0; 
  float max_z = 0.0; 

  for(i = 0; i< TOTAL_PARTICLE; i++){
    if(pos_data[0][i] > max_x){
      max_x = pos_data[0][i];
    }
    if(pos_data[1][i] > max_y){
      max_y = pos_data[1][i];
    }
    if(pos_data[2][i] > max_z){
      max_z = pos_data[2][i];
    }
  }

  // Print simulation space boundaries
  cout << "\nMax X: " << max_x << "\tMax Y: " << max_y << "\tMax Z: " << max_z << endl;

  // Find max cell counts along each dimension
  int CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z;

  if(fmod(max_x, CUTOFF_RADIUS)){
    CELL_COUNT_X = max_x/CUTOFF_RADIUS + 1;
  }
  else{
    CELL_COUNT_X = max_x/CUTOFF_RADIUS;
  }

  if(fmod(max_y, CUTOFF_RADIUS)){
    CELL_COUNT_Y = max_y/CUTOFF_RADIUS + 1;
  }
  else{
    CELL_COUNT_Y = max_y/CUTOFF_RADIUS;
  }

  if(fmod(max_z, CUTOFF_RADIUS)){
    CELL_COUNT_Z = max_z/CUTOFF_RADIUS + 1;
  }
  else{
    CELL_COUNT_Z = max_z/CUTOFF_RADIUS;
  }


  // Print simulation space cell boundaries
  cout << "\nMax cell X: " << CELL_COUNT_X << "\tMax cell Y: " << CELL_COUNT_Y << "\tMax cell Z: " << CELL_COUNT_Z << endl;

  int CELL_COUNT_TOTAL;

  CELL_COUNT_TOTAL = CELL_COUNT_X * CELL_COUNT_Y * CELL_COUNT_Z;

  // Calculate number of grid points and distance between grid points
  int GRID_POINTS_X = 5 * CELL_COUNT_X;
  int GRID_POINTS_Y = 5 * CELL_COUNT_Y;
  int GRID_POINTS_Z = 5 * CELL_COUNT_Z;

  float GRID_DIST_X = (CUTOFF_RADIUS * CELL_COUNT_X) / (GRID_POINTS_X-1);
  float GRID_DIST_Y = (CUTOFF_RADIUS * CELL_COUNT_Y) / (GRID_POINTS_Y-1);
  float GRID_DIST_Z = (CUTOFF_RADIUS * CELL_COUNT_Z) / (GRID_POINTS_Z-1);


	// Declare a counter matrix to track the # of particles in each cell (3d)
	int*** particle_in_cell_counter;
	particle_in_cell_counter = new int** [CELL_COUNT_Z];
	for (i = 0; i < CELL_COUNT_X; i++) {
		particle_in_cell_counter[i] = new int* [CELL_COUNT_Y];
		for (j = 0; j < CELL_COUNT_Y; j++) {
			particle_in_cell_counter[i][j] = new int[CELL_COUNT_X];
		}
	}

	set_to_zeros_3d_int(particle_in_cell_counter, 
		CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);						// Initialize the particle counter to 0


	// Declare a matrix to record the status of each particle in each cell (3d)
	// 0 : X position
	// 1 : Y position
	// 2 : Z position
	// 3 : Number of neighbor particles which have overlapping sub-grids
	// 4 : Neighbor particles from home cell with overlapping sub-grids
	// 5 : Total neighbor particles for the current particle

	float*** cell_particle;
	cell_particle = new float** [6];
	for (i = 0; i < 6; i++) {
		cell_particle[i] = new float* [CELL_COUNT_TOTAL];
		for (j = 0; j < CELL_COUNT_TOTAL; j++) {
			cell_particle[i][j] = new float[CELL_PARTICLE_MAX];
		}
	}

	set_to_zeros_3d(cell_particle, CELL_PARTICLE_MAX, CELL_COUNT_TOTAL, 6);		// Initialize the particle-cell data matrix to 0



	cout << "*** Start mapping particles to cells ***" << endl;
	map_to_cells(pos_data, cell_particle, particle_in_cell_counter, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);	// Map the particles to cells

  // Print particle counts
  if(PRINT_PARTICLE_COUNT){
    cout << "Print particle count" << endl;
    print_int_3d(particle_in_cell_counter, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
    //return 0;
  }


// Go through cells and iterate though particles. Check how many other particles from home cell and neighbor cells
  for(int cell_z=0; cell_z<CELL_COUNT_Z; cell_z++){
    for(int cell_y=0; cell_y<CELL_COUNT_Y; cell_y++){
      for(int cell_x=0; cell_x<CELL_COUNT_X; cell_x++){
        //caculate cell index
        int cell_index = cell_index_calculator(cell_x, cell_y, cell_z, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
        //particle count in the cell
        int cell_p_count = particle_in_cell_counter[cell_z][cell_y][cell_x];

        // neighbor cell list
        // 0: cell index of the neighbor cell
        // 1: particle count for the neighbor cell
        // 2: X offset for neighbor particles from this neighbor cell
        // 3: Y offset for neighbor particles
        // 4: Z offset for neighbor particles
        //
        float nb_list[27][5];

        for(i=-1; i<2; i++){ //Z
          for(j=-1; j<2; j++){ //Y
            for(k=-1; k<2; k++){ //X
              int list_index = i*9 + j*3 + k + 13;
              int x_i, y_i, z_i;
              
              if((cell_z == 0) && (i == -1)){
                z_i = CELL_COUNT_Z-1;
                nb_list[list_index][4] = -1 * CUTOFF_RADIUS * CELL_COUNT_Z;
              }
              else if((cell_z == CELL_COUNT_Z-1) && (i == 1)){
                z_i = 0;
                nb_list[list_index][4] = CUTOFF_RADIUS * CELL_COUNT_Z;
              }
              else{
                z_i = cell_z + i;
                nb_list[list_index][4] = 0;
              }

              if((cell_y == 0) && (j == -1)){
                y_i = CELL_COUNT_Y -1;
                nb_list[list_index][3] = -1 * CUTOFF_RADIUS * CELL_COUNT_Y;
              }
              else if((cell_y == CELL_COUNT_Y-1) && (j == 1)){
                y_i = 0;
                nb_list[list_index][3] = CUTOFF_RADIUS * CELL_COUNT_Y;
              }
              else{
                y_i = cell_y + j;
                nb_list[list_index][3] = 0;
              }

              if((cell_x == 0) && (k == -1)){
                x_i = CELL_COUNT_X-1;
                nb_list[list_index][2] = -1 * CUTOFF_RADIUS * CELL_COUNT_X;
              }
              else if((cell_x == CELL_COUNT_X-1) && (k == 1)){
                x_i = 0;
                nb_list[list_index][2] = CUTOFF_RADIUS * CELL_COUNT_X;
              }
              else{
                x_i = cell_x + k;
                nb_list[list_index][2] = 0;
              }

              nb_list[list_index][0] = cell_index_calculator(x_i, y_i, z_i, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
              nb_list[list_index][1] = particle_in_cell_counter[z_i][y_i][x_i];
            }
          }
        }

        //loop through the particles in the home cell
        for(int hp = 0; hp<cell_p_count; hp++){
          for(int n=0; n<27; n++){ // go through each of the neighbor cells
            int nb_p_count = nb_list[n][1];
            int nb_cell_id = nb_list[n][0];

            // home particle position
            float h_x = cell_particle[0][cell_index][hp];
            float h_y = cell_particle[1][cell_index][hp];
            float h_z = cell_particle[2][cell_index][hp];
            
            for(int np=0; np<nb_p_count; np++){ // go through each of the neighbor particles
              // avoid home current home particle when home cell is the neighbor cell
              if((nb_cell_id == cell_index) && (hp == np)){
                continue;
              }

              // increment total neighbor count
              cell_particle[5][cell_index][hp] += 1;

              //neighbor particle position
              float n_x = cell_particle[0][nb_cell_id][np] + nb_list[n][2];
              float n_y = cell_particle[1][nb_cell_id][np] + nb_list[n][3];
              float n_z = cell_particle[2][nb_cell_id][np] + nb_list[n][4];

              // check overlap on X dimension
              float h_neg, h_pos, n_neg, n_pos;
              
              h_neg = floor(h_x/GRID_DIST_X)*GRID_DIST_X - GRID_DIST_X;
              h_pos = floor(h_x/GRID_DIST_X)*GRID_DIST_X + 2*GRID_DIST_X;

              n_neg = floor(n_x/GRID_DIST_X)*GRID_DIST_X - GRID_DIST_X;
              n_pos = floor(n_x/GRID_DIST_X)*GRID_DIST_X + 2*GRID_DIST_X;
              
              if(((h_x > n_x) && (h_neg <= n_pos)) || ((h_x <= n_x) && (h_pos >= n_neg))){
                //count the particle
                cell_particle[3][cell_index][hp] += 1;
                if(nb_cell_id == cell_index){
                  cell_particle[4][cell_index][hp] += 1;
                }
                /** debug print **/
                if(cell_index == 0 && nb_cell_id == 1 && hp == 0){
                  cout << "Overlap on X. HP: " << h_x << ", " << h_y << ", " << h_z << "\tNP: " << n_x << ", " << n_y << ", " << n_z << endl;
                }
                /** debug print **/
                continue;
              }

              // Check overlap along Y dimension
              h_neg = floor(h_y/GRID_DIST_Y)*GRID_DIST_Y - GRID_DIST_Y;
              h_pos = floor(h_y/GRID_DIST_Y)*GRID_DIST_Y + 2*GRID_DIST_Y;

              n_neg = floor(n_y/GRID_DIST_Y)*GRID_DIST_Y - GRID_DIST_Y;
              n_pos = floor(n_y/GRID_DIST_Y)*GRID_DIST_Y + 2*GRID_DIST_Y;

              if(((h_x > n_x) && (h_neg <= n_pos)) || ((h_x <= n_x) && (h_pos >= n_neg))){
                //count the particle
                cell_particle[3][cell_index][hp] += 1;
                if(nb_cell_id == cell_index){
                  cell_particle[4][cell_index][hp] += 1;
                }
                /** debug print **/
                if(cell_index == 0 && nb_cell_id == 1 && hp == 0){
                  cout << "Overlap on Y. HP: " << h_x << ", " << h_y << ", " << h_z << "\tNP: " << n_x << ", " << n_y << ", " << n_z << endl;
                }
                /** debug print **/
                continue;
              }

              // Check overlap along Z dimension
              h_neg = floor(h_z/GRID_DIST_Z)*GRID_DIST_Z - GRID_DIST_Z;
              h_pos = floor(h_z/GRID_DIST_Z)*GRID_DIST_Z + 2*GRID_DIST_Z;

              n_neg = floor(n_z/GRID_DIST_Z)*GRID_DIST_Z - GRID_DIST_Z;
              n_pos = floor(n_z/GRID_DIST_Z)*GRID_DIST_Z + 2*GRID_DIST_Z;

              if(((h_x > n_x) && (h_neg <= n_pos)) || ((h_x <= n_x) && (h_pos >= n_neg))){
                //count the particle
                cell_particle[3][cell_index][hp] += 1;
                if(nb_cell_id == cell_index){
                  cell_particle[4][cell_index][hp] += 1;
                }
                /** debug print **/
                if(cell_index == 0 && nb_cell_id == 1 && hp == 0){
                  cout << "Overlap on Z. HP: " << h_x << ", " << h_y << ", " << h_z << "\tNP: " << n_x << ", " << n_y << ", " << n_z << endl;
                }
                /** debug print **/
              }

            }
          }
        } //loop through the particles in the home cell




      }
    }
  } // Go through cells and iterate though particles.


  //Generate results
  // 1. Average number of particles which have overlpaping sub-grids per particle
  // 2. Same as above when overlapping particles from home cell are ignored.

  int particle_count = 0;
  int total_neighbors = 0;
  int overlapping_particles = 0;
  int overlaps_exclude_home_cell = 0;
  
  float avg_overlaps;
  float avg_overlaps_exclude;

  // Go through all cells and particles again
  for(int cell_z=0; cell_z<CELL_COUNT_Z; cell_z++){
    for(int cell_y=0; cell_y<CELL_COUNT_Y; cell_y++){
      for(int cell_x=0; cell_x<CELL_COUNT_X; cell_x++){
        int cell_id = cell_index_calculator(cell_x, cell_y, cell_z, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
        //go through particles
        int p_count = particle_in_cell_counter[cell_z][cell_y][cell_x];
        for(int p=0; p<p_count; p++){
          particle_count++;
          overlapping_particles      += (int) cell_particle[3][cell_id][p];
          overlaps_exclude_home_cell += (int) (cell_particle[3][cell_id][p] - cell_particle[4][cell_id][p]);
          total_neighbors            += (int) cell_particle[5][cell_id][p];
        } //go through particles
      }
    }
  } // Go through all cells and particles again

  // Print results
  cout << "Particle count: " << particle_count << endl;
  cout << "Total overlapping neighbors per particle: " << overlapping_particles/particle_count << endl;
  cout << "Overlapping neighbors from neighbor cells only: " << overlaps_exclude_home_cell/particle_count << endl;
  cout << "Average number of neighbor particles per particle: " << total_neighbors/particle_count << endl;



}



// Helper functions
string get_input_path(string file_name) {
	// Not available for pdb files for now
	string path = COMMON_PATH + file_name;
	return path;
}


void read_initial_input(string path, float** data_pos) {
	// Initial velocity is zero for all particles
	int i;
	ifstream raw(path.c_str());
	if (!raw) {
		cout << "*** Error reading input file! ***" << endl;
		exit(1);
	}
	string line;
	stringstream ss;
	for (i = 0; i < TOTAL_PARTICLE; i++) {
		getline(raw, line);
		ss.str(line);
		ss >> data_pos[0][i] >> data_pos[1][i] >> data_pos[2][i];
		ss.clear();
	}
}


string get_output_path() {
	string part_1 = "output_file";
	string path = part_1 + ".txt";
	return path;
}


void shift_to_first_quadrant(float** raw_data, float** shifted_data) {
	int i;
	float* min_x;
	float* min_y;
	float* min_z;

	min_x = min_element(raw_data[0], raw_data[0] + TOTAL_PARTICLE);
	min_y = min_element(raw_data[1], raw_data[1] + TOTAL_PARTICLE);
	min_z = min_element(raw_data[2], raw_data[2] + TOTAL_PARTICLE);
	for (i = 0; i < TOTAL_PARTICLE; i++) {
		shifted_data[0][i] = raw_data[0][i] - *min_x;
		shifted_data[1][i] = raw_data[1][i] - *min_y;
		shifted_data[2][i] = raw_data[2][i] - *min_z;
	}
}


void set_to_zeros_3d_int(int*** matrix, int x, int y, int z) {
	int i, j, k;
	for (i = 0; i < z; i++) {
		for (j = 0; j < y; j++) {
			for (k = 0; k < x; k++) {
				matrix[i][j][k] = 0;
			}
		}
	}
}


void set_to_zeros_3d(float*** matrix, int x, int y, int z) {
	int i, j, k;
	for (i = 0; i < z; i++) {
		for (j = 0; j < y; j++) {
			for (k = 0; k < x; k++) {
				matrix[i][j][k] = 0;
			}
		}
	}
}


void print_int_3d(int*** matrix, int x, int y, int z) {
	int i, j, k;
	for (i = 0; i < z; i++) {
		for (j = 0; j < y; j++) {
			for (k = 0; k < x; k++) {
			  cout << i << "," << j << "," << k << ": ";
        cout << "(" << (i*16 + j*4 + k) << ")";
			  cout << matrix[i][j][k] << endl;
			}
		}
	}
}



void map_to_cells(float** pos_data, float*** cell_particle, int*** particle_in_cell_counter, int CELL_COUNT_X, int CELL_COUNT_Y, int CELL_COUNT_Z) {
	int i;
	int cell_x, cell_y, cell_z;
	int out_range_particle_counter = 0;
	int counter = 0;
	int total_counter = 0;
	int cell_id;
	for (i = 0; i < TOTAL_PARTICLE; i++) {
		cell_x = pos_data[0][i] / CUTOFF_RADIUS;
		cell_y = pos_data[1][i] / CUTOFF_RADIUS;
		cell_z = pos_data[2][i] / CUTOFF_RADIUS;
    /*********************** Test new cell mapping ********************/
		//cell_x = pos_data[2][i] / CUTOFF_RADIUS;
		//cell_y = pos_data[1][i] / CUTOFF_RADIUS;
		//cell_z = pos_data[0][i] / CUTOFF_RADIUS;
    /*********************** Test new cell mapping ********************/


		// Write the particle information to cell list
		if (cell_x >= 0 && cell_x < CELL_COUNT_X &&
			cell_y >= 0 && cell_y < CELL_COUNT_Y &&
			cell_z >= 0 && cell_z < CELL_COUNT_Z) {
			counter = particle_in_cell_counter[cell_z][cell_y][cell_x];

      //if(PRINT_POS_DATA && cell_x == 3 && cell_y == 2 && cell_z == 1){
      if(PRINT_POS_DATA){
        cout << setprecision(12) << "pos " << pos_data[0][i] << "\t" << pos_data[1][i] << "\t" << pos_data[2][i] << endl;
        cout << "cell " << cell_x << "\t" << cell_y << "\t" << cell_z << "\n" << endl;
      }

			// Start from 0
			cell_id = cell_index_calculator(cell_x, cell_y, cell_z, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
			cell_particle[0][cell_id][counter] = pos_data[0][i];
			cell_particle[1][cell_id][counter] = pos_data[1][i];
			cell_particle[2][cell_id][counter] = pos_data[2][i];
			particle_in_cell_counter[cell_z][cell_y][cell_x] += 1;
			total_counter += 1;
		}
		else {
			out_range_particle_counter += 1;
      cout << "Out of range particle: " << pos_data[0][i] << ", " << pos_data[1][i] << ", " << pos_data[2][i] << endl;
		}
	}
	cout << "*** Particles mapping to cells finished! ***\n" << endl;
	cout << "Total of (" << total_counter << ") particles recorded" << endl;
	cout << "Total of (" << out_range_particle_counter << ") particles falling out of the range" << endl;
}


int cell_index_calculator(int cell_x, int cell_y, int cell_z, int CELL_COUNT_X, int CELL_COUNT_Y, int CELL_COUNT_Z) {
	int index;
	index = cell_z * CELL_COUNT_Y * CELL_COUNT_X + cell_y * CELL_COUNT_X + cell_x;
	return index;
}





