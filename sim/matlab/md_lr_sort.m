%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Configuration Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Size of the Grid in grid points
numgpx = 32;
numgpy = 32;
numgpz = 32;

% Number of cells in each dimension
numcellx = 6;
numcelly = 6;
numcellz = 6;

% Ratio between number of grid points and number of cells is >5 for each dimension.
% This is within the values used in OpenMM simulations by STX.

% Number of particles
%nump = 4096;
nump = numgpx*numgpy*numgpz;

% Number of nearest neighbors in one dimension
nnn1d = 4;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Derived Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Grid coordinate address widths
xaddrw = ceil(log2(numgpx));
yaddrw = ceil(log2(numgpy));
zaddrw = ceil(log2(numgpz));

% Particle Memory data width
pmemw = xaddrw + yaddrw + zaddrw + 3*27 + 32;

% Cell length in terms of grid distances
cellgridratiox = (numgpx-1)/numcellx; % -1 because we need the number of spaces between grid points
cellgridratioy = (numgpy-1)/numcelly;
cellgridratioz = (numgpz-1)/numcellz;

% Total cells
totalcells = numcellx * numcelly * numcellz;

% Maximum number of particles per cell (to ensure an even distribution)
maxppc = ceil(nump/totalcells);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Constants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Particle-to-Grid Polynomial Matrix
p2gmat = double(zeros([4, 4]));

% Use Cardinal B-Splines from OpenMM
p2gmat(1,:) =  1/6*[ -1.0,   3.0,  -3.0,   1.0];
p2gmat(2,:) =  1/6*[  3.0,  -6.0,   0.0,   4.0];
p2gmat(3,:) =  1/6*[ -3.0,   3.0,   3.0,   1.0];
p2gmat(4,:) =  1/6*[  1.0,   0.0,   0.0,   0.0];

% Grid-to-Particle Polynomial Matrix
g2pmat = double(zeros([4, 4]));

% Use Cardinal B-Splines from OpenMM
g2pmat(1,:) =  1/6*[  0.0,  -3.0,   6.0, -3.0];
g2pmat(2,:) =  1/6*[  0.0,   9.0, -12.0,  0.0];
g2pmat(3,:) =  1/6*[  0.0,  -9.0,   6.0,  3.0];
g2pmat(4,:) =  1/6*[  0.0,   3.0,   0.0,  0.0];

% Index sequence to pick particles from cells
% 3x3x3 Grid
%iseq = [0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 12, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 13, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 14, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 16, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 17, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 18, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 19, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 20, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 21, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 22, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 23, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 24, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 25, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 26, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];
% 4x4x4 Grid
%iseq = [0, 2, 8, 10, 32, 34, 40, 42, -1, -1, -1, -1, -1, 1, 3, 9, 11, 33, 35, 41, 43, -1, -1, -1, -1, -1, -1, 5, 7, 12, 14, 37, 39, 44, 46, -1, -1, -1, -1, -1, 4, 6, 13, 15, 36, 38, 45, 47, -1, -1, -1, -1, -1, -1, -1, -1, 52, 54, 61, 63, 16, 18, 24, 26, -1, -1, -1, -1, -1, 53, 55, 60, 62, 17, 19, 25, 27, -1, -1, -1, -1, -1, -1, 48, 50, 56, 58, 21, 23, 28, 30, -1, -1, -1, -1, -1, 49, 51, 57, 59, 20, 22, 29, 31, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];
% 5x5x5 Grid
%iseq = [0, 2, 10, 12, 50, 52, 60, 62, -1, -1, -1, -1, 100, 102, 110, 112, 25, 27, 35, 37, -1, -1, -1, -1, 75, 77, 85, 87, 4, 21, 39, 6, -1, -1, -1, -1, 54, 71, 89, 56, 103, 116, 13, 101, -1, -1, -1, -1, 28, 40, 63, 26, 78, 86, 113, 120, -1, -1, -1, -1, 3, 11, 38, 45, 53, 55, 88, 90, -1, -1, -1, -1, 104, 106, 122, 14, 32, 41, 48, 59, 94, -1, -1, -1, -1, 107, 117, 5, 51, 61, 15, 33, 43, 79, -1, -1, -1, -1, 93, 1, 76, 91, 16, 29, 44, 83, -1, -1, -1, -1, 98, 7, 80, 95, 17, 30, 49, 57, -1, -1, -1, -1, 67, 108, 105, 115, 118, 34, 65, 31, -1, -1, -1, -1, 42, 82, 84, 121, 123, 8, 69, -1, -1, -1, -1, -1, 72, 81, 36, 58, 119, 9, 22, 70, -1, -1, -1, -1, 73, 111, -1, 64, 124, 109, -1, 46, 96, -1, -1, -1, 74, -1, -1, -1, 18, -1, -1, 20, 66, -1, -1, -1, 68, -1, -1, -1, 114, 23, -1, -1, -1, -1, -1, -1, 92, 99, -1, -1, -1, 19, 47, -1, -1, -1, -1, -1, 97, -1, -1, -1, -1, 24, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];

