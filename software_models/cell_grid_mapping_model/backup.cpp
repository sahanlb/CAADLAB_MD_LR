#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include "main.h"
using namespace std;

int main() {
	int i, j, k;

#pragma region DeclareMatrices
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

	/* Record the history of energy, 1: LJ potential, 2: Kinectic energy, 3: Total energy*/
	double* energy_data_history;
	energy_data_history = new double [3];

	// Declare a counter matrix to track the # of particles in each cell (3d)
	int*** particle_in_cell_counter;
	particle_in_cell_counter = new int** [CELL_COUNT_Z];
	for (i = 0; i < CELL_COUNT_X; i++) {
		particle_in_cell_counter[i] = new int* [CELL_COUNT_Y];
		for (j = 0; j < CELL_COUNT_Y; j++) {
			particle_in_cell_counter[i][j] = new int[CELL_COUNT_X];
		}
	}


	// Declare a matrix to record the status of each particle in each cell (3d)
	// 0 : X position
	// 1 : Y position
	// 2 : Z position
	// 3 : X force
	// 4 : Y force
	// 5 : Z force
	// 6 : X velocity
	// 7 : Y velocity
	// 8 : Z velocity
	// 9 : Potential energy
	// 10: Kinetic energy
	// 11: Number of neighbor particles inside cut-off radius
	float*** cell_particle;
	cell_particle = new float** [12];
	for (i = 0; i < 12; i++) {
		cell_particle[i] = new float* [CELL_COUNT_TOTAL];
		for (j = 0; j < CELL_COUNT_TOTAL; j++) {
			cell_particle[i][j] = new float[CELL_PARTICLE_MAX];
		}
	}

	// Declare a temporary counter matrix to track the # of particles in each cell (3d)
	int*** tmp_particle_in_cell_counter;
	tmp_particle_in_cell_counter = new int** [CELL_COUNT_Z];
	for (i = 0; i < CELL_COUNT_X; i++) {
		tmp_particle_in_cell_counter[i] = new int* [CELL_COUNT_Y];
		for (j = 0; j < CELL_COUNT_Y; j++) {
			tmp_particle_in_cell_counter[i][j] = new int[CELL_COUNT_X];
		}
	}

	// Declare a temporary matrix to record the status of each particle in each cell (3d)
	float*** tmp_cell_particle;
	tmp_cell_particle = new float** [12];
	for (i = 0; i < 12; i++) {
		tmp_cell_particle[i] = new float* [CELL_COUNT_TOTAL];
		for (j = 0; j < CELL_COUNT_TOTAL; j++) {
			tmp_cell_particle[i][j] = new float[CELL_PARTICLE_MAX];
		}
	}


	// Declare a matrix to record the number of reference particles to be evaluated by each filter (2d)
	/* Record how many reference particles each filter need to evaluate: 
	   1: total particle this filter need to process; 
	   2: # of particles from 1st cell; 
	   3: # of particles from 2nd cell
	*/
	float** filter_input_particle_num;
	filter_input_particle_num = new float* [3];
	for (i = 0; i < 3; i++) {
		filter_input_particle_num[i] = new float[NUM_FILTER];
	}



	string input_file_path = get_input_path(INPUT_FILE_NAME);							// Get the input file path

	cout << "*** Start reading data from input file:" << " ***" << endl;
	cout << input_file_path << endl;
	read_initial_input(input_file_path, raw_pos_data);							// Read the initial position
	cout << "*** Particle data loading finished ***\n" << endl;


	string OUTPUT_ENERGY_FILE_PATH;
	if (ENABLE_OUTPUT_ENERGY_FILE) {
		OUTPUT_ENERGY_FILE_PATH = get_energy_output_path();		// Set the output path
	}
	ofstream output_file;
	output_file.open(OUTPUT_ENERGY_FILE_PATH, ofstream::app);

	shift_to_first_quadrant(raw_pos_data, pos_data);					// Shift the positions to the 1st quadrant

	set_to_zeros_3d_int(particle_in_cell_counter, 
		CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);						// Initialize the particle counter to 0

	set_to_zeros_3d(cell_particle, CELL_PARTICLE_MAX, CELL_COUNT_TOTAL, 12);		// Initialize the particle-cell data matrix to 0

	cout << "*** Start mapping particles to cells ***" << endl;
	map_to_cells(pos_data, cell_particle, particle_in_cell_counter);	// Map the particles to cells

  // Print particle counts
  if(PRINT_PARTICLE_COUNT){
    cout << "Print particle count" << endl;
    print_int_3d(particle_in_cell_counter, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
    //return 0;
  }

	/* Start loading interpolation index data */
	string file_0 = get_input_path("c0_14.txt");
	read_interpolation(file_0, c0_vdw_list_14);
	string file_1 = get_input_path("c1_14.txt");
	read_interpolation(file_1, c1_vdw_list_14);
	string file_4 = get_input_path("c0_8.txt");
	read_interpolation(file_4, c0_vdw_list_8);
	string file_5 = get_input_path("c1_8.txt");
	read_interpolation(file_5, c1_vdw_list_8);
	string file_8 = get_input_path("c0_12.txt");
	read_interpolation(file_8, c0_vdw_list_12);
	string file_9 = get_input_path("c1_12.txt");
	read_interpolation(file_9, c1_vdw_list_12);
	string file_12 = get_input_path("c0_6.txt");
	read_interpolation(file_12, c0_vdw_list_6);
	string file_13 = get_input_path("c1_6.txt");
	read_interpolation(file_13, c1_vdw_list_6);
	if (INTERPOLATION_ORDER > 1) {
		string file_2 = get_input_path("c2_14.txt");
		read_interpolation(file_2, c2_vdw_list_14);
		string file_6 = get_input_path("c2_8.txt");
		read_interpolation(file_6, c2_vdw_list_8);
		string file_10 = get_input_path("c2_12.txt");
		read_interpolation(file_10, c2_vdw_list_12);
		string file_14 = get_input_path("c2_6.txt");
		read_interpolation(file_14, c2_vdw_list_6);
	}
	if (INTERPOLATION_ORDER > 2) {
		string file_3 = get_input_path("c3_14.txt");
		read_interpolation(file_3, c3_vdw_list_14);
		string file_7= get_input_path("c3_8.txt");
		read_interpolation(file_7, c3_vdw_list_8);
		string file_11 = get_input_path("c3_12.txt");
		read_interpolation(file_11, c3_vdw_list_12);
		string file_15 = get_input_path("c3_6.txt");
		read_interpolation(file_15, c3_vdw_list_6);
	}
#pragma endregion
#pragma region FullSimulation
	int sim_iter;
	int home_cell_x, home_cell_y, home_cell_z;
	int nb_cell_x, nb_cell_y, nb_cell_z;
	int filter_id, nb_cell_id;
	int tmp_particle_num, tmp_particle_num_1, tmp_particle_num_2;
	int filter_process_particle_max;
	int ref_particle_index, nb_particle_index;
	int tmp_counter_particles_within_cutoff;
	int seg_index;
	bool ENABLE_ENERGY_EVALUATION;
	float ref_pos_x, ref_pos_y, ref_pos_z;
	float nb_pos_x, nb_pos_y, nb_pos_z;
	float tmp_force_acc_x, tmp_force_acc_y, tmp_force_acc_z;
	float tmp_potential_acc;
	float tmp_nb_force_x, tmp_nb_force_y, tmp_nb_force_z;
	float dx, dy, dz, r2;
	double SIMULATION_TIME_STEP = 2E-15;
  int neighbor_cell_id[14]; //holds the calculated neighbor cell IDs for a given iteration
  int neighbor_particle_count[14]; //number of particles in neighboe cells

	for (sim_iter = 0; sim_iter < SIMULATION_TIMESTEP; sim_iter++) {
    if(DEBUG){
      cout << "Iteration: " << sim_iter << endl;
    }

		if (sim_iter % ENERGY_EVALUATION_STEPS == 0) {
			ENABLE_ENERGY_EVALUATION = 1;
		}
		else {
			ENABLE_ENERGY_EVALUATION = 0;
		}

    // Zero out the force values in cell_particle data structure
    for(i = 0; i < CELL_COUNT_TOTAL; i++){
      for(j = 0; j < CELL_PARTICLE_MAX; j++){
        cell_particle[3][i][j] = 0.0;
        cell_particle[4][i][j] = 0.0;
        cell_particle[5][i][j] = 0.0;
      }
    }

    // Zero out potential energy values
    for(i = 0; i < CELL_COUNT_TOTAL; i++){
      for(j = 0; j < CELL_PARTICLE_MAX; j++){
        cell_particle[9][i][j] = 0.0;
      }
    }


		// Each cell as home cell for once
		for (home_cell_z = 0; home_cell_z < CELL_COUNT_Z; home_cell_z++) {
			for (home_cell_y = 0; home_cell_y < CELL_COUNT_Y; home_cell_y++) {
		    for (home_cell_x = 0; home_cell_x < CELL_COUNT_X; home_cell_x++) {
					// Generate input particle pairs
					// In the software model filters are processed in series, and we iterate through the home cell particles,
					// only one filter populated with home cell particles suffice. Reference particles are from neighbor cells 
					// and home cell itself.
					// filter_input_particle_num data structure is repurposed to save the number of particles in neighbor cells 
					// from which the reference particles are selected.
					if (ENABLE_PRINT_DETAIL_MESSAGE) {
						cout << "\n\n*** Start processing home cell: " << home_cell_z << home_cell_y << home_cell_x << " ***" << endl;
					}


					for (filter_id = 0; filter_id < NUM_FILTER; filter_id++) {
						switch (filter_id) // POSSIBLE ACCELERATION: USE MPI,
						{
#pragma region Case_0
						case 0: // Process home cell (222), neighbor cell is itself

							// Home cell itself is the neighbor cell
							nb_cell_id = cell_index_calculator(home_cell_x, home_cell_y, home_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles
							tmp_particle_num = particle_in_cell_counter[home_cell_z][home_cell_y][home_cell_x];

							// Get neighbor cell indices
							// Other neighbor cell processed by filter 0 is (3,1,3)
							if(home_cell_x == CELL_COUNT_X-1){
                nb_cell_x = 0;
              }
              else{
                nb_cell_x = home_cell_x + 1;
              }
              if(home_cell_y == 0){
                nb_cell_y = CELL_COUNT_Y - 1;
              }
              else{
                nb_cell_y = home_cell_y - 1;
              }
							if (home_cell_z == CELL_COUNT_Z - 1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;


              //particle count for the second cell
              tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							filter_input_particle_num[0][filter_id] = (tmp_particle_num > tmp_particle_num_2) ? tmp_particle_num : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;


							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 0 assigned particles. ***" << endl;
								cout << tmp_particle_num << " particles in cell (222)" << endl;
								cout << tmp_particle_num_2 << " particles in cell (313)" << endl;
							}
							break;
#pragma endregion
#pragma region Case_1
						case 1: // Process cells (223) and (321)

							// Get neighbor cell indices (223)
							if (home_cell_x == CELL_COUNT_X - 1) {
								nb_cell_x = 0;
							}
							else {
								nb_cell_x = home_cell_x + 1;
							}
							nb_cell_y = home_cell_y;
							nb_cell_z = home_cell_z;

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in cell (223)
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							// Get neighbor cell indices (321)
							if(home_cell_x == 0){
                nb_cell_x = CELL_COUNT_X - 1;
              }
              else{
                nb_cell_x = home_cell_x - 1;
              }
              nb_cell_y = home_cell_y;
              if(home_cell_z == CELL_COUNT_Z-1){
                nb_cell_z = 0;
              }
              else{
                nb_cell_z = home_cell_z + 1;
              }

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in cell (321)
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;

							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 1 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the cell (223)" << endl;
								cout << tmp_particle_num_2 << " particles in the cell (321)" << endl;
							}
							break;
#pragma endregion						
#pragma region Case_2
						case 2: // Process cell (231), (322)

							// Process the 1st cell
							if(home_cell_x == 0){
                nb_cell_x = CELL_COUNT_X - 1;
              }
              else{
                nb_cell_x = home_cell_x - 1;
              }
              if(home_cell_y == CELL_COUNT_Y-1){
                nb_cell_y = 0;
              }
              else{
                nb_cell_y = home_cell_y + 1;
              }      
							nb_cell_z = home_cell_z;

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in the current evaluated neighbor cell
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							// Process the 2nd cell (322)
							nb_cell_x = home_cell_x;
							nb_cell_y = home_cell_y;
              if(home_cell_z == CELL_COUNT_Z-1){
                nb_cell_z = 0;
              }
              else{
                nb_cell_z = home_cell_z + 1;
              }

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in both evaluated neighbor cells
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;

							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 2 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the 1st cell (231)" << endl;
								cout << tmp_particle_num_2 << " particles in the 2nd cell (322)" << endl;
							}
							break;
#pragma endregion
#pragma region Case_3
						case 3: // Process cell (232) and (323)

							// Process the 1st cell
							nb_cell_x = home_cell_x;
							if (home_cell_y == CELL_COUNT_Y - 1) {
								nb_cell_y = 0;
							}
							else {
								nb_cell_y = home_cell_y + 1;
							}
							nb_cell_z = home_cell_z;

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in the current evaluated neighbor cell
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							// Process the 2nd cell (323)
							if (home_cell_x == CELL_COUNT_X - 1) {
								nb_cell_x = 0;
							}
							else {
								nb_cell_x = home_cell_x + 1;
							}
							nb_cell_y = home_cell_y;
							if (home_cell_z == CELL_COUNT_Z-1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in both evaluated neighbor cells
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;
							
              if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 3 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the 1st cell (232)" << endl;
								cout << tmp_particle_num_2 << " particles in the 2nd cell (323)" << endl;
							}
							break;
#pragma endregion
#pragma region Case_4
						case 4: // Process cell (233) (331)

							// Process the 1st cell (233)
							if (home_cell_x == CELL_COUNT_X-1) {
								nb_cell_x = 0;
							}
							else {
								nb_cell_x = home_cell_x + 1;
							}
							if (home_cell_y == CELL_COUNT_Y-1) {
								nb_cell_y = 0;
							}
							else {
								nb_cell_y = home_cell_y + 1;
							}
							nb_cell_z = home_cell_z;

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in the current evaluated neighbor cell
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							// Process the 2nd cell (331)
							if (home_cell_x == 0) {
								nb_cell_x = CELL_COUNT_X - 1;
							}
							else {
								nb_cell_x = home_cell_x - 1;
							}
							if (home_cell_y == CELL_COUNT_Y-1) {
								nb_cell_y = 0;
							}
							else {
								nb_cell_y = home_cell_y + 1;
							}
							if (home_cell_z == CELL_COUNT_Z-1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in both evaluated neighbor cells
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;

							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 4 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the 1st cell (233)" << endl;
								cout << tmp_particle_num_2 << " particles in the 2nd cell (331)" << endl;
							}
							break;
#pragma endregion
#pragma region Case_5
						case 5: // Process cell (311), (332)

							// Process the 1st cell (311)
							if (home_cell_x == 0) {
								nb_cell_x = CELL_COUNT_X - 1;
							}
							else {
								nb_cell_x = home_cell_x - 1;
							}
              if(home_cell_y == 0){
                nb_cell_y = CELL_COUNT_Y - 1;
              }
              else{
                nb_cell_y = home_cell_y - 1;
              }
							if (home_cell_z == CELL_COUNT_Z-1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in the current evaluated neighbor cell
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];


							// Process the 2nd cell (332)
							nb_cell_x = home_cell_x;
              if(home_cell_y == CELL_COUNT_Y-1){
                nb_cell_y = 0;
              }
              else{
                nb_cell_y = home_cell_y + 1;
              }
              if(home_cell_z == CELL_COUNT_Z-1){
                nb_cell_z = 0;
              }
              else{
                nb_cell_z = home_cell_z + 1;
              }

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in both evaluated neighbor cells
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;

							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 5 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the 1st cell (311)" << endl;
								cout << tmp_particle_num_2 << " particles in the 2nd cell (332)" << endl;
							}
							break;
#pragma endregion
#pragma region Case_6
						case 6: // Process cell (312), (333)

							// Process the 1st cell (312)
							nb_cell_x = home_cell_x;
              if(home_cell_y == 0){
                nb_cell_y = CELL_COUNT_Y - 1;
              }
              else{
                nb_cell_y = home_cell_y - 1;
              }
							if (home_cell_z == CELL_COUNT_Z - 1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id] = nb_cell_id;

							// Get the # of particles in the current evaluated neighbor cell
							tmp_particle_num_1 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							// Process the 2nd cell (333)
							if (home_cell_x == CELL_COUNT_X-1) {
								nb_cell_x = 0;
							}
							else {
								nb_cell_x = home_cell_x + 1;
							}
							if (home_cell_y == CELL_COUNT_Y-1) {
								nb_cell_y = 0;
							}
							else {
								nb_cell_y = home_cell_y + 1;
							}
							if (home_cell_z == CELL_COUNT_Z-1) {
								nb_cell_z = 0;
							}
							else {
								nb_cell_z = home_cell_z + 1;
							}

							// Get the neighbor cell ID
							nb_cell_id = cell_index_calculator(nb_cell_x, nb_cell_y, nb_cell_z);
              neighbor_cell_id[filter_id + NUM_FILTER] = nb_cell_id;

							// Get the # of particles in both evaluated neighbor cells
							tmp_particle_num_2 = particle_in_cell_counter[nb_cell_z][nb_cell_y][nb_cell_x];

							filter_input_particle_num[0][filter_id] = (tmp_particle_num_1 > tmp_particle_num_2) ? tmp_particle_num_1 : tmp_particle_num_2;
							filter_input_particle_num[1][filter_id] = tmp_particle_num_1;
							filter_input_particle_num[2][filter_id] = tmp_particle_num_2;

              neighbor_particle_count[filter_id]              = tmp_particle_num_1;
              neighbor_particle_count[filter_id + NUM_FILTER] = tmp_particle_num_2;

							if (ENABLE_PRINT_DETAIL_MESSAGE) {
								cout << "*** Filter 6 assigned particles. ***" << endl;
								cout << tmp_particle_num_1 << " particles in the 1st cell (312)" << endl;
								cout << tmp_particle_num_2 << " particles in the 2nd cell (333)" << endl;
							}
							break;
#pragma endregion

						default: 
							cout << "*** No matching case for the filter: ***" << filter_id << endl;
							return 1;
						} // switch statement 
					} // Iterate through filters

					if (ENABLE_PRINT_DETAIL_MESSAGE) {
						cout << "\n*** Iteration: " << sim_iter << ", Home cell: " << home_cell_z << home_cell_y << home_cell_x << endl;
						cout << "Mapping cell particles to filters done ***\n" << endl;
					}

					/* Start Evaluation */
					// Home cell id
					int home_cell_id = cell_index_calculator(home_cell_x, home_cell_y, home_cell_z);

					// Home cell particle count
					int home_cell_particle_num = particle_in_cell_counter[home_cell_z][home_cell_y][home_cell_x];

					// Find the max # of particles in any of the neighbor cells.
					// This is the number of iterations for the outer loop
					filter_process_particle_max = *max_element(filter_input_particle_num[0], filter_input_particle_num[0] + NUM_FILTER);

					if (ENABLE_PRINT_DETAIL_MESSAGE) {
						cout << "*** Iteration: " << sim_iter << ", Home cell: " << home_cell_z << home_cell_y << home_cell_x << endl;
						cout << "Max neighbor partlces: " << filter_process_particle_max << endl;
					}
          

					// Force Calculation
					// Declare variables
					float ref_force_x_acc[14];
					float ref_force_y_acc[14];
					float ref_force_z_acc[14];
          float ref_potential_energy_acc[14];
					// - Iterate for the max particle number in all neighbor cells (ref_particle_index)
					for (ref_particle_index = 0; ref_particle_index < filter_process_particle_max; ref_particle_index++){
            if(DEBUG_1_REF_ID){
              if(ref_particle_index == 1){
                return 0;
              }
            }
            // Initialize
            for(i = 0; i < 2*NUM_FILTER; i++){
					    ref_force_x_acc[i] = 0.0;
					    ref_force_y_acc[i] = 0.0;
					    ref_force_z_acc[i] = 0.0;
              ref_potential_energy_acc[i] = 0.0;
            }

					  // - For first 7 neighbors
					  for(filter_id = 0; filter_id < NUM_FILTER; filter_id++){
              // Continue if the neighbor cell have less than ref_particle_index particles.
              if(neighbor_particle_count[filter_id] <= ref_particle_index){
                continue;
              }

              ref_pos_x = cell_particle[0][neighbor_cell_id[filter_id]][ref_particle_index];
              ref_pos_y = cell_particle[1][neighbor_cell_id[filter_id]][ref_particle_index];
              ref_pos_z = cell_particle[2][neighbor_cell_id[filter_id]][ref_particle_index];

					    // - Iterate over all home cell particles
					    for(nb_particle_index = 0; nb_particle_index < home_cell_particle_num; nb_particle_index++){
                nb_pos_x = cell_particle[0][home_cell_id][nb_particle_index];
                nb_pos_y = cell_particle[1][home_cell_id][nb_particle_index];
                nb_pos_z = cell_particle[2][home_cell_id][nb_particle_index];

								// Calculate dx, dy, dz, r2
								dx = ref_pos_x - nb_pos_x;
								dy = ref_pos_y - nb_pos_y;
								dz = ref_pos_z - nb_pos_z;

								// Apply periodic boundary conditions
								dx -= BOUNDING_BOX_SIZE_X * round(dx / BOUNDING_BOX_SIZE_X);
								dy -= BOUNDING_BOX_SIZE_Y * round(dy / BOUNDING_BOX_SIZE_Y);
								dz -= BOUNDING_BOX_SIZE_Z * round(dz / BOUNDING_BOX_SIZE_Z);

								// Evaluate r2
								r2 = dx * dx + dy * dy + dz * dz;
								float inv_r2 = 1.0 / r2;

                if(PRINT_PAIRS && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && sim_iter == 1){
                  cout << setprecision(12) << endl;
                  cout << "refID: " << ref_particle_index + 1 << "\tnbID: " << nb_particle_index + 1 << endl;
                  cout << "home_cell: " << home_cell_id << "\tnb_cell: " << neighbor_cell_id[filter_id] << "\tfilter: " << filter_id << endl;
                  cout << "Neighbor cell particle count: " << neighbor_particle_count[filter_id] << endl;
                  cout << "P1:\t" << ref_pos_x << "\t" << ref_pos_y << "\t" << ref_pos_z << endl;
                  cout << "P2:\t" << nb_pos_x << "\t" << nb_pos_y << "\t" << nb_pos_z << endl;
                  cout << "Diff:\t" << dx << "\t" << dy << "\t" << dz << endl;
                  cout << "R2:\t" << r2 << "\t" << inv_r2 << endl;
								  if (r2 >= EXCLUSION_2 && r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
                    cout << "Filter PASS" << endl;
                  }
                  else{
                    cout << "Filter FAIL" << endl;
                  }
                }

								// Pass the filter
								// Also check for particle_id > ref_id for home cell
								if (r2 >= EXCLUSION_2 && r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
								//if (r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
								//if (abs(dx) < CUTOFF_RADIUS && abs(dy) < CUTOFF_RADIUS &&  abs(dz) < CUTOFF_RADIUS &&
                //    abs(dx)+abs(dy) < sqrt(2)*CUTOFF_RADIUS && abs(dx)+abs(dz) < sqrt(2)*CUTOFF_RADIUS && abs(dy)+abs(dz) < sqrt(2)*CUTOFF_RADIUS &&
                //    abs(dx)+abs(dy)+abs(dz) < sqrt(3)*CUTOFF_RADIUS &&
                //    (filter_id > 0 | nb_particle_index > ref_particle_index)){
									tmp_counter_particles_within_cutoff += 1;
									float vdw_14, vdw_8, vdw_12, vdw_6;
									int lut_index;
									int tmp_nb_cell_id;
									int nb_particle_index_of_cell;
									if (ENABLE_INTERPOLATION) {
										seg_index = 0;
										while (r2 >= MIN_RANGE * pow(2, seg_index + 1)) {
											seg_index += 1;
										}
										if (seg_index >= SEGMENT_NUM) {
											cout << "seg_index: " << seg_index << endl;
											cout << "SEGMENT_NUM: " << SEGMENT_NUM << endl;
											cout << "*** Error: cannot locate the segment for input r2 ***" << endl;
											return 1;
										}

										// Locate the bin in the current segment
										float seg_min = MIN_RANGE * pow(2, seg_index);
										float seg_max = seg_min * 2;
										float seg_stride = (seg_max - seg_min) / BIN_NUM;
										int bin_index = (int)((r2 - seg_min) / seg_stride);

										// Calculate the index for table lookup
										lut_index = seg_index * BIN_NUM + bin_index;

										// Fetch the index for the polynomials
										float c0_vdw14 = c0_vdw_list_14[lut_index];
										float c1_vdw14 = c1_vdw_list_14[lut_index];
										float c0_vdw8 = c0_vdw_list_8[lut_index];
										float c1_vdw8 = c1_vdw_list_8[lut_index];
										float c2_vdw14 = 0;
										float c2_vdw8 = 0;
										float c3_vdw14 = 0;
										float c3_vdw8 = 0;
										if (INTERPOLATION_ORDER > 1) {
											c2_vdw14 = c2_vdw_list_14[lut_index];
											c2_vdw8 = c2_vdw_list_8[lut_index];
										}
										if (INTERPOLATION_ORDER > 2) {
											c3_vdw14 = c3_vdw_list_14[lut_index];
											c3_vdw8 = c3_vdw_list_8[lut_index];
										}

										// Declare the two terms of L-J force / r
										switch (INTERPOLATION_ORDER) {
										case 1:
											vdw_14 = c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c1_vdw8 * r2 + c0_vdw8;
											break;
										case 2:
											vdw_14 = c2_vdw14 * r2 * r2 + c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c2_vdw8 * r2 * r2 + c1_vdw8 * r2 + c0_vdw8;
											break;
										case 3:
											vdw_14 = c3_vdw14 * r2 * r2 * r2 + c2_vdw14 * r2 * r2 + c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c3_vdw8 * r2 * r2 * r2 + c2_vdw8 * r2 * r2 + c1_vdw8 * r2 + c0_vdw8;
											break;
										default:
											cout << "*** Error: No match for INTERPOLATION_ORDER ***" << endl;
											return 1;
										}
									}
									// Direct evaluation
									else {
										vdw_14 = OUTPUT_SCALE_INDEX * 48 * EPS * pow(SIGMA, 12) * pow(inv_r2, 7);
										vdw_8 = OUTPUT_SCALE_INDEX * 24 * EPS * pow(SIGMA, 6) * pow(inv_r2, 4);
									}

									// Calculate the total force, F_LJ is not the actual force, but force / r
									float F_LJ = (vdw_14 - vdw_8) * 1000;	// EPS should be kJ/particle instead of kJ/mol, so here multiply by 1000, from kN to N

									// Calculate the force components
									float F_LJ_x = F_LJ * dx;
									float F_LJ_y = F_LJ * dy;
									float F_LJ_z = F_LJ * dz;

									// Get force for neighbor particles
									float neg_F_LJ_x = -1 * F_LJ_x;
									float neg_F_LJ_y = -1 * F_LJ_y;
									float neg_F_LJ_z = -1 * F_LJ_z;

                  // Partial force write back values for home cell particles
									if (DEBUG_PARTIAL_FORCE && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0) {
                    cout << setprecision(12) << endl;
										cout << "F_LJ_x: " << neg_F_LJ_x / MASS_Nav << "\t";
                    floatToHex(F_LJ_x / MASS_Nav);
										cout << "F_LJ_y: " << neg_F_LJ_y / MASS_Nav << "\t";
                    floatToHex(F_LJ_y / MASS_Nav);
										cout << "F_LJ_z: " << neg_F_LJ_z / MASS_Nav << "\t";
                    floatToHex(F_LJ_z / MASS_Nav);
                    cout << std::dec;
										cout << "dx: " << dx << endl;
										cout << "dy: " << dy << endl;
										cout << "dz: " << dz << endl;
										cout << "r2: " << r2 << endl;
										cout << "filter: " << filter_id << endl;
										cout << "ref_index: " << ref_particle_index + 1 << endl; // +1 to match RTL
										cout << "nb_index: " << nb_particle_index + 1 << endl; // +1 to match RTL
										cout << endl;
									}

									if (PRINT_FORCE && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0 && filter_id == 13){
                    cout << setprecision(12) << "nb_PID=" << nb_particle_index + 1 << "\t" << F_LJ_x / MASS_Nav << "\t" << F_LJ_y / MASS_Nav << "\t" << F_LJ_z / MASS_Nav << endl;
                  }

									// Accumulate force for reference particles
									// filter_id variable follows the neighbor number in the half shell scheme.
									ref_force_x_acc[filter_id] += F_LJ_x;
									ref_force_y_acc[filter_id] += F_LJ_y;
									ref_force_z_acc[filter_id] += F_LJ_z;

                  // Write force values to particle data structure
                  cell_particle[3][home_cell_id][nb_particle_index] += neg_F_LJ_x;
                  cell_particle[4][home_cell_id][nb_particle_index] += neg_F_LJ_y;
                  cell_particle[5][home_cell_id][nb_particle_index] += neg_F_LJ_z;

                  // {XYZ} {000 = 0} {321 = 27} {222 = 42} {133 = 61}
                  if(PRINT_SINGLE_PARTICLE && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && nb_particle_index == 0 && sim_iter == 0){
                    cout << setprecision(12) << std::dec;
                    //cout << endl;
                    //cout << "refPos:\t" << ref_pos_x << "\t" << ref_pos_y << "\t" << ref_pos_z << endl;
                    //cout << "nbPos:\t" << nb_pos_x << "\t" << nb_pos_y << "\t" << nb_pos_z << endl;
                    //cout << "Diff:\t" << dx << "\t" << dy << "\t" << dz << endl;
                    //cout << "R2:\t" << r2 << "\t" << inv_r2 << endl;
                    cout << "nbPID=" << nb_particle_index+1 << "\t" << neg_F_LJ_x/MASS_Nav << "\t" << neg_F_LJ_y/MASS_Nav << "\t" << neg_F_LJ_z/MASS_Nav << endl;
                  }
                  
                  //if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0 && sim_iter == 1 && ref_particle_index == 0){
                  if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 2 && home_cell_y == 2 && home_cell_x == 2){
                    cout << "nbPID=" << nb_particle_index + 1 << "\t" << neg_F_LJ_x/MASS_Nav << "\t" << neg_F_LJ_y/MASS_Nav << "\t" << neg_F_LJ_z/MASS_Nav << endl;
                  }


                  // Potential energy calculation
									if (ENABLE_ENERGY_EVALUATION){
										if (ENABLE_INTERPOLATION) {
											float c0_vdw12 = c0_vdw_list_12[lut_index];
											float c1_vdw12 = c1_vdw_list_12[lut_index];
											float c0_vdw6 = c0_vdw_list_6[lut_index];
											float c1_vdw6 = c1_vdw_list_6[lut_index];
											float c2_vdw12 = 0;
											float c2_vdw6 = 0;
											float c3_vdw12 = 0;
											float c3_vdw6 = 0;
											if (INTERPOLATION_ORDER > 1) {
												c2_vdw12 = c2_vdw_list_12[lut_index];
												c2_vdw6 = c2_vdw_list_6[lut_index];
											}
											if (INTERPOLATION_ORDER > 2) {
												c3_vdw12 = c3_vdw_list_12[lut_index];
												c3_vdw6 = c3_vdw_list_6[lut_index];
											}

											// Declare the two terms of L-J potential
											switch (INTERPOLATION_ORDER) {
											case 1:
												vdw_12 = c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c1_vdw6 * r2 + c0_vdw6;
												break;
											case 2:
												vdw_12 = c2_vdw12 * r2 * r2 + c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c2_vdw6 * r2 * r2 + c1_vdw6 * r2 + c0_vdw6;
												break;
											case 3:
												vdw_12 = c3_vdw12 * r2 * r2 * r2 + c2_vdw12 * r2 * r2 + c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c3_vdw6 * r2 * r2 * r2 + c2_vdw6 * r2 * r2 + c1_vdw6 * r2 + c0_vdw6;
												break;
											default:
												cout << "*** Error: No match for INTERPOLATION_ORDER ***" << endl;
												return 1;
											}
										}
										// Direct computation
										else {
											vdw_12 = OUTPUT_SCALE_INDEX * 4 * EPS * pow(SIGMA, 12) * pow(inv_r2, 6);
											vdw_6 = OUTPUT_SCALE_INDEX * 4 * EPS * pow(SIGMA, 6) * pow(inv_r2, 3);
										}

										// Calculate LJ potential
										float E_LJ = (vdw_12 - vdw_6) / Nav; // EPS should be kJ/particle instead of kJ/mol
									  // Accumulate force for reference particles
									  // filter_id variable follows the neighbor number in the half shell scheme.
									  ref_potential_energy_acc[filter_id] += E_LJ;

                    // Write potential value to the home cell particle
                    cell_particle[9][home_cell_id][nb_particle_index] += E_LJ;
                  } // if energy computation is enabled
										
                } // if passed filter
              } //iterate nb_particle_index
					  } //filter_id 0-6

					  // - For second  7 neighbors
					  for(filter_id = NUM_FILTER; filter_id < 2*NUM_FILTER; filter_id++){
              // Continue if the neighbor cell have less than ref_particle_index particles.
              if(neighbor_particle_count[filter_id] <= ref_particle_index){
                continue;
              }

              ref_pos_x = cell_particle[0][neighbor_cell_id[filter_id]][ref_particle_index];
              ref_pos_y = cell_particle[1][neighbor_cell_id[filter_id]][ref_particle_index];
              ref_pos_z = cell_particle[2][neighbor_cell_id[filter_id]][ref_particle_index];

					    // - Iterate over all home cell particles
					    for(nb_particle_index = 0; nb_particle_index < home_cell_particle_num; nb_particle_index++){
                nb_pos_x = cell_particle[0][home_cell_id][nb_particle_index];
                nb_pos_y = cell_particle[1][home_cell_id][nb_particle_index];
                nb_pos_z = cell_particle[2][home_cell_id][nb_particle_index];

								// Calculate dx, dy, dz, r2
								dx = ref_pos_x - nb_pos_x;
								dy = ref_pos_y - nb_pos_y;
								dz = ref_pos_z - nb_pos_z;

								// Apply periodic boundary conditions
								dx -= BOUNDING_BOX_SIZE_X * round(dx / BOUNDING_BOX_SIZE_X);
								dy -= BOUNDING_BOX_SIZE_Y * round(dy / BOUNDING_BOX_SIZE_Y);
								dz -= BOUNDING_BOX_SIZE_Z * round(dz / BOUNDING_BOX_SIZE_Z);

								// Evaluate r2
								r2 = dx * dx + dy * dy + dz * dz;
								float inv_r2 = 1.0 / r2;

                if(PRINT_PAIRS && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && sim_iter == 1){
                  cout << setprecision(12) << endl;
                  cout << "refID: " << ref_particle_index + 1 << "\tnbID: " << nb_particle_index + 1 << endl;
                  cout << "home_cell: " << home_cell_id << "\tnb_cell: " << neighbor_cell_id[filter_id] << "\tfilter: " << filter_id << endl;
                  cout << "Neighbor cell particle count: " << neighbor_particle_count[filter_id] << endl;
                  cout << "P1:\t" << ref_pos_x << "\t" << ref_pos_y << "\t" << ref_pos_z << endl;
                  cout << "P2:\t" << nb_pos_x << "\t" << nb_pos_y << "\t" << nb_pos_z << endl;
                  cout << "Diff:\t" << dx << "\t" << dy << "\t" << dz << endl;
                  cout << "R2:\t" << r2 << "\t" << inv_r2 << endl;
								  if (r2 >= EXCLUSION_2 && r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
                    cout << "Filter PASS" << endl;
                  }
                  else{
                    cout << "Filter FAIL" << endl;
                  }
                }

								// Pass the filter
								// Also check for particle_id > ref_id for home cell
								if (r2 >= EXCLUSION_2 && r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
								//if (r2 < CUTOFF_RADIUS_2 && (filter_id > 0 | nb_particle_index > ref_particle_index)){
								//if (abs(dx) < CUTOFF_RADIUS && abs(dy) < CUTOFF_RADIUS &&  abs(dz) < CUTOFF_RADIUS &&
                //    abs(dx)+abs(dy) < sqrt(2)*CUTOFF_RADIUS && abs(dx)+abs(dz) < sqrt(2)*CUTOFF_RADIUS && abs(dy)+abs(dz) < sqrt(2)*CUTOFF_RADIUS &&
                //    abs(dx)+abs(dy)+abs(dz) < sqrt(3)*CUTOFF_RADIUS &&
                //    (filter_id > 0 | nb_particle_index > ref_particle_index)){
									tmp_counter_particles_within_cutoff += 1;
									float vdw_14, vdw_8, vdw_12, vdw_6;
									int lut_index;
									int tmp_nb_cell_id;
									int nb_particle_index_of_cell;
									if (ENABLE_INTERPOLATION) {
										seg_index = 0;
										while (r2 >= MIN_RANGE * pow(2, seg_index + 1)) {
											seg_index += 1;
										}
										if (seg_index >= SEGMENT_NUM) {
											cout << "seg_index: " << seg_index << endl;
											cout << "SEGMENT_NUM: " << SEGMENT_NUM << endl;
											cout << "*** Error: cannot locate the segment for input r2 ***" << endl;
											return 1;
										}

										// Locate the bin in the current segment
										float seg_min = MIN_RANGE * pow(2, seg_index);
										float seg_max = seg_min * 2;
										float seg_stride = (seg_max - seg_min) / BIN_NUM;
										int bin_index = (int)((r2 - seg_min) / seg_stride);

										// Calculate the index for table lookup
										lut_index = seg_index * BIN_NUM + bin_index;

										// Fetch the index for the polynomials
										float c0_vdw14 = c0_vdw_list_14[lut_index];
										float c1_vdw14 = c1_vdw_list_14[lut_index];
										float c0_vdw8 = c0_vdw_list_8[lut_index];
										float c1_vdw8 = c1_vdw_list_8[lut_index];
										float c2_vdw14 = 0;
										float c2_vdw8 = 0;
										float c3_vdw14 = 0;
										float c3_vdw8 = 0;
										if (INTERPOLATION_ORDER > 1) {
											c2_vdw14 = c2_vdw_list_14[lut_index];
											c2_vdw8 = c2_vdw_list_8[lut_index];
										}
										if (INTERPOLATION_ORDER > 2) {
											c3_vdw14 = c3_vdw_list_14[lut_index];
											c3_vdw8 = c3_vdw_list_8[lut_index];
										}

										// Declare the two terms of L-J force / r
										switch (INTERPOLATION_ORDER) {
										case 1:
											vdw_14 = c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c1_vdw8 * r2 + c0_vdw8;
											break;
										case 2:
											vdw_14 = c2_vdw14 * r2 * r2 + c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c2_vdw8 * r2 * r2 + c1_vdw8 * r2 + c0_vdw8;
											break;
										case 3:
											vdw_14 = c3_vdw14 * r2 * r2 * r2 + c2_vdw14 * r2 * r2 + c1_vdw14 * r2 + c0_vdw14;
											vdw_8 = c3_vdw8 * r2 * r2 * r2 + c2_vdw8 * r2 * r2 + c1_vdw8 * r2 + c0_vdw8;
											break;
										default:
											cout << "*** Error: No match for INTERPOLATION_ORDER ***" << endl;
											return 1;
										}
									}
									// Direct evaluation
									else {
										vdw_14 = OUTPUT_SCALE_INDEX * 48 * EPS * pow(SIGMA, 12) * pow(inv_r2, 7);
										vdw_8 = OUTPUT_SCALE_INDEX * 24 * EPS * pow(SIGMA, 6) * pow(inv_r2, 4);
									}

									// Calculate the total force, F_LJ is not the actual force, but force / r
									float F_LJ = (vdw_14 - vdw_8) * 1000;	// EPS should be kJ/particle instead of kJ/mol, so here multiply by 1000, from kN to N

									// Calculate the force components
									float F_LJ_x = F_LJ * dx;
									float F_LJ_y = F_LJ * dy;
									float F_LJ_z = F_LJ * dz;

									// Get force for neighbor particles
									float neg_F_LJ_x = -1 * F_LJ_x;
									float neg_F_LJ_y = -1 * F_LJ_y;
									float neg_F_LJ_z = -1 * F_LJ_z;

                  // Partial force write back values for home cell particles
									if (DEBUG_PARTIAL_FORCE && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0) {
                    cout << setprecision(12) << endl;
										cout << "F_LJ_x: " << neg_F_LJ_x / MASS_Nav << "\t";
                    floatToHex(F_LJ_x / MASS_Nav);
										cout << "F_LJ_y: " << neg_F_LJ_y / MASS_Nav << "\t";
                    floatToHex(F_LJ_y / MASS_Nav);
										cout << "F_LJ_z: " << neg_F_LJ_z / MASS_Nav << "\t";
                    floatToHex(F_LJ_z / MASS_Nav);
                    cout << std::dec;
										cout << "dx: " << dx << endl;
										cout << "dy: " << dy << endl;
										cout << "dz: " << dz << endl;
										cout << "r2: " << r2 << endl;
										cout << "filter: " << filter_id << endl;
										cout << "ref_index: " << ref_particle_index + 1 << endl; // +1 to match RTL
										cout << "nb_index: " << nb_particle_index + 1 << endl; // +1 to match RTL
										cout << endl;
									}
									if (PRINT_FORCE && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0 && filter_id == 13){
                    cout << setprecision(12) << "nb_PID=" << nb_particle_index + 1 << "\t" << F_LJ_x / MASS_Nav << "\t" << F_LJ_y / MASS_Nav << "\t" << F_LJ_z / MASS_Nav << endl;
                  }

									// Accumulate force for reference particles
									// filter_id variable follows the neighbor number in the half shell scheme.
									ref_force_x_acc[filter_id] += F_LJ_x;
									ref_force_y_acc[filter_id] += F_LJ_y;
									ref_force_z_acc[filter_id] += F_LJ_z;

                  // Write force values to particle data structure
                  cell_particle[3][home_cell_id][nb_particle_index] += neg_F_LJ_x;
                  cell_particle[4][home_cell_id][nb_particle_index] += neg_F_LJ_y;
                  cell_particle[5][home_cell_id][nb_particle_index] += neg_F_LJ_z;

                  // {XYZ} {000 = 0} {321 = 27} {222 = 42} {133 = 61}
                  if(PRINT_SINGLE_PARTICLE && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && nb_particle_index == 0 && sim_iter == 0){
                    cout << setprecision(12) << std::dec;
                    //cout << endl;
                    //cout << "refPos:\t" << ref_pos_x << "\t" << ref_pos_y << "\t" << ref_pos_z << endl;
                    //cout << "nbPos:\t" << nb_pos_x << "\t" << nb_pos_y << "\t" << nb_pos_z << endl;
                    //cout << "Diff:\t" << dx << "\t" << dy << "\t" << dz << endl;
                    //cout << "R2:\t" << r2 << "\t" << inv_r2 << endl;
                    cout << "nbPID=" << nb_particle_index+1 << "\t" << neg_F_LJ_x/MASS_Nav << "\t" << neg_F_LJ_y/MASS_Nav << "\t" << neg_F_LJ_z/MASS_Nav << endl;
                  }

                  //if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0 && sim_iter == 1 && ref_particle_index == 0){
                  if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 2 && home_cell_y == 2 && home_cell_x == 2){
                    cout << "nbPID=" << nb_particle_index + 1 << "\t" << neg_F_LJ_x/MASS_Nav << "\t" << neg_F_LJ_y/MASS_Nav << "\t" << neg_F_LJ_z/MASS_Nav << endl;
                  }

                  // Potential energy calculation
									if (ENABLE_ENERGY_EVALUATION){
										if (ENABLE_INTERPOLATION) {
											float c0_vdw12 = c0_vdw_list_12[lut_index];
											float c1_vdw12 = c1_vdw_list_12[lut_index];
											float c0_vdw6 = c0_vdw_list_6[lut_index];
											float c1_vdw6 = c1_vdw_list_6[lut_index];
											float c2_vdw12 = 0;
											float c2_vdw6 = 0;
											float c3_vdw12 = 0;
											float c3_vdw6 = 0;
											if (INTERPOLATION_ORDER > 1) {
												c2_vdw12 = c2_vdw_list_12[lut_index];
												c2_vdw6 = c2_vdw_list_6[lut_index];
											}
											if (INTERPOLATION_ORDER > 2) {
												c3_vdw12 = c3_vdw_list_12[lut_index];
												c3_vdw6 = c3_vdw_list_6[lut_index];
											}

											// Declare the two terms of L-J potential
											switch (INTERPOLATION_ORDER) {
											case 1:
												vdw_12 = c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c1_vdw6 * r2 + c0_vdw6;
												break;
											case 2:
												vdw_12 = c2_vdw12 * r2 * r2 + c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c2_vdw6 * r2 * r2 + c1_vdw6 * r2 + c0_vdw6;
												break;
											case 3:
												vdw_12 = c3_vdw12 * r2 * r2 * r2 + c2_vdw12 * r2 * r2 + c1_vdw12 * r2 + c0_vdw12;
												vdw_6 = c3_vdw6 * r2 * r2 * r2 + c2_vdw6 * r2 * r2 + c1_vdw6 * r2 + c0_vdw6;
												break;
											default:
												cout << "*** Error: No match for INTERPOLATION_ORDER ***" << endl;
												return 1;
											}
										}
										// Direct computation
										else {
											vdw_12 = OUTPUT_SCALE_INDEX * 4 * EPS * pow(SIGMA, 12) * pow(inv_r2, 6);
											vdw_6 = OUTPUT_SCALE_INDEX * 4 * EPS * pow(SIGMA, 6) * pow(inv_r2, 3);
										}

										// Calculate LJ potential
										float E_LJ = (vdw_12 - vdw_6) / Nav; // EPS should be kJ/particle instead of kJ/mol
									  // Accumulate force for reference particles
									  // filter_id variable follows the neighbor number in the half shell scheme.
									  ref_potential_energy_acc[filter_id] += E_LJ;

                    // Write potential value to the home cell particle
                    cell_particle[9][home_cell_id][nb_particle_index] += E_LJ;
                  } // if enert computation is enabled
										
                } // if passed filter
              } //iterate nb_particle_index
					  } // filter_id 7-13

            // Writeback accumulated forces to the particle data structure
            for(i=0; i<14; i++){
              cell_particle[3][neighbor_cell_id[i]][ref_particle_index] += ref_force_x_acc[i];
              cell_particle[4][neighbor_cell_id[i]][ref_particle_index] += ref_force_y_acc[i];
              cell_particle[5][neighbor_cell_id[i]][ref_particle_index] += ref_force_z_acc[i];

              // {XYZ} {000 = 0} {321 = 27} {222 = 42} {133 = 61}
              if(PRINT_SINGLE_PARTICLE && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && ref_particle_index == 0 && i == 0 && sim_iter == 0){
                cout << setprecision(12) << std::dec << endl;
                cout << "refPID=" << ref_particle_index+1 << "\t" << ref_force_x_acc[i]/MASS_Nav << "\t" << ref_force_y_acc[i]/MASS_Nav << "\t" << ref_force_z_acc[i]/MASS_Nav << endl;
                //cout << "\nChange ref ID. Next ID=" << ref_particle_index+2 << endl;
              }
            }

            //if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0 && sim_iter == 1 && ref_particle_index == 0){
            if(PRINT_FORCE_DISTRIBUTOR_OUTPUT && home_cell_z == 2 && home_cell_y == 2 && home_cell_x == 2){
              cout << "\nStart writing back forces ref particles." << endl;
              cout << setprecision(12) << std::dec << endl;
              for(i=0; i<14; i++){
                cout << "neighbor=" << i << "\t" << ref_force_x_acc[i]/MASS_Nav << "\t" << ref_force_y_acc[i]/MASS_Nav << "\t" << ref_force_z_acc[i]/MASS_Nav << endl;
              }
              cout << "\nChange ref ID " << ref_particle_index + 1 << "\n" << endl;
            }

						if (PRINT_FORCE && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0){
              cout << "\nChange ref ID. Next ref_ID=" << ref_particle_index + 2 << endl;
              cout << endl;
            }

            // Writeback accumulated potential energy values to the particle data structure
            if(ENABLE_ENERGY_EVALUATION){
              for(i=0; i<14; i++){
                cell_particle[9][neighbor_cell_id[i]][ref_particle_index] += ref_potential_energy_acc[i];
              }
            }
            
            // Print accumulated forces for the ref particles
            // This is equivelant to the force writebacks 
            if(DEBUG_PARTIAL_FORCE && ref_particle_index == 0 && home_cell_z == 0 && home_cell_y == 0 && home_cell_x == 0) {
              cout << endl;
              cout << "Accumulated forces for reference particles" << endl;
              for(int ct = 0; ct < 2*NUM_FILTER; ct++){
                cout << setprecision(12) << std::dec;
                cout << "neighbor: " << ct << endl;
                cout << "F_LJ_x: " << ref_force_x_acc[ct] / MASS_Nav << "\t";
                floatToHex(ref_force_x_acc[ct] / MASS_Nav);
                cout << "F_LJ_y: " << ref_force_y_acc[ct] / MASS_Nav << "\t";
                floatToHex(ref_force_y_acc[ct] / MASS_Nav);
                cout << "F_LJ_z: " << ref_force_z_acc[ct] / MASS_Nav << "\t";
                floatToHex(ref_force_z_acc[ct] / MASS_Nav);
                cout << endl;
              }
              cout << "Ref ID " << ref_particle_index << "done." << endl;
              cout << endl;
            }

            // {XYZ} {000 = 0} {321 = 27} {222 = 42} {133 = 61}
            if(PRINT_SINGLE_PARTICLE && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2 && sim_iter == 0){
              cout << "\nChange ref ID. Next ID=" << ref_particle_index+2 << endl;
            }

            if(PRINT_PAIRS && home_cell_x == 2 && home_cell_y == 2 && home_cell_z == 2){
              cout << "\n\nChange ref ID. Next ID=" << ref_particle_index+2 << endl;
            }

					} // Iterate ref_particle_index
					

					// Print out which home cell is done processing
					if (ENABLE_PRINT_DETAIL_MESSAGE) {
						cout << "*** Home cell " << home_cell_z << home_cell_y << home_cell_x << " force evaluation done! ***" << endl;
					}

				} // home cell z loop
			} // home cell y loop
    } // home cell x loop


		/* Energy Evaluation: Individual Kinetic Energy and System Total Energy */
		if (ENABLE_ENERGY_EVALUATION) {
			double potential_energy_acc = 0;
			double kinetic_energy_acc = 0;
			for (home_cell_x = 0; home_cell_x < CELL_COUNT_X; home_cell_x++) {
				for (home_cell_y = 0; home_cell_y < CELL_COUNT_Y; home_cell_y++) {
					for (home_cell_z = 0; home_cell_z < CELL_COUNT_Z; home_cell_z++) {
						int home_cell_id = cell_index_calculator(home_cell_x, home_cell_y, home_cell_z);
						int home_cell_particle_num = particle_in_cell_counter[home_cell_z][home_cell_y][home_cell_x];
						int particle_index;
						for (particle_index = 0; particle_index < home_cell_particle_num; particle_index++) {
							
							// Evaluate the individual kinetic energy first
							float v_x = cell_particle[6][home_cell_id][particle_index];
							float v_y = cell_particle[7][home_cell_id][particle_index];
							float v_z = cell_particle[8][home_cell_id][particle_index];
							float v2 = v_x * v_x + v_y * v_y + v_z * v_z;

							// Kinetic energy
							float Ek = 0.5 * MASS * v2;
							cell_particle[10][home_cell_id][particle_index] = Ek;

							// Evaluate the total energy
							potential_energy_acc += cell_particle[9][home_cell_id][particle_index];
							kinetic_energy_acc += cell_particle[10][home_cell_id][particle_index];
						}
					}
				}
			}
			kinetic_energy_acc *= 1E-3; // J to kJ
			energy_data_history[0] = potential_energy_acc / 2;
			energy_data_history[1] = kinetic_energy_acc; // kJ
			energy_data_history[2] = potential_energy_acc / 2 + kinetic_energy_acc; // kJ

			if (ENABLE_OUTPUT_ENERGY_FILE) {
				output_file << sim_iter << '\t';
				output_file << setprecision(17);
				output_file << energy_data_history[0] << '\t'
					<< energy_data_history[1] << '\t' << energy_data_history[2] << endl;
			}
		}


    /* Motion Update */
		// Clear the tmp arrays
		if(DEBUG){
      cout << "Start motion update." << endl;
    }
		set_to_zeros_3d_int(tmp_particle_in_cell_counter, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);
		set_to_zeros_3d(tmp_cell_particle, CELL_PARTICLE_MAX, CELL_COUNT_TOTAL, 12);
		if(DEBUG){
      cout << "Zero out temp arrays." << endl;
    }

		// Traverse all cells
		for (home_cell_z = 0; home_cell_z < CELL_COUNT_Z; home_cell_z++) {
			float z_min = home_cell_z * CUTOFF_RADIUS;
			float z_max = (home_cell_z + 1) * CUTOFF_RADIUS;
			for (home_cell_y = 0; home_cell_y < CELL_COUNT_Y; home_cell_y++) {
				float y_min = home_cell_y * CUTOFF_RADIUS;
				float y_max = (home_cell_y + 1) * CUTOFF_RADIUS;
				for (home_cell_x = 0; home_cell_x < CELL_COUNT_X; home_cell_x++) {
					float x_min = home_cell_x * CUTOFF_RADIUS;
					float x_max = (home_cell_x + 1) * CUTOFF_RADIUS;
					int cell_id = cell_index_calculator(home_cell_x, home_cell_y, home_cell_z);
          if(CELL_MAP_DEBUG && home_cell_z == 1 & home_cell_y == 2 && home_cell_x == 3){
            cout << cell_id << "\t\t" << home_cell_z << "\t" << home_cell_y << "\t" << home_cell_x << "\t" << particle_in_cell_counter[home_cell_z][home_cell_y][home_cell_x] <<endl;
          }
					int particle_index;

					// Traverse each particle in cell
					for (particle_index = 0; particle_index < particle_in_cell_counter[home_cell_z][home_cell_y][home_cell_x]; particle_index++){
						// Fetch the current values
						float pos_x = cell_particle[0][cell_id][particle_index];
						float pos_y = cell_particle[1][cell_id][particle_index];
						float pos_z = cell_particle[2][cell_id][particle_index];
						float force_x = cell_particle[3][cell_id][particle_index];
						float force_y = cell_particle[4][cell_id][particle_index];
						float force_z = cell_particle[5][cell_id][particle_index];
						float v_x = cell_particle[6][cell_id][particle_index];
						float v_y = cell_particle[7][cell_id][particle_index];
						float v_z = cell_particle[8][cell_id][particle_index];

            if(CELL_MAP_DEBUG && home_cell_z == 1 & home_cell_y == 2 && home_cell_x == 3){
              cout << "original => nbID=" << particle_index << "\t" << pos_z << "\t" << pos_y << "\t" << pos_x << endl;
            }

            if(PRINT_FULL_FORCES && home_cell_x == 3 && home_cell_y == 2 && home_cell_z == 1 && sim_iter == 1){
              cout << setprecision(12) << std::dec;
              cout << "PID=" << particle_index + 1; // +1 to match the indexing in RTL
              cout << "\t" << force_x / MASS_Nav << "\t";
              floatToHex_inline(force_x / MASS_Nav);
              cout << "\t" << force_y / MASS_Nav << "\t";
              floatToHex_inline(force_y / MASS_Nav);
              cout << "\t" << force_z / MASS_Nav << "\t";
              floatToHex_inline(force_z / MASS_Nav);
              cout << endl;
            }

						// Update velocity
						v_x += (force_x / MASS_Nav) * SIMULATION_TIME_STEP;
						v_y += (force_y / MASS_Nav) * SIMULATION_TIME_STEP;
						v_z += (force_z / MASS_Nav) * SIMULATION_TIME_STEP;

						// Update position
						float move_x = v_x * SIMULATION_TIME_STEP;
						float move_y = v_y * SIMULATION_TIME_STEP;
						float move_z = v_z * SIMULATION_TIME_STEP;
						pos_x += move_x;
						pos_y += move_y;
						pos_z += move_z;

						// Apply boundary conditions to the new position
						pos_x < 0 ? pos_x = fmod(pos_x, -1 * BOUNDING_BOX_SIZE_X) + BOUNDING_BOX_SIZE_X : pos_x = fmod(pos_x, BOUNDING_BOX_SIZE_X);
						pos_y < 0 ? pos_y = fmod(pos_y, -1 * BOUNDING_BOX_SIZE_Y) + BOUNDING_BOX_SIZE_Y : pos_y = fmod(pos_y, BOUNDING_BOX_SIZE_Y);
						pos_z < 0 ? pos_z = fmod(pos_z, -1 * BOUNDING_BOX_SIZE_Z) + BOUNDING_BOX_SIZE_Z : pos_z = fmod(pos_z, BOUNDING_BOX_SIZE_Z);
            if(CELL_MAP_DEBUG && home_cell_z == 1 & home_cell_y == 2 && home_cell_x == 3){
              cout << "updated => nbID=" << particle_index << "\t" << pos_z << "\t" << pos_y << "\t" << pos_x << endl;
            }

						// In case the small number is eaten by the big number so the position = bounding box size
						if (pos_x == BOUNDING_BOX_SIZE_X) {
							pos_x = 0;
						}
						if (pos_y == BOUNDING_BOX_SIZE_Y) {
							pos_y = 0;
						}
						if (pos_z == BOUNDING_BOX_SIZE_Z) {
							pos_z = 0;
						}

						// The particle may move to a new cell, get the cell coordinates
						int target_cell_x = (int)(pos_x / CUTOFF_RADIUS);
						int target_cell_y = (int)(pos_y / CUTOFF_RADIUS);
						int target_cell_z = (int)(pos_z / CUTOFF_RADIUS);
            /********************* Testing new cell mapping **********************************/
						//int target_cell_x = (int)(pos_z / CUTOFF_RADIUS);
						//int target_cell_y = (int)(pos_y / CUTOFF_RADIUS);
						//int target_cell_z = (int)(pos_x / CUTOFF_RADIUS);
            /********************* Testing new cell mapping **********************************/

            if(CELL_MAP_DEBUG && home_cell_z == 1 & home_cell_y == 2 && home_cell_x == 3){
              cout << "target => nbID=" << particle_index << "\t" << target_cell_z << "\t" << target_cell_y << "\t" << target_cell_x << endl;
            }

						// Assign particles to new cells
						int new_particle_index = tmp_particle_in_cell_counter[target_cell_z][target_cell_y][target_cell_x];
						int target_cell_id = cell_index_calculator(target_cell_x, target_cell_y, target_cell_z);

						// Assign the physical properties to temp array
						tmp_cell_particle[0][target_cell_id][new_particle_index] = pos_x;
						tmp_cell_particle[1][target_cell_id][new_particle_index] = pos_y;
						tmp_cell_particle[2][target_cell_id][new_particle_index] = pos_z;
						tmp_cell_particle[3][target_cell_id][new_particle_index] = 0;		// Forces set to 0 and will be accumulated later
						tmp_cell_particle[4][target_cell_id][new_particle_index] = 0;
						tmp_cell_particle[5][target_cell_id][new_particle_index] = 0;
						tmp_cell_particle[6][target_cell_id][new_particle_index] = v_x;
						tmp_cell_particle[7][target_cell_id][new_particle_index] = v_y;
						tmp_cell_particle[8][target_cell_id][new_particle_index] = v_z;

            if(PRINT_MU_POS && target_cell_id == 61 && sim_iter == 1){
              cout << setprecision(12);
              cout << "nbID=" << new_particle_index + 1 << "\t" << pos_x << "\t" << pos_y << "\t" << pos_z << endl; //+1 to match RTL
              //cout << target_cell_x  << "\t" << target_cell_y << "\t" << target_cell_z << endl;
            }

            if(PRINT_MU_VEL && target_cell_id == 61 && sim_iter == 1){
              cout << setprecision(12);
              cout << "nbID=" << new_particle_index + 1 << "\t" << v_x << "\t" << v_y << "\t" << v_z << endl; //+1 to match RTL
            }

						// Update the # of particles in the new cell
						tmp_particle_in_cell_counter[target_cell_z][target_cell_y][target_cell_x] += 1;

          } // go through particles in the cell
        } //motion update z loop
      } //motion update y loop
    } //motion update x loop
		if(DEBUG){
      cout << "Finished motion calculation." << endl;
    }

    //debug print
    //for(i=0; i<CELL_COUNT_Z; i++){
    //  for(j=0; j<CELL_COUNT_Y; j++){
    //    for(k=0; k<CELL_COUNT_X; k++){
    //      cout << "cell_ID:" << i*CELL_COUNT_Y*CELL_COUNT_X + j*CELL_COUNT_X + k << "\t" << tmp_particle_in_cell_counter[i][j][k] << endl;
    //    }
    //  }
    //}

    if(PRINT_FORCE_DISTRIBUTOR_OUTPUT){
      cout << "\nIteration " << sim_iter << " over\n" << endl;
    }

		/* Update the cell list from motion update tmp arrays */
		update(cell_particle, tmp_cell_particle, CELL_PARTICLE_MAX, CELL_COUNT_TOTAL, 12);
		update_int(particle_in_cell_counter, tmp_particle_in_cell_counter, CELL_COUNT_X, CELL_COUNT_Y, CELL_COUNT_Z);

	} // sim iteration

