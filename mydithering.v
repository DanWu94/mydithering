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
                      input  wire [15:0] r0,
                      input  wire [15:0] r1,
                      input  wire [15:0] r2,
                      input  wire [15:0] r3,
                      input  wire [15:0] r4,
                      input  wire [15:0] r5,
                      input  wire [15:0] r6,
                      input  wire [15:0] r7,
                      output reg        de_req,
                      input  wire        de_ack,
                      output wire [17:0] de_addr,
                      output reg  [3:0] de_nbyte,
                      output wire        de_rnw,
                      output reg [31:0] de_w_data,
                      input  wire [31:0] de_r_data );

reg draw_state;
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

reg [15:0] x_start;
reg [15:0] x_now;
reg [15:0] y_now;
reg [15:0] x_end;
reg [15:0] y_end;
reg [7:0] colour_input;
reg [7:0] colour_draw;
reg [19:0] address;
reg [9:0] error_mem[0:640];

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
	      colour_input <= r4[7:0];
	      draw_state <= `BUSY;
	      for (k = 0; k < 640; k = k + 1) begin
          error_mem[k] = 0;
        end
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