% 6x6x6 grid
iseq = [0, 2, 4, 12, 14, 16, 24, 26, 28, 72, 74, 76, 84, 86, 88, 96, 98, 100, 144, 146, 148, 156, 158, 160, 168, 170, 172, 1, 3, 5, 13, 15, 17, 25, 27, 29, 73, 75, 77, 85, 87, 89, 97, 99, 101, 145, 147, 149, 157, 159, 161, 169, 171, 173, 6, 8, 10, 18, 20, 22, 30, 32, 34, 78, 80, 82, 90, 92, 94, 102, 104, 106, 150, 152, 154, 162, 164, 166, 174, 176, 178, 7, 9, 11, 19, 21, 23, 31, 33, 35, 79, 81, 83, 91, 93, 95, 103, 105, 107, 151, 153, 155, 163, 165, 167, 175, 177, 179, 37, 39, 41, 48, 50, 52, 60, 62, 64, 109, 111, 113, 120, 122, 124, 132, 134, 136, 180, 182, 184, 192, 194, 196, 204, 206, 208, 36, 38, 40, 49, 51, 53, 61, 63, 65, 108, 110, 112, 121, 123, 125, 133, 135, 137, 181, 183, 185, 193, 195, 197, 205, 207, 209, 42, 44, 46, 54, 56, 58, 66, 68, 70, 114, 116, 118, 126, 128, 130, 138, 140, 142, 186, 188, 190, 198, 200, 202, 210, 212, 214, 43, 45, 47, 55, 57, 59, 67, 69, 71, 115, 117, 119, 127, 129, 131, 139, 141, 143, 187, 189, 191, 199, 201, 203, 211, 213, 215, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];

