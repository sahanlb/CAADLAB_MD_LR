default : closest.cpp forward.cpp
	#g++ closest.cpp -std=c++11 -o index_seq1
	g++ forward.cpp -std=c++11 -o index_seq2

clean :
	rm -rf index_seq1 index_seq2 index_seq3 index_seq4 index_seq5  log*

cleanlog :
	rm -rf log*

run : closest.cpp
	rm -rf Output*
	rm -rf log*
	g++ closest.cpp -std=c++11 -o index_seq1
	./index_seq1 > log_closest

seq2: forward.cpp
	rm -rf index_seq2
	g++ forward.cpp -std=c++11 -o index_seq2
	./index_seq2

seq3: forward_v2.cpp
	rm -rf index_seq3
	g++ forward_v2.cpp -std=c++11 -o index_seq3
	./index_seq3

seq4: closest_v2.cpp
	rm -rf index_seq4
	g++ closest_v2.cpp -std=c++11 -o index_seq4
	./index_seq4

seq5: forward_v3.cpp
	rm -rf index_seq5
	g++ forward_v3.cpp -std=c++11 -o index_seq5
	./index_seq5
