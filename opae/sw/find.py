num_list = []
with open('force_log2','r')as fh:
  for line in fh.readlines():
    num_list.append(abs(float(line)))

print "Max number is -" ,max(num_list)
print "Line number is - ", (num_list.index(max(num_list)))+1

sortedlist = sorted(num_list);
print sortedlist

temp_index = 0
temp = sortedlist[temp_index]
while temp < 1.0:
  temp_index = temp_index + 1
  temp = sortedlist[temp_index]

print "Number of points with diff < 1%" , temp_index
print "Number of points with diff > 1%" , len(sortedlist) - temp_index