% 12x12x12
%iseq = [0, 2, 4, 6, 8, 10, 24, 26, 28, 30, 32, 34, 48, 50, 52, 54, 56, 58, 72, 74, 76, 78, 80, 82, 96, 98, 100, 102, 104, 106, 120, 122, 124, 126, 128, 130, 144, 146, 148, 150, 152, 154, 168, 170, 172, 174, 176, 178, 192, 194, 196, 198, 200, 202, 216, 218, 220, 222, 224, 226, 240, 242, 244, 246, 248, 250, 264, 266, 268, 270, 272, 274, 288, 290, 292, 294, 296, 298, 312, 314, 316, 318, 320, 322, 336, 338, 340, 342, 344, 346, 360, 362, 364, 366, 368, 370, 384, 386, 388, 390, 392, 394, 408, 410, 412, 414, 416, 418, 432, 434, 436, 438, 440, 442, 456, 458, 460, 462, 464, 466, 480, 482, 484, 486, 488, 490, 504, 506, 508, 510, 512, 514, 528, 530, 532, 534, 536, 538, 552, 554, 556, 558, 560, 562, 576, 578, 580, 582, 584, 586, 600, 602, 604, 606, 608, 610, 624, 626, 628, 630, 632, 634, 648, 650, 652, 654, 656, 658, 672, 674, 676, 678, 680, 682, 696, 698, 700, 702, 704, 706, 720, 722, 724, 726, 728, 730, 744, 746, 748, 750, 752, 754, 768, 770, 772, 774, 776, 778, 792, 794, 796, 798, 800, 802, 816, 818, 820, 822, 824, 826, 840, 842, 844, 846, 848, 850, 864, 866, 868, 870, 872, 874, 888, 890, 892, 894, 896, 898, 912, 914, 916, 918, 920, 922, 936, 938, 940, 942, 944, 946, 960, 962, 964, 966, 968, 970, 984, 986, 988, 990, 992, 994, 1008, 1010, 1012, 1014, 1016, 1018, 1032, 1034, 1036, 1038, 1040, 1042, 1056, 1058, 1060, 1062, 1064, 1066, 1080, 1082, 1084, 1086, 1088, 1090, 1104, 1106, 1108, 1110, 1112, 1114, 1128, 1130, 1132, 1134, 1136, 1138, 1152, 1154, 1156, 1158, 1160, 1162, 1176, 1178, 1180, 1182, 1184, 1186, 1200, 1202, 1204, 1206, 1208, 1210, 1224, 1226, 1228, 1230, 1232, 1234, 1248, 1250, 1252, 1254, 1256, 1258, 1272, 1274, 1276, 1278, 1280, 1282, 1296, 1298, 1300, 1302, 1304, 1306, 1320, 1322, 1324, 1326, 1328, 1330, 1344, 1346, 1348, 1350, 1352, 1354, 1368, 1370, 1372, 1374, 1376, 1378, 1392, 1394, 1396, 1398, 1400, 1402, 1416, 1418, 1420, 1422, 1424, 1426, 1440, 1442, 1444, 1446, 1448, 1450, 1464, 1466, 1468, 1470, 1472, 1474, 1488, 1490, 1492, 1494, 1496, 1498, 1512, 1514, 1516, 1518, 1520, 1522, 1536, 1538, 1540, 1542, 1544, 1546, 1560, 1562, 1564, 1566, 1568, 1570, 1584, 1586, 1588, 1590, 1592, 1594, 1608, 1610, 1612, 1614, 1616, 1618, 1632, 1634, 1636, 1638, 1640, 1642, 1656, 1658, 1660, 1662, 1664, 1666, 1680, 1682, 1684, 1686, 1688, 1690, 1704, 1706, 1708, 1710, 1712, 1714, 1, 3, 5, 7, 9, 11, 25, 27, 29, 31, 33, 35, 49, 51, 53, 55, 57, 59, 73, 75, 77, 79, 81, 83, 97, 99, 101, 103, 105, 107, 121, 123, 125, 127, 129, 131, 145, 147, 149, 151, 153, 155, 169, 171, 173, 175, 177, 179, 193, 195, 197, 199, 201, 203, 217, 219, 221, 223, 225, 227, 241, 243, 245, 247, 249, 251, 265, 267, 269, 271, 273, 275, 289, 291, 293, 295, 297, 299, 313, 315, 317, 319, 321, 323, 337, 339, 341, 343, 345, 347, 361, 363, 365, 367, 369, 371, 385, 387, 389, 391, 393, 395, 409, 411, 413, 415, 417, 419, 433, 435, 437, 439, 441, 443, 457, 459, 461, 463, 465, 467, 481, 483, 485, 487, 489, 491, 505, 507, 509, 511, 513, 515, 529, 531, 533, 535, 537, 539, 553, 555, 557, 559, 561, 563, 577, 579, 581, 583, 585, 587, 601, 603, 605, 607, 609, 611, 625, 627, 629, 631, 633, 635, 649, 651, 653, 655, 657, 659, 673, 675, 677, 679, 681, 683, 697, 699, 701, 703, 705, 707, 721, 723, 725, 727, 729, 731, 745, 747, 749, 751, 753, 755, 769, 771, 773, 775, 777, 779, 793, 795, 797, 799, 801, 803, 817, 819, 821, 823, 825, 827, 841, 843, 845, 847, 849, 851, 865, 867, 869, 871, 873, 875, 889, 891, 893, 895, 897, 899, 913, 915, 917, 919, 921, 923, 937, 939, 941, 943, 945, 947, 961, 963, 965, 967, 969, 971, 985, 987, 989, 991, 993, 995, 1009, 1011, 1013, 1015, 1017, 1019, 1033, 1035, 1037, 1039, 1041, 1043, 1057, 1059, 1061, 1063, 1065, 1067, 1081, 1083, 1085, 1087, 1089, 1091, 1105, 1107, 1109, 1111, 1113, 1115, 1129, 1131, 1133, 1135, 1137, 1139, 1153, 1155, 1157, 1159, 1161, 1163, 1177, 1179, 1181, 1183, 1185, 1187, 1201, 1203, 1205, 1207, 1209, 1211, 1225, 1227, 1229, 1231, 1233, 1235, 1249, 1251, 1253, 1255, 1257, 1259, 1273, 1275, 1277, 1279, 1281, 1283, 1297, 1299, 1301, 1303, 1305, 1307, 1321, 1323, 1325, 1327, 1329, 1331, 1345, 1347, 1349, 1351, 1353, 1355, 1369, 1371, 1373, 1375, 1377, 1379, 1393, 1395, 1397, 1399, 1401, 1403, 1417, 1419, 1421, 1423, 1425, 1427, 1441, 1443, 1445, 1447, 1449, 1451, 1465, 1467, 1469, 1471, 1473, 1475, 1489, 1491, 1493, 1495, 1497, 1499, 1513, 1515, 1517, 1519, 1521, 1523, 1537, 1539, 1541, 1543, 1545, 1547, 1561, 1563, 1565, 1567, 1569, 1571, 1585, 1587, 1589, 1591, 1593, 1595, 1609, 1611, 1613, 1615, 1617, 1619, 1633, 1635, 1637, 1639, 1641, 1643, 1657, 1659, 1661, 1663, 1665, 1667, 1681, 1683, 1685, 1687, 1689, 1691, 1705, 1707, 1709, 1711, 1713, 1715, 12, 14, 16, 18, 20, 22, 36, 38, 40, 42, 44, 46, 60, 62, 64, 66, 68, 70, 84, 86, 88, 90, 92, 94, 108, 110, 112, 114, 116, 118, 132, 134, 136, 138, 140, 142, 156, 158, 160, 162, 164, 166, 180, 182, 184, 186, 188, 190, 204, 206, 208, 210, 212, 214, 228, 230, 232, 234, 236, 238, 252, 254, 256, 258, 260, 262, 276, 278, 280, 282, 284, 286, 300, 302, 304, 306, 308, 310, 324, 326, 328, 330, 332, 334, 348, 350, 352, 354, 356, 358, 372, 374, 376, 378, 380, 382, 396, 398, 400, 402, 404, 406, 420, 422, 424, 426, 428, 430, 444, 446, 448, 450, 452, 454, 468, 470, 472, 474, 476, 478, 492, 494, 496, 498, 500, 502, 516, 518, 520, 522, 524, 526, 540, 542, 544, 546, 548, 550, 564, 566, 568, 570, 572, 574, 588, 590, 592, 594, 596, 598, 612, 614, 616, 618, 620, 622, 636, 638, 640, 642, 644, 646, 660, 662, 664, 666, 668, 670, 684, 686, 688, 690, 692, 694, 708, 710, 712, 714, 716, 718, 732, 734, 736, 738, 740, 742, 756, 758, 760, 762, 764, 766, 780, 782, 784, 786, 788, 790, 804, 806, 808, 810, 812, 814, 828, 830, 832, 834, 836, 838, 852, 854, 856, 858, 860, 862, 876, 878, 880, 882, 884, 886, 900, 902, 904, 906, 908, 910, 924, 926, 928, 930, 932, 934, 948, 950, 952, 954, 956, 958, 972, 974, 976, 978, 980, 982, 996, 998, 1000, 1002, 1004, 1006, 1020, 1022, 1024, 1026, 1028, 1030, 1044, 1046, 1048, 1050, 1052, 1054, 1068, 1070, 1072, 1074, 1076, 1078, 1092, 1094, 1096, 1098, 1100, 1102, 1116, 1118, 1120, 1122, 1124, 1126, 1140, 1142, 1144, 1146, 1148, 1150, 1164, 1166, 1168, 1170, 1172, 1174, 1188, 1190, 1192, 1194, 1196, 1198, 1212, 1214, 1216, 1218, 1220, 1222, 1236, 1238, 1240, 1242, 1244, 1246, 1260, 1262, 1264, 1266, 1268, 1270, 1284, 1286, 1288, 1290, 1292, 1294, 1308, 1310, 1312, 1314, 1316, 1318, 1332, 1334, 1336, 1338, 1340, 1342, 1356, 1358, 1360, 1362, 1364, 1366, 1380, 1382, 1384, 1386, 1388, 1390, 1404, 1406, 1408, 1410, 1412, 1414, 1428, 1430, 1432, 1434, 1436, 1438, 1452, 1454, 1456, 1458, 1460, 1462, 1476, 1478, 1480, 1482, 1484, 1486, 1500, 1502, 1504, 1506, 1508, 1510, 1524, 1526, 1528, 1530, 1532, 1534, 1548, 1550, 1552, 1554, 1556, 1558, 1572, 1574, 1576, 1578, 1580, 1582, 1596, 1598, 1600, 1602, 1604, 1606, 1620, 1622, 1624, 1626, 1628, 1630, 1644, 1646, 1648, 1650, 1652, 1654, 1668, 1670, 1672, 1674, 1676, 1678, 1692, 1694, 1696, 1698, 1700, 1702, 1716, 1718, 1720, 1722, 1724, 1726, 13, 15, 17, 19, 21, 23, 37, 39, 41, 43, 45, 47, 61, 63, 65, 67, 69, 71, 85, 87, 89, 91, 93, 95, 109, 111, 113, 115, 117, 119, 133, 135, 137, 139, 141, 143, 157, 159, 161, 163, 165, 167, 181, 183, 185, 187, 189, 191, 205, 207, 209, 211, 213, 215, 229, 231, 233, 235, 237, 239, 253, 255, 257, 259, 261, 263, 277, 279, 281, 283, 285, 287, 301, 303, 305, 307, 309, 311, 325, 327, 329, 331, 333, 335, 349, 351, 353, 355, 357, 359, 373, 375, 377, 379, 381, 383, 397, 399, 401, 403, 405, 407, 421, 423, 425, 427, 429, 431, 445, 447, 449, 451, 453, 455, 469, 471, 473, 475, 477, 479, 493, 495, 497, 499, 501, 503, 517, 519, 521, 523, 525, 527, 541, 543, 545, 547, 549, 551, 565, 567, 569, 571, 573, 575, 589, 591, 593, 595, 597, 599, 613, 615, 617, 619, 621, 623, 637, 639, 641, 643, 645, 647, 661, 663, 665, 667, 669, 671, 685, 687, 689, 691, 693, 695, 709, 711, 713, 715, 717, 719, 733, 735, 737, 739, 741, 743, 757, 759, 761, 763, 765, 767, 781, 783, 785, 787, 789, 791, 805, 807, 809, 811, 813, 815, 829, 831, 833, 835, 837, 839, 853, 855, 857, 859, 861, 863, 877, 879, 881, 883, 885, 887, 901, 903, 905, 907, 909, 911, 925, 927, 929, 931, 933, 935, 949, 951, 953, 955, 957, 959, 973, 975, 977, 979, 981, 983, 997, 999, 1001, 1003, 1005, 1007, 1021, 1023, 1025, 1027, 1029, 1031, 1045, 1047, 1049, 1051, 1053, 1055, 1069, 1071, 1073, 1075, 1077, 1079, 1093, 1095, 1097, 1099, 1101, 1103, 1117, 1119, 1121, 1123, 1125, 1127, 1141, 1143, 1145, 1147, 1149, 1151, 1165, 1167, 1169, 1171, 1173, 1175, 1189, 1191, 1193, 1195, 1197, 1199, 1213, 1215, 1217, 1219, 1221, 1223, 1237, 1239, 1241, 1243, 1245, 1247, 1261, 1263, 1265, 1267, 1269, 1271, 1285, 1287, 1289, 1291, 1293, 1295, 1309, 1311, 1313, 1315, 1317, 1319, 1333, 1335, 1337, 1339, 1341, 1343, 1357, 1359, 1361, 1363, 1365, 1367, 1381, 1383, 1385, 1387, 1389, 1391, 1405, 1407, 1409, 1411, 1413, 1415, 1429, 1431, 1433, 1435, 1437, 1439, 1453, 1455, 1457, 1459, 1461, 1463, 1477, 1479, 1481, 1483, 1485, 1487, 1501, 1503, 1505, 1507, 1509, 1511, 1525, 1527, 1529, 1531, 1533, 1535, 1549, 1551, 1553, 1555, 1557, 1559, 1573, 1575, 1577, 1579, 1581, 1583, 1597, 1599, 1601, 1603, 1605, 1607, 1621, 1623, 1625, 1627, 1629, 1631, 1645, 1647, 1649, 1651, 1653, 1655, 1669, 1671, 1673, 1675, 1677, 1679, 1693, 1695, 1697, 1699, 1701, 1703, 1717, 1719, 1721, 1723, 1725, 1727, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1];

