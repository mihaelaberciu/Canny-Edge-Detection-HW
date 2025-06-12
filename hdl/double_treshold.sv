//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : double_threshold.sv
// Author      : Mihaela - Georgiana Berciu
// Date        : 17.02.2025
// Description : Double Threshold after NMS Stage
//---------------------------------------------------------------------

module double_threshold#(
  FRAME_WIDTH  = 640,     // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,     // frame height parameter  -default VGA res
  PIX_WIDTH    =  24,     // 8 bits for pixels after grayscale conversion
  HIGH_THRESH  = 100,     // High threshold value
  LOW_THRESH   =  50      // Low threshold value
)(
  input                          clk       ,                                     // clock
  input                          rst_n     ,                                     // reset, asynchronous low
  // input frame interface 
  input                          thin_val  ,                                     // thin edge frame valid
  input      [(PIX_WIDTH/3)-1:0] thin_edge [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // thin edge input frame
  // output frame interface
  output reg                     dual_val  ,                                     // dual threshold valid
  output reg [(PIX_WIDTH/3)-1:0] str_edge  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // strong edges output frame
  output reg [(PIX_WIDTH/3)-1:0] weak_edge [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]   // weak edges output frame
);

// State machine parameters
localparam IDLE    = 2'd0;
localparam PADDING = 2'd1;
localparam PROCESS = 2'd2;

// State register
reg [1:0] state;

// Position counters
reg [$clog2(FRAME_WIDTH )+1:0] padd_x;   // Padding x position
reg [$clog2(FRAME_HEIGHT)+1:0] padd_y;   // Padding y position
reg [$clog2(FRAME_WIDTH )-1:0] proc_x;   // Processing x position
reg [$clog2(FRAME_HEIGHT)-1:0] proc_y;   // Processing y position

// Padding tracking - X axis of the frame - PADDING 
always @(posedge clk or negedge rst_n) 
if (~rst_n) padd_x <= 'd0; else 
if (state == PADDING) begin
    if (padd_x == FRAME_WIDTH+1) padd_x <= 'd0; else 
                                 padd_x <= padd_x + 'd1; 
end else 
                                 padd_x <= 'd0;

// Padding tracking - Y axis of the frame - PADDING 
always @(posedge clk or negedge rst_n)
if (~rst_n) padd_y <= 'd0; else
if (state == PADDING) begin
  if ((padd_x == FRAME_WIDTH+1) && (padd_y == FRAME_HEIGHT+1)) padd_y <= 'd0;         else
  if  (padd_x == FRAME_WIDTH+1)                                padd_y <= padd_y + 'd1;
end else 
                                                               padd_y <= 'd0;

// Processing tracking - X axis of the frame - PROCESS
always @(posedge clk or negedge rst_n) 
if (~rst_n)                      proc_x <= 'd0; else 
if (state == PROCESS) begin
    if (proc_x == FRAME_WIDTH-1) proc_x <= 'd0; else 
                                 proc_x <= proc_x + 'd1; 
end else 
                                 proc_x <= 'd0;

// Processing tracking - Y axis of the frame - PROCESS
always @(posedge clk or negedge rst_n)
if (~rst_n) proc_y <= 'd0; else
if (state == PROCESS) begin
  if ((proc_x == FRAME_WIDTH-1) && (proc_y == FRAME_HEIGHT-1)) proc_y <= 'd0;         else
  if  (proc_x == FRAME_WIDTH-1)                                proc_y <= proc_y + 'd1;
end else 
                                                               proc_y <= 'd0;

// State machine logic
always @(posedge clk or negedge rst_n) 
if (~rst_n) state <= IDLE; else
case (state)
  IDLE   : if (thin_val)                                            state <= PADDING;
  PADDING: if (padd_x == FRAME_WIDTH+1 && padd_y == FRAME_HEIGHT+1) state <= PROCESS;
  PROCESS: if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1) state <= IDLE   ;
  default:                                                          state <= IDLE   ;
endcase

// Strong edges thresholding
always @(posedge clk or negedge rst_n)
if (~rst_n)           str_edge[proc_y][proc_x] <= 'd0; else
if (state == PROCESS) str_edge[proc_y][proc_x] <= (thin_edge[proc_y][proc_x] >= HIGH_THRESH) ? 8'd255 : 8'd0;

// Weak edges thresholding
always @(posedge clk or negedge rst_n)
if (~rst_n)           weak_edge[proc_y][proc_x] <= 'd0; else
if (state == PROCESS) weak_edge[proc_y][proc_x] <= ((thin_edge[proc_y][proc_x] >= LOW_THRESH) && (thin_edge[proc_y][proc_x] < HIGH_THRESH)) ? 8'd128 : 8'd0;

// Dual threshold valid signal
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                  dual_val <= 1'b0; else
if (state == PROCESS && proc_y == FRAME_HEIGHT-1 && proc_x == FRAME_WIDTH-1) dual_val <= 1'b1; else
if (state == IDLE)                                                           dual_val <= 1'b0;

endmodule