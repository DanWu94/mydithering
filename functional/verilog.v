// Verilog HDL for "COMP32212", "mydithering" "functional"
// This is a cell which performs dithering 
// Modified by Dan Wu 16/03/2015

`define IDLE 0
`define BUSY 1
`define TPD 2

module mydithering(   input  wire        clk,
                      input  wire        req,
                      output reg         ack,
                      output wire        busy,
                      input  wire [15:0] r0,//x_start
                      input  wire [15:0] r1,//y_start
                      input  wire [15:0] r2,//x_end
                      input  wire [15:0] r3,//y_end
                      input  wire [15:0] r4,//colour_input_rg
                      input  wire [15:0] r5,//colour_input_b
                      input  wire [15:0] r6,
                      input  wire [15:0] r7,
                      output reg        de_req,
                      input  wire        de_ack,
                      output wire [17:0] de_addr,
                      output reg  [3:0] de_nbyte,
                      output wire        de_rnw,
                      output wire [31:0] de_w_data,
                      input  wire [31:0] de_r_data );

reg draw_state;
reg [15:0] x_start;
reg [15:0] x_now;
reg [15:0] y_now;
reg [15:0] x_end;
reg [15:0] y_end;
reg [7:0] colour_input_r;
wire [2:0] colour_draw_r;
reg [7:0] colour_now_r;
wire [7:0] colour_next_r;
reg [19:0] address;
reg [9:0] error_mem_r[0:640];
wire [5:0] error_r;
reg [9:0] error_next_r;
integer k;

reg [8:0] ppl1_r;
reg [8:0] ppl2_r;
reg [8:0] ppl3_r;
wire [8:0] ppl1_toUpdate_r;
wire [8:0] ppl2_toUpdate_r;
wire [8:0] ppl3_toUpdate_r;

colourCal clrcl(  colour_now_r,
                  error_r,
                  colour_draw_r);

pipelineCal pplcl1( error_r,
                    3'd1,
                    9'b0,
                    ppl1_toUpdate_r);
pipelineCal pplcl2( error_r,
                    3'd5,
                    ppl1_r,
                    ppl2_toUpdate_r);
pipelineCal pplcl3( error_r,
                    3'd3,
                    ppl2_r,
                    ppl3_toUpdate_r);
colourUpdate clrpdt(error_next_r,
                    error_r,
                    colour_input_r,
                    colour_next_r);
assign de_w_data = {colour_draw_r,5'b0,colour_draw_r,5'b0,colour_draw_r,5'b0,colour_draw_r,5'b0};
assign de_rnw = 0;

assign busy = (draw_state == `BUSY);
initial draw_state = `IDLE;
initial ack        = 0;
initial de_req = 0;

assign de_addr = address[19:2];
always @(address[1:0])
  case(address[1:0])
    2'b00 : de_nbyte <= 4'b1110;
    2'b01 : de_nbyte <= 4'b1101;
    2'b10 : de_nbyte <= 4'b1011;
    2'b11 : de_nbyte <= 4'b0111;
    default:de_nbyte <= 4'b1111;
  endcase

always@ (posedge clk)
  case(draw_state)
    `IDLE:
      if(req) begin
        #`TPD;
        ack <= 1;
        x_start <= r0;
        x_now <= r0;
        y_now <= r1;
        x_end <= r2;
        y_end <= r3;
        colour_input_r <= r4[7:0];
        colour_now_r <= r4[7:0];
        ppl1_r <= 9'b0;
        ppl2_r <= 9'b0;
        ppl3_r <= 9'b0;
        draw_state <= `BUSY;
        for (k = 0; k < 640; k = k + 1) begin
          error_mem_r[k] = 0;
        end
        error_next_r <= 9'b0;
      end
    `BUSY: begin
      #`TPD;
      ack <= 0;
      de_req <= 1;
      if(de_ack) begin
        if (y_now == y_end + 1) begin
          draw_state <= `IDLE;
          de_req <= 0;
        end
        else begin
          address <= x_now + y_now*640;
          ppl1_r <= ppl1_toUpdate_r;
          ppl2_r <= ppl2_toUpdate_r;
          ppl3_r <= ppl3_toUpdate_r;
          
          if (x_now == x_start) begin
            error_mem_r[x_end-1] <= ppl3_r;
          end
          else if(x_now == x_start+1) begin
            error_mem_r[x_end] <= ppl3_r;
          end
          else begin
            error_mem_r[x_now-2] <= ppl3_r;
          end
          
          if (x_now == x_end-1) begin
            error_next_r <= error_mem_r[x_start];
          end
          else if (x_now == x_end) begin
            error_next_r <= error_mem_r[x_start+1];
          end
          else begin
            error_next_r <= error_mem_r[x_now+2];
          end
          
          colour_now_r <= colour_next_r;
          if (x_now == x_end) begin
            y_now <= y_now + 1;
            x_now <= x_start;
          end
          else begin
            x_now <= x_now + 1;
          end
        end
      end
    end
  endcase
endmodule

module colourCal( input wire [7:0] colour_now,
                  output reg [5:0] error,
                  output reg [2:0] colour_draw);
always@(colour_now)begin
  if(colour_now[7:5]==3'b111)begin
    colour_draw = 3'b111;
    error = {1'b0,colour_now[4:0]};
  end
  else begin
    if(colour_now[4]) begin
      colour_draw = colour_now[7:5]+1;
      error = {1'b1,colour_now[4:0]};
    end
    else begin
      colour_draw = colour_now[7:5];
      error = {1'b0,colour_now[4:0]};
    end
  end
end

endmodule

module pipelineCal( input wire [5:0] error,
                    input wire [2:0] multiplex,
                    input wire [8:0] ppl_old,
                    output reg [8:0] ppl_new);
reg [8:0] ppl_temp;
always@(*)begin
  ppl_temp = 9'b0;
  if(multiplex[0])begin
    ppl_temp = ppl_temp+{{3{error[5]}},error};
  end
  if(multiplex[1])begin
    ppl_temp = ppl_temp+{{2{error[5]}},error,1'b0};
  end
  if(multiplex[2])begin
    ppl_temp = ppl_temp+{{1{error[5]}},error,2'b0};
  end
  ppl_new = ppl_old+ppl_temp;
end

endmodule

module colourUpdate(  input wire [8:0] error_next,
                      input wire [5:0] error,
                      input wire [7:0] colour_input,
                      output reg [7:0] colour_next);
reg [8:0] error_temp;
always@(*) begin
  error_temp = error_next;
  error_temp = error_temp+{error,3'b0};
  error_temp = error_temp+~{{3{error[5]}},error}+1;
  if(error_temp[3]) begin
    colour_next = colour_input+{{3{error_temp[8]}},error_temp[8:4]}+1;
  end
  else begin
    colour_next = colour_input+{{3{error_temp[8]}},error_temp[8:4]};
  end
end

endmodule