seqlen = length(iseq);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Greens ROM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize empty array of doubles to keep as much precision as possible
grom = double(zeros([numgpx, numgpy, numgpz]));

% Get Greens ROM values from separate script partially generated by OpenMM
% run greens_rom.m
run greens_rom_32x32x32.m

% Caste as single to match hardware storage precision
grom = single(grom);

% Create Verilog header file for clustered grid ROM
file0 = fopen('./clustered_greens_rom.svh', 'w');

fprintf(file0, 'localparam [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][BMEMD-1:0][31:0] ROMVAL = {\n');

for ii = nnn1d:-1:1
  for jj = nnn1d:-1:1
    for kk = nnn1d:-1:1
      for ll = numgpz/nnn1d:-1:1
        for mm = numgpy/nnn1d:-1:1
          for nn = numgpx/nnn1d:-1:1
            indxx = (nn-1)*nnn1d+kk;
            indxy = (mm-1)*nnn1d+jj;
            indxz = (ll-1)*nnn1d+ii;

            rtmp = num2hex(real(grom(indxx,indxy,indxz)));

            fprintf(file0, '  32''h%s /* (%0d, %0d, %0d) */', rtmp, indxx-1, indxy-1, indxz-1);

            if (indxx==1) && (indxy==1) && (indxz==1)
              fprintf(file0, '};\n');
            else
              fprintf(file0, ',\n');
            end
          end
        end
      end
    end
  end
