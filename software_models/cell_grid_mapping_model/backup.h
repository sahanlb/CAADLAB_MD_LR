#include <cmath>
#include <string>

//Debug Parameter
static const int DEBUG_PARTICLE_NUM = 5000;
static const int DEBUG = 0;
static const int DEBUG_MU = 0;
static const int DEBUG_PARTIAL_FORCE = 0;
static const int PRINT_PARTICLE_COUNT = 0;
static const int DEBUG_1_REF_ID = 0;
static const int PRINT_FORCE = 0;                                      // print partial force values to be used by comparison scripts
static const int PRINT_FULL_FORCES = 0;                                // print force values used in motion uodate
static const int PRINT_FORCE_DISTRIBUTOR_OUTPUT = 0;
static const int PRINT_SINGLE_PARTICLE = 0;
static const int PRINT_PAIRS = 0;
static const int PRINT_MU_POS = 0;
static const int PRINT_MU_VEL = 1;
static const int CELL_MAP_DEBUG = 0;
static const int PRINT_POS_DATA = 0;
//Simulation Control Parameter
static const bool ENABLE_INTERPOLATION = 1;                         	 	// Choose to use direct computation or interpolation to evaluat the force and energy
static const bool ENABLE_VERIFICATION = 0;                      	     	// Enable verification for a certain reference particle
static const bool ENABLE_SCATTER_PLOTTING = 0;                	         	// Ploting out the particle positions after each iteration ends
static const bool ENABLE_PRINT_DETAIL_MESSAGE = 0;            	         	// Print out detailed message showing which step the program is working on
static const bool ENABLE_OUTPUT_ENERGY_FILE = 0;              	         	// Print out the energy result to an output file
static const int SIMULATION_TIMESTEP = 2;                            	  // Total timesteps to simulate
static const int ENERGY_EVALUATION_STEPS = 1;                         		// Every few iterations, evaluate energy once
// Dataset Parameters
// Input & Output Scale Parameters (Determined by the LJ_no_smooth_poly_interpolation_accuracy.m)
static const int INPUT_SCALE_INDEX = 1;                        				// if the readin position data is in the unit of meter, it turns out that the minimum r2 value can be too small, lead to the overflow when calculating the r^-14, thus scale to A
static const int OUTPUT_SCALE_INDEX = 1;                       				// The scale value for the results of r14 & r8 term
// Dataset Paraemeters
static const char* DATASET_NAME = "LJArgon";
// Ar
static const float kb = 1.380E-23;                               			// Boltzmann constant (J/K)
static const float Nav = 6.022E23;                               			// Avogadro constant, # of atoms per mol
static const float Ar_weight = 39.90;                            			// g/mol value of Argon atom
static const float EPS = 1.995996 * 1.995996;                    			// Extracted from OpenMM, unit kJ      //0.996;// Unit: kJ	//0.238;// Unit kcal/mol	//kb * 120;// Unit J
static const float SIGMA = 2.1;//3.4;//0.8;//0.1675*2;                   	// Extracted from LJArgon, unit Angstrom        //3.35;//3.4;// Unit Angstrom    //3.4e-10;// Unit meter, the unit should be in consistant with position value
static const float MASS = Ar_weight / Nav / 1000.0;                			// Unit kg
static const float MASS_Nav = 0.03995;
//static const float SIMULATION_TIME_STEP = 2E-15;                 			// 2 femtosecond
static const float CUTOFF_RADIUS = 8.5;//single(SIGMA*2.5);      			// Unit Angstrom, Cutoff Radius
static const float CUTOFF_RADIUS_2 = CUTOFF_RADIUS*CUTOFF_RADIUS;           // Cutoff distance square
static const float EXCLUSION = 0.5;                     					// Unit Angstrom, If the particle pairs has closers distance than this value, then don't evaluate
static const float EXCLUSION_2 = EXCLUSION*EXCLUSION;                  		// Exclusion distance square
																			// LJArgon min r2 is 2.242475 ang^2
																			// Here we choose a interpolation range that is consistant with ApoA1
static const float RAW_R2_MIN = pow(2, -12);//2.242475;                 	// Currently this value is not used
static const float SCALED_R2_MIN = RAW_R2_MIN*INPUT_SCALE_INDEX*INPUT_SCALE_INDEX;
static const int MIN_LOG_INDEX = (int)log2(EXCLUSION_2);
static const float MIN_RANGE = pow(2, MIN_LOG_INDEX);                  		// minimal range for the evaluation
static const int MAX_LOG_INDEX = (int)log2(CUTOFF_RADIUS_2) + 1;
static const float MAX_RANGE = pow(2, MAX_LOG_INDEX);                  		// maximum range for the evaluation (currently this is the cutoff radius)
// Interpolation Parameters
static const int INTERPOLATION_ORDER = 1;
static const int INTERPOLATION_TABLE_SIZE = 2304;
static const int SEGMENT_NUM = MAX_LOG_INDEX-MIN_LOG_INDEX;    				// # of segment
static const int BIN_NUM = 256;                                				// # of bins per segment
// Benmarck Related Parameters (related with CUTOFF_RADIUS)
static const int CELL_COUNT_X = 4;//5;//3;
static const int CELL_COUNT_Y = 4;//5;//3;
static const int CELL_COUNT_Z = 4;//5;//3;
static const int CELL_COUNT_TOTAL = CELL_COUNT_X * CELL_COUNT_Y * CELL_COUNT_Z;
static const float BOUNDING_BOX_SIZE_X = CELL_COUNT_X * CUTOFF_RADIUS;
static const float BOUNDING_BOX_SIZE_Y = CELL_COUNT_Y * CUTOFF_RADIUS;
static const float BOUNDING_BOX_SIZE_Z = CELL_COUNT_Z * CUTOFF_RADIUS;
static const int CELL_PARTICLE_MAX = 200;                            		// The maximum possible particle count in each cell
static const int TOTAL_PARTICLE = 20000;//10000;//864;//500;//19000;                   // particle count in benchmark
static const int MEM_DATA_WIDTH = 32*3;                              		// Memory Data Width (3*32 for position)
static const std::string COMMON_PATH = "./";
static const std::string INPUT_FILE_FORMAT = "txt";//"pdb";                   	// The input file format, can be "txt" or "pdb"
static const std::string INPUT_FILE_NAME = "input_positions_ljargon_20000_box_58_49_49.txt";//"input_positions_ljargon_10000_40box.txt";//"ar_gas.pdb";//"input_positions_ljargon.txt";
// HDL design parameters
static const int NUM_FILTER = 7;                                     		// Number of filters in the pipeline
static const int FILTER_BUFFER_DEPTH = 32;                           		// Filter buffer depth, if buffer element # is larger than this value, pause generating particle pairs into filter bank

std::string get_input_path(std::string file_name);
std::string get_energy_output_path();
void read_initial_input(std::string path, float** data_pos);
void shift_to_first_quadrant(float** raw_data, float** shifted_data);
void map_to_cells(float** pos_data, float*** cell_particle, int*** particle_in_cell_counter);
void set_to_zeros_3d(float*** matrix, int x, int y, int z);
void print_int_3d(int*** matrix, int x, int y, int z);
void set_to_zeros_3d_int(int*** matrix, int x, int y, int z);
void read_interpolation(std::string path, float* table);
int cell_index_calculator(int cell_x, int cell_y, int cell_z);
void update_int(int*** target, int*** tmp, int x, int y, int z);
void update(float*** target, float*** tmp, int x, int y, int z);
void floatToHex(float val);
void floatToHex_inline(float val);









