#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <math.h>
using namespace std;

#define LATENCY 12 // Required latency in cycles between picking from two
                  // cells which have particles which can potentially
                  // have overlapping charge sub-grids.
#define CELL_COUNT_X  8
#define CELL_COUNT_Y  4
#define CELL_COUNT_Z  4
#define TOTAL_CELLS   (CELL_COUNT_X*CELL_COUNT_Y*CELL_COUNT_Z)

// Helper function definitions
int cell_index_calculator(int cell_x, int cell_y, int cell_z);
int find_next_cell(int *cell_array, int x, int y, int z, int *order, int current_pick, int *picking_order);
void print_matrix(int *array, int XDIM, int YDIM, int ZDIM);
int calc_X_index(int cell_id);
int calc_Y_index(int cell_id);
int calc_Z_index(int cell_id);


int main(){

  int cell_array[TOTAL_CELLS]; //
  int order[TOTAL_CELLS];
  int picking_order[TOTAL_CELLS];
  int start_x, start_y, start_z;

  // Cell array values
  // 0: Can be accessed next
  //    - 0 gets set to -1 at the beginning od the find_next_cell function.
  // N: Can be accessed after N cycles
  //
  // Order
  // -1: Not accessed yet.
  // N : Accessed as the Nth step of the sequence

  for(int i=0; i<TOTAL_CELLS; i++){
    cell_array[i]    = 0;
    order[i]         = -1;
    picking_order[i] = -1;
  }
  start_x = 0;
  start_y = 0;
  start_z = 0;

  order[0]         = 0;
  picking_order[0] = 0;

  cell_array[0] = LATENCY;

  int result = find_next_cell(cell_array, start_x, start_y, start_z, order, 1, picking_order);

  if(result == 1)
    cout << "Could not find a feasible sequence." << endl;

  return 0;
}



// Helper functions
//
int cell_index_calculator(int cell_x, int cell_y, int cell_z) {
	int index;
	index = cell_z * CELL_COUNT_Y * CELL_COUNT_X + cell_y * CELL_COUNT_X + cell_x;
	return index;
}

int find_next_cell(int *cell_array, int x, int y, int z, int *order, int current_pick, int* picking_order){
  //cout << "Enter find_next_cell. current pick: " << current_pick << endl;
  // cell_array: cell array last updated by the caller function.
  // x         : x coordinate of the current cell (picked by caller function)
  // y         : y coordinate of the current cell (picked by caller function)
  // z         : z coordinate of the current cell (picked by caller function)
  // order: Order of picks so far. (last update by the caller). Caller updated (current_pick-1)th pick

  int *new_array = (int*) malloc(sizeof(int)*TOTAL_CELLS);
  int *new_order = (int*) malloc(sizeof(int)*TOTAL_CELLS);
  int *new_picking_order = (int*) malloc(sizeof(int)*TOTAL_CELLS);


  for(int i=0; i<TOTAL_CELLS; i++){
    // Deduct 1 while copying. Comparisons should be done with cell value + 1 due to this.
    if(cell_array[i] == -1)
      new_array[i] = cell_array[i];
    else
      new_array[i] = cell_array[i] - 1;
  }

  for(int i=0; i<TOTAL_CELLS; i++){
    new_order[i] = order[i];
  }

  for(int i=0; i<TOTAL_CELLS; i++){
    new_picking_order[i] = picking_order[i];
  }

  int curr_cell = cell_index_calculator(x, y, z);

  // Find next cell. Go forward along the cell array until a valid cell is found
  for(int i=1; i<TOTAL_CELLS; i++){
    int target = (curr_cell + i) % TOTAL_CELLS;

    if(new_order[target] != -1){
      continue;
    }
    else{ // Not already visited
      // Find coordinates of the target cell
      int next_x = calc_X_index(target);
      int next_y = calc_Y_index(target);
      int next_z = calc_Z_index(target);

      //cout << "Target: " << target << "\tTarget coordinates:" << next_z << ", " << next_y << ", " << next_x << endl;


      //Is the neighborhood clear?
      int subgrid_values[27];

      for(int zt=-1; zt<2; zt++){ // Traverse subgrid
        for(int yt=-1; yt<2; yt++){
          for(int xt=-1; xt<2; xt++){
            int nb_x = next_x + xt;
            int nb_y = next_y + yt;
            int nb_z = next_z + zt;
            // Apply periodic boundary conditions
            if(nb_x == -1)
              nb_x = CELL_COUNT_X - 1;
            else if(nb_x == CELL_COUNT_X)
              nb_x = 0;
            else
              nb_x = nb_x;

            if(nb_y == -1)
              nb_y = CELL_COUNT_Y - 1;
            else if(nb_y == CELL_COUNT_Y)
              nb_y = 0;
            else
              nb_y = nb_y;

            if(nb_z == -1)
              nb_z = CELL_COUNT_Z - 1;
            else if(nb_z == CELL_COUNT_Z)
              nb_z = 0;
            else
              nb_z = nb_z;
            
            // List index
            int list_inedx = 9*zt + 3*yt + xt + 13;

            int nb_index = cell_index_calculator(nb_x, nb_y, nb_z);

            subgrid_values[list_inedx] = new_array[nb_index] + 1; 
          } 
        } 
      } // Traverse subgrid 
      
      // Check if the subgrid is clear
      int accum = 0;
      for(int i=0; i<27; i++){
        if(subgrid_values[i] != -1)
          accum += subgrid_values[i];
        else
        accum = accum;
      }

      if(accum == 0){ // Pick this sell
        // Update new order
        new_order[target] = current_pick;
        new_picking_order[current_pick] = target;

        if(current_pick == TOTAL_CELLS-1){
          cout << "Sequence generation successful!" << endl;
          for(int i=0; i<TOTAL_CELLS-1; i++)
            cout << new_order[i] << ", ";
          cout << new_order[TOTAL_CELLS-1] << endl;

          cout << "\nPicking order" << endl;
          for(int i=0; i<TOTAL_CELLS-1; i++)
            cout << new_picking_order[i] << ", ";
          cout << new_picking_order[TOTAL_CELLS-1] << endl;

          return 0;
        }

        // Update new array
        new_array[target] = LATENCY;

        // Recursively call the function
        int result = find_next_cell(new_array, next_x, next_y, next_z, new_order, (current_pick+1), new_picking_order);
        if (result == 1)
          return 1;
        else
          return 0;
         
      }
      else{ // Can't pick this. Move on to the next target cell
        continue;
      }

    } // Not already visited

  }

  // Done looping theough cell array. No valid target found.
  return 1;
}


void print_matrix(int *array, int XDIM, int YDIM, int ZDIM){
  for(int z=0; z<ZDIM; z++){
    for(int y=0; y<YDIM; y++){
      for(int x=0; x<XDIM; x++){
        int index = z*YDIM*XDIM + y*XDIM + x;
        cout << " " << array[index];
      }
      cout << endl;
    }
    cout << "\n" << endl;
  }
}


int calc_X_index(int cell_id){
  int z_slice_points = cell_id % (CELL_COUNT_X*CELL_COUNT_Y);
  int y_line_points  = z_slice_points % CELL_COUNT_X;
  return y_line_points;
}


int calc_Y_index(int cell_id){
  int z_slice_points = cell_id % (CELL_COUNT_X*CELL_COUNT_Y);
  int y_line = z_slice_points / CELL_COUNT_X;
  return y_line;
}


int calc_Z_index(int cell_id){
  int z_index = cell_id / (CELL_COUNT_X*CELL_COUNT_Y);
return z_index;
}