end

fclose(file0);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generate Particle Information
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
file0 = fopen('./particle_info_old.svh', 'w'); % Particle info for the old design
file1 = fopen('./particle_info_new.svh', 'w'); % Particle info for the new design
filehr = fopen('./particle_info.txt', 'w'); % Particle info in readable from

% Get Greens ROM values from separate script partially generated by OpenMM
run posq_charge.m

% Data structure for cell lists
cell_list = zeros(totalcells,maxppc,3);
% Particle count
pcount = zeros(1,totalcells);

% Initialize random number generator
rng(0);

% Generate random particle positions
mappedparticles = 0;
total_lines     = 0;
while(mappedparticles < nump)
  xpos = numcellx * rand;
  ypos = numcelly * rand;
  zpos = numcellz * rand;
  % Identify cell the particle belongs to
  cellx = floor(xpos);
  celly = floor(ypos);
  cellz = floor(zpos);
  % Cell ID in the cell list (+1 because of 1-based indexing)
  cellid = cellz*numcellx*numcelly + celly*numcellx + cellx + 1;
  % Does the cell have less than the max number of particles?
  if(pcount(cellid) < maxppc)
    % write particle info to cell
    index = pcount(cellid) + 1;
    cell_list(cellid,index,1) = xpos;
    cell_list(cellid,index,2) = ypos;
    cell_list(cellid,index,3) = zpos;

    % Record keeping
    pcount(cellid)  = pcount(cellid) + 1;
    mappedparticles = mappedparticles + 1;
  end
end

% Convert particle positoins to (grid point + oi) format and write to arrays p_x, p_y, p_oi_x, etc.
convertedparticles = 0;
lines = 0;
seq_id = 0;
while(convertedparticles < nump)
  if(iseq(mod(seq_id,seqlen)+1) == -1) % Bubble
    % Write zeros to data arrays
    p_x1(lines+1)      = 0;
    p_oi_x1(lines+1)   = sfi(0, 32, 10);
    p_y1(lines+1)      = 0;
    p_oi_y1(lines+1)   = sfi(0, 32, 10);
    p_z1(lines+1)      = 0;
    p_oi_z1(lines+1)   = sfi(0, 32, 10);
    p_q1(lines+1)      = 0;
    validp(lines + 1)  = 0;
    % Write particle info in readable form to output file
    fprintf(filehr, '%0d) Bubble\n', (lines+1)); 
    % Update counters (lines and sequence ID)
    lines  = lines + 1;
    seq_id = seq_id + 1;
  else % Not a bubble
    %disp(mod(seq_id,seqlen));
    %disp(mod(seq_id,seqlen)+1);
    %disp(iseq(mod(seq_id,seqlen)+1));
    if(pcount(iseq(mod(seq_id,seqlen)+1)+1) > 0) 
    % +1 for both pcount and iseq because of zero based indexing generated by the sequence generator code.
    % Does the cell pointed by the current index sequence value has particles to be picked?
      cellpcount = pcount(iseq(mod(seq_id,seqlen)+1)+1); % Number of particles left in the selected cell
      pick_xpos  = cell_list(iseq(mod(seq_id,seqlen)+1)+1, cellpcount, 1);
      pick_ypos  = cell_list(iseq(mod(seq_id,seqlen)+1)+1, cellpcount, 2);
      pick_zpos  = cell_list(iseq(mod(seq_id,seqlen)+1)+1, cellpcount, 3);
      % Write particle info in readable form to output file
      fprintf(filehr, '%0d) %f\t%f\t%f\t%d\n', (lines+1), pick_xpos, pick_ypos, pick_zpos,iseq(mod(seq_id,seqlen)+1)); 
      % Convert cell to grid
      gridposx = pick_xpos * cellgridratiox;
      gridposy = pick_ypos * cellgridratioy;
      gridposz = pick_zpos * cellgridratioz;
      % convert to grid point + oi format 
      intx = floor(gridposx); % Take floor to get the integer part of the grid index
      inty = floor(gridposy);
      intz = floor(gridposz);
      oi_x = gridposx - intx; % Fraction
      oi_y = gridposy - inty;
      oi_z = gridposz - intz;
      % Record particle info for further processing
      % Original arrays
      p_x(convertedparticles+1)    = intx;
      p_oi_x(convertedparticles+1) = sfi(oi_x, 32, 10);
      p_y(convertedparticles+1)    = inty;
      p_oi_y(convertedparticles+1) = sfi(oi_y, 32, 10);
      p_z(convertedparticles+1)    = intz;
      p_oi_z(convertedparticles+1) = sfi(oi_z, 32, 10);
      % Extended arrays
      p_x1(lines+1)    = intx;
      p_oi_x1(lines+1) = sfi(oi_x, 32, 10);
      p_y1(lines+1)    = inty;
      p_oi_y1(lines+1) = sfi(oi_y, 32, 10);
      p_z1(lines+1)    = intz;
      p_oi_z1(lines+1) = sfi(oi_z, 32, 10);
      p_q1(lines+1)    = p_q(convertedparticles+1);
      validp(lines+1)  = 1;
      % Decrease number of particles in the cell
      pcount(iseq(mod(seq_id,seqlen)+1)+1) = cellpcount - 1;
      % Increase counters
      convertedparticles = convertedparticles + 1;
      lines              = lines + 1;
      seq_id             = seq_id + 1;
    else % Cell is empty 
      %Go to next sequence ID
      seq_id = seq_id + 1;
    end
  end
