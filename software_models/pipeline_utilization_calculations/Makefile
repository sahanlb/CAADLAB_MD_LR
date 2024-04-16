default : closest.cpp forward.cpp
	#g++ closest.cpp -std=c++11 -o index_seq1
	g++ forward.cpp -std=c++11 -o index_seq2

clean :
	rm -rf log* closest forward

cleanlog :
	rm -rf log*

closest: closest.cpp
	rm -rf closest
	g++ closest.cpp -std=c++11 -o closest
	./closest

forward: forward_v3.cpp
	rm -rf forward
	g++ forward_v3.cpp -std=c++11 -o forward
	./forward
