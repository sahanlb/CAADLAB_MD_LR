default : main.cpp main.h
	g++ main.cpp -std=c++11 -o MD_golden

clean :
	rm -rf MD_golden output* log*

cleanout :
	rm -rf Output*

cleanlog :
	rm -rf log*

run : main.cpp main.h
	rm -rf Output*
	rm -rf log*
	g++ main.cpp -std=c++11 -o MD_golden
	./MD_golden > log