end

% Header files
fprintf(file0, 'localparam NUMP = 32''d%0d;\n\n', nump);
fprintf(file0, 'localparam [0:%0d][%0d:0] P_INFO = {\n', nump-1, pmemw-1);	

%fprintf(file1, 'localparam NUMP = 32''d%0d;\n\n', nump);
fprintf(file1, 'localparam [0:%0d][%0d:0] P_INFO_NEW = {\n', lines-1, pmemw); % Additional bit for the valid signal

fprintf(filehr, 'Particle List\n');


% Write to old particle info file
for ll = 0:nump-1
  fprintf(file0, '  %0d''d%0d, 27''h%s, %0d''d%0d, 27''h%s, %0d''d%0d, 27''h%s, 32''h%s', zaddrw, p_z(ll+1), hex(p_oi_z(ll+1)), yaddrw, p_y(ll+1), hex(p_oi_y(ll+1)), xaddrw, p_x(ll+1), hex(p_oi_x(ll+1)), hex(p_q(ll+1)));
  if (ll == nump-1)
    fprintf(file0, '};\n');
  else
    fprintf(file0, ',\n');
  end
end

% Write C header file for OPAE
fileC = fopen('./particle_info.h', 'w'); % Particle info for the old design
fprintf(fileC, 'const uint16_t p_info [%d][12] = {\n', lines);
for pp = 1:lines-1
  zt  = hex(p_oi_z1(pp));
  zt1 = extractBetween(zt,1,4);
  zt2 = extractBetween(zt,5,8);
  yt  = hex(p_oi_y1(pp));
  yt1 = extractBetween(yt,1,4);
  yt2 = extractBetween(yt,5,8);
  xt  = hex(p_oi_x1(pp));
  xt1 = extractBetween(xt,1,4);
  xt2 = extractBetween(xt,5,8);
  qt  = hex(p_q1(pp));
  qt1 = extractBetween(qt,1,4);
  qt2 = extractBetween(qt,5,8);
  fprintf(fileC, '  {0x%04x, 0x%04x, 0x%s, 0x%s, 0x%04x, 0x%s, 0x%s, 0x%04x, 0x%s, 0x%s, 0x%s, 0x%s},\n', uint16(validp(pp)), uint16(p_z1(pp)), zt1{1}, zt2{1}, uint16(p_y1(pp)), yt1{1}, yt2{1}, uint16(p_x1(pp)), xt1{1}, xt2{1}, qt1{1}, qt2{1});
end

zt  = hex(p_oi_z1(lines));
zt1 = extractBetween(zt,1,4);
zt2 = extractBetween(zt,5,8);
yt  = hex(p_oi_y1(lines));
yt1 = extractBetween(yt,1,4);
yt2 = extractBetween(yt,5,8);
xt  = hex(p_oi_x1(lines));
xt1 = extractBetween(xt,1,4);
xt2 = extractBetween(xt,5,8);
qt  = hex(p_q1(lines));
qt1 = extractBetween(qt,1,4);
qt2 = extractBetween(qt,5,8);
fprintf(fileC, '  {0x%04x, 0x%04x, 0x%s, 0x%s, 0x%04x, 0x%s, 0x%s, 0x%04x, 0x%s, 0x%s, 0x%s, 0x%s}};', uint16(validp(lines)), uint16(p_z1(lines)), zt1{1}, zt2{1}, uint16(p_y1(lines)), yt1{1}, yt2{1}, uint16(p_x1(lines)), xt1{1}, xt2{1}, qt1{1}, qt2{1});

fclose(fileC);


% Write C header file with new code
fileC2 = fopen('./particle_info_alt.h', 'w'); % Particle info for the old design

fprintf(fileC2, 'const uint16_t p_info [%d][12] = {\n', lines);

% Write to C header file
for ll = 0:lines-1
  hexvalid = hex(sfi(validp(ll+1),16,0));
  hexpx = hex(sfi(p_x1(ll+1),16,0));
  hexpy = hex(sfi(p_y1(ll+1),16,0));
  hexpz = hex(sfi(p_z1(ll+1),16,0));
  hexpoiz = hex(p_oi_z1(ll+1));
  hexpoiy = hex(p_oi_y1(ll+1));
  hexpoix = hex(p_oi_x1(ll+1));
  hexq = hex(p_q1(ll+1));

  fprintf(fileC2, '  {0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s, 0x%s}', hexvalid, hexpz, hexpoiz(1:4), hexpoiz(5:8), hexpy, hexpoiy(1:4), hexpoiy(5:8), hexpx, hexpoix(1:4), hexpoix(5:8), hexq(1:4), hexq(5:8) );
  if (ll == lines-1)
    fprintf(fileC2, '};\n');
  else
    fprintf(fileC2, ',\n');
  end 
end

fclose(fileC2);


% Write to new particle info file
for ll = 0:lines-1
  fprintf(file1, '  1''d%0d,  %0d''d%0d, 27''h%s, %0d''d%0d, 27''h%s, %0d''d%0d, 27''h%s, 32''h%s', validp(ll+1), zaddrw, p_z1(ll+1), hex(p_oi_z1(ll+1)), yaddrw, p_y1(ll+1), hex(p_oi_y1(ll+1)), xaddrw, p_x1(ll+1), hex(p_oi_x1(ll+1)), hex(p_q1(ll+1)));
  if (ll == lines-1)
    fprintf(file1, '};\n');
  else
    fprintf(file1, ',\n');
  end