#pragma endregion

	output_file.close();
	return 0;
} //main




string get_input_path(string file_name) {
	// Not available for pdb files for now
	string path = COMMON_PATH + file_name;
	return path;
}

string get_energy_output_path() {
	string underscore = "_";
	string part_1 = "Output_Energy_FullScale_Sim_";
	string part_2 = to_string(TOTAL_PARTICLE);
	string part_3 = to_string(SIMULATION_TIMESTEP);
	string path = part_1 + DATASET_NAME + underscore + part_2 + underscore + part_3 + ".txt";
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

void map_to_cells(float** pos_data, float*** cell_particle, int*** particle_in_cell_counter) {
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
			if (DEBUG || DEBUG_MU) {
				if (counter >= DEBUG_PARTICLE_NUM) {
					continue;
				}
			}

      //if(PRINT_POS_DATA && cell_x == 3 && cell_y == 2 && cell_z == 1){
      if(PRINT_POS_DATA){
        cout << setprecision(12) << "pos " << pos_data[0][i] << "\t" << pos_data[1][i] << "\t" << pos_data[2][i] << endl;
        cout << "cell " << cell_x << "\t" << cell_y << "\t" << cell_z << "\n" << endl;
      }

			// Start from 0
			cell_id = cell_index_calculator(cell_x, cell_y, cell_z);
			cell_particle[0][cell_id][counter] = pos_data[0][i];
			cell_particle[1][cell_id][counter] = pos_data[1][i];
			cell_particle[2][cell_id][counter] = pos_data[2][i];
			particle_in_cell_counter[cell_z][cell_y][cell_x] += 1;
			total_counter += 1;
		}
		else {
			out_range_particle_counter += 1;
		}
	}
	cout << "*** Particles mapping to cells finished! ***\n" << endl;
	cout << "Total of (" << total_counter << ") particles recorded" << endl;
	cout << "Total of (" << out_range_particle_counter << ") particles falling out of the range" << endl;
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

