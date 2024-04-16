module Reduction_Tree(clk, rst, fp_en, out_port, in_port1, in_port2);

input                         clk;
input                         rst;
input                         fp_en;
output                 [31:0] out_port;
input   [3:0][3:0][3:0][31:0] in_port1;
input   [3:0][3:0][3:0][31:0] in_port2;

logic  [1:0][31:0] stage1;
logic  [3:0][31:0] stage2;
logic  [7:0][31:0] stage3;
logic [15:0][31:0] stage4;
logic [31:0][31:0] stage5;
logic [63:0][31:0] stage6;

genvar i;

for (i = 0; i < 64; i = i + 1) begin: mul
  FpMul u_FpMul (.clk(clk), .areset(rst), .en(fp_en), .a(in_port1[i[5:4]][i[3:2]][i[1:0]]), .b(in_port2[i[5:4]][i[3:2]][i[1:0]]), .q(stage6[i]));
end

FpAdd reduce5_31(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[63]), .b(stage6[62]), .q(stage5[31]));
FpAdd reduce5_30(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[61]), .b(stage6[60]), .q(stage5[30]));
FpAdd reduce5_29(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[59]), .b(stage6[58]), .q(stage5[29]));
FpAdd reduce5_28(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[57]), .b(stage6[56]), .q(stage5[28]));
FpAdd reduce5_27(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[55]), .b(stage6[54]), .q(stage5[27]));
FpAdd reduce5_26(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[53]), .b(stage6[52]), .q(stage5[26]));
FpAdd reduce5_25(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[51]), .b(stage6[50]), .q(stage5[25]));
FpAdd reduce5_24(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[49]), .b(stage6[48]), .q(stage5[24]));
FpAdd reduce5_23(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[47]), .b(stage6[46]), .q(stage5[23]));
FpAdd reduce5_22(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[45]), .b(stage6[44]), .q(stage5[22]));
FpAdd reduce5_21(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[43]), .b(stage6[42]), .q(stage5[21]));
FpAdd reduce5_20(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[41]), .b(stage6[40]), .q(stage5[20]));
FpAdd reduce5_19(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[39]), .b(stage6[38]), .q(stage5[19]));
FpAdd reduce5_18(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[37]), .b(stage6[36]), .q(stage5[18]));
FpAdd reduce5_17(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[35]), .b(stage6[34]), .q(stage5[17]));
FpAdd reduce5_16(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[33]), .b(stage6[32]), .q(stage5[16]));
FpAdd reduce5_15(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[31]), .b(stage6[30]), .q(stage5[15]));
FpAdd reduce5_14(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[29]), .b(stage6[28]), .q(stage5[14]));
FpAdd reduce5_13(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[27]), .b(stage6[26]), .q(stage5[13]));
FpAdd reduce5_12(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[25]), .b(stage6[24]), .q(stage5[12]));
FpAdd reduce5_11(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[23]), .b(stage6[22]), .q(stage5[11]));
FpAdd reduce5_10(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[21]), .b(stage6[20]), .q(stage5[10]));
FpAdd reduce5_9(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[19]), .b(stage6[18]), .q(stage5[9]));
FpAdd reduce5_8(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[17]), .b(stage6[16]), .q(stage5[8]));
FpAdd reduce5_7(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[15]), .b(stage6[14]), .q(stage5[7]));
FpAdd reduce5_6(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[13]), .b(stage6[12]), .q(stage5[6]));
FpAdd reduce5_5(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[11]), .b(stage6[10]), .q(stage5[5]));
FpAdd reduce5_4(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[9]), .b(stage6[8]), .q(stage5[4]));
FpAdd reduce5_3(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[7]), .b(stage6[6]), .q(stage5[3]));
FpAdd reduce5_2(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[5]), .b(stage6[4]), .q(stage5[2]));
FpAdd reduce5_1(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[3]), .b(stage6[2]), .q(stage5[1]));
FpAdd reduce5_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage6[1]), .b(stage6[0]), .q(stage5[0]));

FpAdd reduce4_15(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[31]), .b(stage5[30]), .q(stage4[15]));
FpAdd reduce4_14(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[29]), .b(stage5[28]), .q(stage4[14]));
FpAdd reduce4_13(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[27]), .b(stage5[26]), .q(stage4[13]));
FpAdd reduce4_12(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[25]), .b(stage5[24]), .q(stage4[12]));
FpAdd reduce4_11(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[23]), .b(stage5[22]), .q(stage4[11]));
FpAdd reduce4_10(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[21]), .b(stage5[20]), .q(stage4[10]));
FpAdd reduce4_9(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[19]), .b(stage5[18]), .q(stage4[9]));
FpAdd reduce4_8(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[17]), .b(stage5[16]), .q(stage4[8]));
FpAdd reduce4_7(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[15]), .b(stage5[14]), .q(stage4[7]));
FpAdd reduce4_6(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[13]), .b(stage5[12]), .q(stage4[6]));
FpAdd reduce4_5(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[11]), .b(stage5[10]), .q(stage4[5]));
FpAdd reduce4_4(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[9]), .b(stage5[8]), .q(stage4[4]));
FpAdd reduce4_3(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[7]), .b(stage5[6]), .q(stage4[3]));
FpAdd reduce4_2(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[5]), .b(stage5[4]), .q(stage4[2]));
FpAdd reduce4_1(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[3]), .b(stage5[2]), .q(stage4[1]));
FpAdd reduce4_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage5[1]), .b(stage5[0]), .q(stage4[0]));

FpAdd reduce3_7(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[15]), .b(stage4[14]), .q(stage3[7]));
FpAdd reduce3_6(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[13]), .b(stage4[12]), .q(stage3[6]));
FpAdd reduce3_5(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[11]), .b(stage4[10]), .q(stage3[5]));
FpAdd reduce3_4(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[9]), .b(stage4[8]), .q(stage3[4]));
FpAdd reduce3_3(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[7]), .b(stage4[6]), .q(stage3[3]));
FpAdd reduce3_2(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[5]), .b(stage4[4]), .q(stage3[2]));
FpAdd reduce3_1(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[3]), .b(stage4[2]), .q(stage3[1]));
FpAdd reduce3_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage4[1]), .b(stage4[0]), .q(stage3[0]));

FpAdd reduce2_3(.clk(clk), .areset(rst), .en(fp_en), .a(stage3[7]), .b(stage3[6]), .q(stage2[3]));
FpAdd reduce2_2(.clk(clk), .areset(rst), .en(fp_en), .a(stage3[5]), .b(stage3[4]), .q(stage2[2]));
FpAdd reduce2_1(.clk(clk), .areset(rst), .en(fp_en), .a(stage3[3]), .b(stage3[2]), .q(stage2[1]));
FpAdd reduce2_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage3[1]), .b(stage3[0]), .q(stage2[0]));

FpAdd reduce1_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage2[1]), .b(stage2[0]), .q(stage1[0]));
FpAdd reduce1_1(.clk(clk), .areset(rst), .en(fp_en), .a(stage2[3]), .b(stage2[2]), .q(stage1[1]));

FpAdd reduce0_0(.clk(clk), .areset(rst), .en(fp_en), .a(stage1[1]), .b(stage1[0]), .q(out_port));

endmodule