end

fclose(file0);
fclose(file1);
fclose(filehr);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generate Particle Information
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
gmem = single(zeros([numgpx, numgpy, numgpz]));

for ii = 1:nump
  for jj = -1:nnn1d-2
    for kk = -1:nnn1d-2
      for ll = -1:nnn1d-2
        temp =        (single(p_oi_x.data(ii))^3*p2gmat(jj+2,1) + single(p_oi_x.data(ii))^2*p2gmat(jj+2,2) + single(p_oi_x.data(ii))*p2gmat(jj+2,3) + p2gmat(jj+2,4));
        temp = temp * (single(p_oi_y.data(ii))^3*p2gmat(kk+2,1) + single(p_oi_y.data(ii))^2*p2gmat(kk+2,2) + single(p_oi_y.data(ii))*p2gmat(kk+2,3) + p2gmat(kk+2,4));
        temp = temp * (single(p_oi_z.data(ii))^3*p2gmat(ll+2,1) + single(p_oi_z.data(ii))^2*p2gmat(ll+2,2) + single(p_oi_z.data(ii))*p2gmat(ll+2,3) + p2gmat(ll+2,4));
        temp = temp * (single(p_q.data(ii)));
        gmem((mod((p_x(ii)+jj), numgpx)+1), (mod((p_y(ii)+kk), numgpy)+1), (mod((p_z(ii)+ll), numgpz)+1)) = gmem((mod((p_x(ii)+jj), numgpx)+1), (mod((p_y(ii)+kk), numgpy)+1), (mod((p_z(ii)+ll), numgpz)+1)) + temp;
      end
    end
  end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Save matlab workspace
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
save('workspace_save1');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Grid Value Check
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
file0 = fopen('./gmem_map_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_CMAP_CHK = {\n');
for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(gmem(ii,jj,kk)));
      itmp = num2hex(single(0));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FFT Prep
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mappedC = gmem;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FFTX Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute FFT in X dimension
fftx = fft(mappedC, numgpx, 1);