void read_interpolation(string path, float* table) {
	int i;
	ifstream raw(path.c_str());
	if (!raw) {
		cout << "*** Error reading input file! ***" << endl;
		exit(1);
	}
	string line;
	stringstream ss;
	for (i = 0; i < INTERPOLATION_TABLE_SIZE; i++) {
		getline(raw, line);
		ss.str(line);
		ss >> table[i];
		ss.clear();
	}
}

int cell_index_calculator(int cell_x, int cell_y, int cell_z) {
	int index;
	index = cell_z * CELL_COUNT_Y * CELL_COUNT_X + cell_y * CELL_COUNT_X + cell_x;
	return index;
}

void update_int(int*** target, int*** tmp, int x, int y, int z) {
	int i, j, k;
	for (i = 0; i < z; i++) {
		for (j = 0; j < y; j++) {
			for (k = 0; k < x; k++) {
				target[i][j][k] = tmp[i][j][k];
			}
		}
	}
}

void update(float*** target, float*** tmp, int x, int y, int z) {
	int i, j, k;
	for (i = 0; i < z; i++) {
		for (j = 0; j < y; j++) {
			for (k = 0; k < x; k++) {
				target[i][j][k] = tmp[i][j][k];
			}
		}
	}
}

void floatToHex(float val){
  union FloatToChar {
    float f;
    int  c;
    //char  c[sizeof(float)];
  };

  FloatToChar x;
  x.f = val;
  cout << "0x" << std::hex << x.c << endl;
}

void floatToHex_inline(float val){
  union FloatToChar {
    float f;
    int  c;
  };

  FloatToChar x;
  x.f = val;
  cout << "0x" << std::hex << x.c;
}
