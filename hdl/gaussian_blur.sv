//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : gaussian_blur.sv
// Author      : Mihaela - Georgiana Berciu
// Date        : 05.02.2025
// Description : Gaussian 3x3 mask on Grayscale image
//---------------------------------------------------------------------

module gaussian_blur#(
  FRAME_WIDTH  = 640,    // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,    // frame height parameter  -default VGA res
  PIX_WIDTH    = 24      // 8 bits for red[23:16], green[15:8], blue[7:0]
)(
  input                          clk       ,                                     // clock
  input                          rst_n     ,                                     // reset, asynchronous low
  // input frame interface
  input                          pix_val   ,                                     // pixel valid
  input                          pix_sof   ,                                     // pixel start of frame
  input                          pix_eof   ,                                     // pixel end of frame
  input                          pix_sol   ,                                     // pixel start of line
  input                          pix_eol   ,                                     // pixel end of line
  input      [(PIX_WIDTH/3)-1:0] pix_data  ,                                     // pixel grayscale value
  // output frame interface
  output reg                     gauss_val ,                                     // gaussian frame valid
  output reg [(PIX_WIDTH/3)-1:0] gauss_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]  // gaussian output frame
);

// State machine parameters
localparam IDLE    = 2'd0;
localparam CAPTURE = 2'd1;
localparam PADDING = 2'd2;
localparam PROCESS = 2'd3;

reg  [ 1:0] state;       // State register
wire [31:0] window_sum;  // intermediate sum of 3*3 window of pixels with 3*3 matrix [1 2 1 ; 2 4 2 ; 1 2 1]

reg [(PIX_WIDTH/3)-1:0] internal_frame       [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]; // Internal Frame buffer
reg [(PIX_WIDTH/3)-1:0] border_reflect_frame [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0]; // Original frame padded in PADDING state with border_reflect_101 tehnique

// Position counters
reg [$clog2(FRAME_WIDTH )-1:0] x_pos;
reg [$clog2(FRAME_HEIGHT)-1:0] y_pos;
reg [$clog2(FRAME_WIDTH )+1:0] padd_x;
reg [$clog2(FRAME_HEIGHT)+1:0] padd_y;
reg [$clog2(FRAME_WIDTH )-1:0] proc_x;
reg [$clog2(FRAME_HEIGHT)-1:0] proc_y;

// Frame capture
always @(posedge clk or negedge rst_n)
if (~rst_n)                      internal_frame[y_pos][x_pos] <= 'd0; else
if (state == CAPTURE && pix_val) internal_frame[y_pos][x_pos] <= pix_data;

// original window padding with border_reflect_101
always @(posedge clk or negedge rst_n)
if (~rst_n) border_reflect_frame[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from internal_frame to border_reflect_frame with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) border_reflect_frame[padd_y][padd_x] <= internal_frame[padd_y-1][padd_x-1];
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if (padd_x ==             0) border_reflect_frame[0][0]             <= internal_frame[1][1];             else 
    if (padd_x == FRAME_WIDTH+1) border_reflect_frame[0][FRAME_WIDTH+1] <= internal_frame[1][FRAME_WIDTH-2]; else  
                                 border_reflect_frame[0][padd_x]        <= internal_frame[1][padd_x-1];
  end
  // Bottom row padding (reflect from the second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if (padd_x ==             0) border_reflect_frame[FRAME_HEIGHT+1][0]             <= internal_frame[FRAME_HEIGHT-2][1];             else 
    if (padd_x == FRAME_WIDTH+1) border_reflect_frame[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= internal_frame[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                 border_reflect_frame[FRAME_HEIGHT+1][padd_x]        <= internal_frame[FRAME_HEIGHT-2][padd_x-1];
  end
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y ==              0) border_reflect_frame[0][0]              <= internal_frame[1][1];              else 
    if (padd_y == FRAME_HEIGHT+1) border_reflect_frame[FRAME_HEIGHT+1][0] <= internal_frame[FRAME_HEIGHT-2][1]; else  
                                  border_reflect_frame[padd_y][0] <= internal_frame[padd_y-1][1];
  end
  // Right column padding (reflect from the second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y ==              0) border_reflect_frame[0][FRAME_WIDTH+1]              <= internal_frame[1][FRAME_WIDTH-2];              else 
    if (padd_y == FRAME_HEIGHT+1) border_reflect_frame[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= internal_frame[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else  
                                  border_reflect_frame[padd_y][FRAME_WIDTH+1]         <= internal_frame[padd_y-1][FRAME_WIDTH-2];
  end
end

// Position tracking - X axis of the frame - CAPTURE
always @(posedge clk or negedge rst_n)
if (~rst_n)                 x_pos <= 'd0; else
if (pix_val) begin
    if (pix_eof || pix_eol) x_pos <= 'd0; else
                            x_pos <= x_pos + 'd1;
end

// Position tracking - Y axis of the frame - CAPTURE
always @(posedge clk or negedge rst_n)
if (~rst_n)    y_pos <= 'd0;         else
if (pix_val) begin
  if (pix_sof) y_pos <= 'd0;         else
  if (pix_eof) y_pos <= 'd0;         else
  if (pix_eol) y_pos <= y_pos + 'd1; 
end 

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

// State machine logic
always @(posedge clk or negedge rst_n) 
if (~rst_n) state <= IDLE; else
case (state)
  IDLE   : if (pix_sof)                                                        state <= CAPTURE;
  CAPTURE: if (pix_eof || (x_pos == FRAME_WIDTH-1 && y_pos == FRAME_HEIGHT-1)) state <= PADDING;
  PADDING: if (padd_x == FRAME_WIDTH+1 && padd_y == FRAME_HEIGHT+1)            state <= PROCESS;
  PROCESS: if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1)            state <= IDLE   ;
  default:                                                                     state <= IDLE   ;
endcase

// Calculate 3*3 window sum on border_reflect_frame
assign window_sum = 
    ((state == PROCESS) ? 
    // Top row [1 2 1]
    (border_reflect_frame[proc_y][proc_x] + (border_reflect_frame[proc_y][proc_x+1] << 1) + border_reflect_frame[proc_y][proc_x+2]) +
    // Middle row [2 4 2]
    ((border_reflect_frame[proc_y+1][proc_x] << 1) + (border_reflect_frame[proc_y+1][proc_x+1] << 2) + (border_reflect_frame[proc_y+1][proc_x+2] << 1)) +
    // Bottom row [1 2 1]
    (border_reflect_frame[proc_y+2][proc_x] + (border_reflect_frame[proc_y+2][proc_x+1] << 1) + border_reflect_frame[proc_y+2][proc_x+2]) : 0); // Default value when out of bounds

// Calculate final gaussian pixel based on the window sum (with rounding)
always @(posedge clk or negedge rst_n)
if (~rst_n)           gauss_data[proc_y][proc_x] <= 'd0; else
if (state == PROCESS) gauss_data[proc_y][proc_x] <= (window_sum + 8) >> 4; 

// Gaussian valid signal
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                  gauss_val <= 1'b0; else
if (state == PROCESS && proc_y == FRAME_HEIGHT-1 && proc_x == FRAME_WIDTH-1) gauss_val <= 1'b1; else
if (state == IDLE)                                                           gauss_val <= 1'b0;

endmodule