% Create Verilog header file
file0 = fopen('./gmem_fftx_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_FFTX_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(fftx(ii,jj,kk)));
      itmp = num2hex(imag(fftx(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FFTY Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute FFT in Y dimension
ffty = fft(fftx, numgpy, 2);

% Create Verilog header file
file0 = fopen('./gmem_ffty_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_FFTY_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(ffty(ii,jj,kk)));
      itmp = num2hex(imag(ffty(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FFTZ Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute FFT in Z dimension
fftz = fft(ffty, numgpz, 3);

% Create Verilog header file with FFT output for Z dimension.
file0 = fopen('./gmem_fftz_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_FFTZ_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(fftz(ii,jj,kk)));
      itmp = num2hex(imag(fftz(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FFTZNG values (FFT output multiplied by Green's ROM values.)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Apply Greens Function
fftzng = fftz.*grom;

% Create Verilog header file
file0 = fopen('./gmem_fftzng_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_FFTZNG_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(fftzng(ii,jj,kk)));
      itmp = num2hex(imag(fftzng(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IFFTX Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute IFFT in X dimension
ifftx = ifft(fftzng, numgpx, 1);

% Multiply by x dimension size to account for using forward FFT in RTL implementation
ifftx = ifftx*numgpx;

% Create Verilog header file
file0 = fopen('./gmem_ifftx_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_IFFTX_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(ifftx(ii,jj,kk)));
      itmp = num2hex(imag(ifftx(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IFFTY Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute IFFT in Y dimension
iffty = ifft(ifftx, numgpy, 2);

% Multiply by Y dimension size to account for using forward FFT in RTL implementation
iffty = iffty*numgpy;

% Create Verilog header file
file0 = fopen('./gmem_iffty_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_IFFTY_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(iffty(ii,jj,kk)));
      itmp = num2hex(imag(iffty(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IFFTZ Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute IFFT in Z dimension
ifftz = ifft(iffty, numgpz, 3);

% Multiply  by Z dimension size to account for using forward FFT in RTL implementation
ifftz = ifftz*numgpz;
 
% Create Verilog header file
file0 = fopen('./gmem_ifftz_check_values.svh', 'w');

fprintf(file0, 'localparam [GSIZE1DX-1:0][GSIZE1DY-1:0][GSIZE1DZ-1:0][1:0][31:0] GMEM_IFFTZ_CHK = {\n');

for ii = numgpx:-1:1
  for jj = numgpy:-1:1
    for kk = numgpz:-1:1
      rtmp = num2hex(real(ifftz(ii,jj,kk)));
      itmp = num2hex(imag(ifftz(ii,jj,kk)));
      fprintf(file0, '  {32''h%s, 32''h%s} /* (%0d, %0d, %0d) {real, imag} */', rtmp, itmp, ii-1, jj-1, kk-1);
      if (ii==1) && (jj==1) && (kk==1)
        fprintf(file0, '};\n');
      else
        fprintf(file0, ',\n');
      end
    end
  end
end

fclose(file0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Force Check Values
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pad the now potential grid with periodic repititon of 2D matricies so that
% we do not need to perform boundary checks when applying force coefficients
potmem = cat(1,  ifftz(numgpx,      :,      :),  ifftz,  ifftz(1:3,   :,   :));
potmem = cat(2, potmem(     :, numgpy,      :), potmem, potmem(  :, 1:3,   :));
potmem = cat(3, potmem(     :,      :, numgpz), potmem, potmem(  :,   :, 1:3));

% Create a nump by nnn1d by nnn1d by nnn1d matrix to hold force coefficients
% for each particle
fmemx = single(zeros([nump, nnn1d, nnn1d, nnn1d]));
fmemy = single(zeros([nump, nnn1d, nnn1d, nnn1d]));
fmemz = single(zeros([nump, nnn1d, nnn1d, nnn1d]));

for ii = 1:nump
  for jj = 1:nnn1d
    for kk = 1:nnn1d
      for ll = 1:nnn1d
        fmemx(ii, jj, kk, ll) =                         (single(p_oi_x.data(ii))^3*g2pmat(jj,1) + single(p_oi_x.data(ii))^2*g2pmat(jj,2) + single(p_oi_x.data(ii))*g2pmat(jj,3) + g2pmat(jj,4));
        fmemx(ii, jj, kk, ll) = fmemx(ii, jj, kk, ll) * (single(p_oi_y.data(ii))^3*p2gmat(kk,1) + single(p_oi_y.data(ii))^2*p2gmat(kk,2) + single(p_oi_y.data(ii))*p2gmat(kk,3) + p2gmat(kk,4));
        fmemx(ii, jj, kk, ll) = fmemx(ii, jj, kk, ll) * (single(p_oi_z.data(ii))^3*p2gmat(ll,1) + single(p_oi_z.data(ii))^2*p2gmat(ll,2) + single(p_oi_z.data(ii))*p2gmat(ll,3) + p2gmat(ll,4));

        fmemy(ii, jj, kk, ll) =                         (single(p_oi_x.data(ii))^3*p2gmat(jj,1) + single(p_oi_x.data(ii))^2*p2gmat(jj,2) + single(p_oi_x.data(ii))*p2gmat(jj,3) + p2gmat(jj,4));
        fmemy(ii, jj, kk, ll) = fmemy(ii, jj, kk, ll) * (single(p_oi_y.data(ii))^3*g2pmat(kk,1) + single(p_oi_y.data(ii))^2*g2pmat(kk,2) + single(p_oi_y.data(ii))*g2pmat(kk,3) + g2pmat(kk,4));
        fmemy(ii, jj, kk, ll) = fmemy(ii, jj, kk, ll) * (single(p_oi_z.data(ii))^3*p2gmat(ll,1) + single(p_oi_z.data(ii))^2*p2gmat(ll,2) + single(p_oi_z.data(ii))*p2gmat(ll,3) + p2gmat(ll,4));

        fmemz(ii, jj, kk, ll) =                         (single(p_oi_x.data(ii))^3*p2gmat(jj,1) + single(p_oi_x.data(ii))^2*p2gmat(jj,2) + single(p_oi_x.data(ii))*p2gmat(jj,3) + p2gmat(jj,4));
        fmemz(ii, jj, kk, ll) = fmemz(ii, jj, kk, ll) * (single(p_oi_y.data(ii))^3*p2gmat(kk,1) + single(p_oi_y.data(ii))^2*p2gmat(kk,2) + single(p_oi_y.data(ii))*p2gmat(kk,3) + p2gmat(kk,4));
        fmemz(ii, jj, kk, ll) = fmemz(ii, jj, kk, ll) * (single(p_oi_z.data(ii))^3*g2pmat(ll,1) + single(p_oi_z.data(ii))^2*g2pmat(ll,2) + single(p_oi_z.data(ii))*g2pmat(ll,3) + g2pmat(ll,4));
      end
    end
  end
end


for ii = 1:nump
  p_f_x(ii) = sum((squeeze(fmemx(ii,:,:,:)) .* real(potmem((p_x(ii)+1):(p_x(ii)+4), (p_y(ii)+1):(p_y(ii)+4), (p_z(ii)+1):(p_z(ii)+4)))), 'all');
  p_f_y(ii) = sum((squeeze(fmemy(ii,:,:,:)) .* real(potmem((p_x(ii)+1):(p_x(ii)+4), (p_y(ii)+1):(p_y(ii)+4), (p_z(ii)+1):(p_z(ii)+4)))), 'all');
  p_f_z(ii) = sum((squeeze(fmemz(ii,:,:,:)) .* real(potmem((p_x(ii)+1):(p_x(ii)+4), (p_y(ii)+1):(p_y(ii)+4), (p_z(ii)+1):(p_z(ii)+4)))), 'all');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Save matlab workspace
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
save('workspace_save2');


file0 = fopen('./force_info.svh', 'w');

fprintf(file0, 'localparam [0:%0d][0:2][31:0] P_FORCE = {\n', nump-1);	

for ii = 1:nump
  tmpx = num2hex(p_f_x(ii));
  tmpy = num2hex(p_f_y(ii));
  tmpz = num2hex(p_f_z(ii));
  fprintf(file0, '  {32''h%s, 32''h%s, 32''h%s}', tmpx, tmpy, tmpz);
  if (ii == nump)
    fprintf(file0, '};\n');
  else
    fprintf(file0, ',\n');
  end
end

fclose(file0);


% Write header file for OPAE
fileF = fopen('./force_info.h', 'w'); % Particle info for the old design
fprintf(fileF, 'const uint32_t p_force [%d][3] = {\n', nump);

for fp = 1:nump-1
  tmpx = num2hex(p_f_x(fp));
  tmpy = num2hex(p_f_y(fp));
  tmpz = num2hex(p_f_z(fp));
  fprintf(fileF, '  {0x%s, 0x%s, 0x%s},\n', tmpx, tmpy, tmpz);
end

tmpx = num2hex(p_f_x(nump));
tmpy = num2hex(p_f_y(nump));
tmpz = num2hex(p_f_z(nump));
fprintf(fileF, '  {0x%s, 0x%s, 0x%s}};', tmpx, tmpy, tmpz);



