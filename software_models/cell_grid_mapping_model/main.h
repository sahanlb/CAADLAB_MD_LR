#include <cmath>
#include <string>

// DEbug parameters
static const int DEBUG = 0;
static const int PRINT_POS_DATA = 0;


static const int TOTAL_PARTICLE = 20000;      // particle count in benchmark
static const std::string INPUT_FILE_NAME = "input_positions.txt";
static const bool ENABLE_OUTPUT_FILE = 0;     // Print out the energy result to an output file
static const int PRINT_PARTICLE_COUNT = 0;
static const int SIMULATION_TIMESTEP = 2;                            	  // Total timesteps to simulate

static const float CUTOFF_RADIUS = 8.5;//single(SIGMA*2.5);      			// Unit Angstrom, Cutoff Radius
//static const float GRID_DIST = CUTOFF_RADIUS/6;
static const int SUB_GRID_POINTS = 4; //sub grid points on one dimension



static const std::string COMMON_PATH = "./";


// Dataset Paraemeters
static const char* DATASET_NAME = "LJArgon";
static const int CELL_PARTICLE_MAX = 200;        // The maximum possible particle count in each cell



std::string get_input_path(std::string file_name);
std::string get_output_path();
void read_initial_input(std::string path, float** data_pos);
void shift_to_first_quadrant(float** raw_data, float** shifted_data);
void map_to_cells(float** pos_data, float*** cell_particle, int*** particle_in_cell_counter, int CELL_COUNT_X, int CELL_COUNT_Y, int CELL_COUNT_Z);
void set_to_zeros_3d(float*** matrix, int x, int y, int z);
void print_int_3d(int*** matrix, int x, int y, int z);
void set_to_zeros_3d_int(int*** matrix, int x, int y, int z);
//void read_interpolation(std::string path, float* table);
int cell_index_calculator(int cell_x, int cell_y, int cell_z, int CELL_COUNT_X, int CELL_COUNT_Y, int CELL_COUNT_Z);
//void update_int(int*** target, int*** tmp, int x, int y, int z);
//void update(float*** target, float*** tmp, int x, int y, int z);
//void floatToHex(float val);
//void floatToHex_inline(float val);
