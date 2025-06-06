//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : sobel_edge.sv
// Author      : Mihaela - Georgiana Berciu
// Date        : 13.02.2025
// Description : Sobel Edge Detection on Gaussian blurred image
//---------------------------------------------------------------------

module sobel_edge#(
  FRAME_WIDTH  = 640,     // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,     // frame height parameter  -default VGA res
  PIX_WIDTH    = 24      // 8 bits for red[23:16], green[15:8], blue[7:0]
)(
  input                          clk       ,                                      // clock
  input                          rst_n     ,                                      // reset, asynchronous low
  // input frame interface 
  input                          gauss_val ,                                      // gaussian frame valid
  input      [(PIX_WIDTH/3)-1:0] gauss_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // gaussian frame
  // output frame interface
  output reg                     sobel_val ,                                      // sobel valid
  output reg [(PIX_WIDTH/3)-1:0] sobel_dir  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // sobel output frame of gradients directions (angle)
  output reg [(PIX_WIDTH/3)-1:0] sobel_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]   // sobel output frame of gradients magnitude (euclidian formula obtained)
);

// State machine parameters
localparam IDLE    = 2'd0;
localparam PADDING = 2'd1;
localparam PROCESS = 2'd2;
// // Direction definitions
localparam DIR_0   = 2'b00;  // 0°   horizontal
localparam DIR_45  = 2'b01;  // 45°  diagonal
localparam DIR_90  = 2'b10;  // 90°  vertical
localparam DIR_135 = 2'b11;  // 135° diagonal

reg [1:0] state;       // State register

// Internal frame buffer with padding
reg [(PIX_WIDTH/3)-1:0] border_reflect_frame [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0];    // Frame with border reflection padding

// Position counters
reg [$clog2(FRAME_WIDTH )+1:0] padd_x;   // Padding x position
reg [$clog2(FRAME_HEIGHT)+1:0] padd_y;   // Padding y position
reg [$clog2(FRAME_WIDTH )-1:0] proc_x;   // Processing x position
reg [$clog2(FRAME_HEIGHT)-1:0] proc_y;   // Processing y position

// Gradient calculation wires (need extra bits for signed math)
wire [15:0] gx;         // Horizontal gradient
wire [15:0] gy;         // Vertical gradient
wire [15:0] magnitude;  // Gradient magnitude

wire [15:0] abs_gx;
wire [15:0] abs_gy;
wire        gy_gt_2_5_gx;
wire        gy_lt_0_4_gx;
wire [ 1:0] angle;

// Border reflection padding
always @(posedge clk or negedge rst_n)
if (~rst_n) border_reflect_frame[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from gauss_data to border_reflect_frame with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) 
    border_reflect_frame[padd_y][padd_x] <= gauss_data[padd_y-1][padd_x-1];
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if (padd_x ==             0) border_reflect_frame[0][0]             <= gauss_data[1][1];             else 
    if (padd_x == FRAME_WIDTH+1) border_reflect_frame[0][FRAME_WIDTH+1] <= gauss_data[1][FRAME_WIDTH-2]; else  
                                 border_reflect_frame[0][padd_x]        <= gauss_data[1][padd_x-1];
  end
  // Bottom row padding (reflect from second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if (padd_x ==             0) border_reflect_frame[FRAME_HEIGHT+1][0]             <= gauss_data[FRAME_HEIGHT-2][1];             else 
    if (padd_x == FRAME_WIDTH+1) border_reflect_frame[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= gauss_data[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                 border_reflect_frame[FRAME_HEIGHT+1][padd_x]        <= gauss_data[FRAME_HEIGHT-2][padd_x-1];
  end
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y ==              0) border_reflect_frame[0][0]              <= gauss_data[1][1];              else 
    if (padd_y == FRAME_HEIGHT+1) border_reflect_frame[FRAME_HEIGHT+1][0] <= gauss_data[FRAME_HEIGHT-2][1]; else  
                                  border_reflect_frame[padd_y][0]         <= gauss_data[padd_y-1][1];
  end
  // Right column padding (reflect from second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y ==              0) border_reflect_frame[0][FRAME_WIDTH+1]              <= gauss_data[1][FRAME_WIDTH-2];              else 
    if (padd_y == FRAME_HEIGHT+1) border_reflect_frame[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= gauss_data[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else  
                                  border_reflect_frame[padd_y][FRAME_WIDTH+1]         <= gauss_data[padd_y-1][FRAME_WIDTH-2];
  end
end

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

// Horizontal gradient Gx = [-1 0 1; -2 0 2; -1 0 1]
assign gx = ((state == PROCESS) ? (((border_reflect_frame[proc_y  ][proc_x+2])       -  border_reflect_frame[proc_y  ][proc_x])       +      // Top row
                                  (((border_reflect_frame[proc_y+1][proc_x+2] << 1)) - (border_reflect_frame[proc_y+1][proc_x] << 1)) +      // Middle row
                                   ((border_reflect_frame[proc_y+2][proc_x+2])       -  border_reflect_frame[proc_y+2][proc_x]))       : 0); // Bottom row


// Vertical gradient Gy = [-1 -2 -1; 0 0 0; 1 2 1]
assign gy = ((state == PROCESS) ? ((border_reflect_frame[proc_y+2][proc_x]) + (border_reflect_frame[proc_y+2][proc_x+1] << 1) + (border_reflect_frame[proc_y+2][proc_x+2]) -      // Bottom row
                                   (border_reflect_frame[proc_y  ][proc_x]) - (border_reflect_frame[proc_y  ][proc_x+1] << 1) - (border_reflect_frame[proc_y  ][proc_x+2])) : 0); // Top row

// Calculate gradient magnitude using absolute values
assign abs_gx = (gx[15] == 1'b1) ? (~gx + 1) : gx;  // 2's complement conversion
assign abs_gy = (gy[15] == 1'b1) ? (~gy + 1) : gy;

// assign magnitude = (abs_gx > abs_gy) ? (abs_gx + (abs_gy >> 1)) : (abs_gy + (abs_gx >> 1)); // euclidian formula adapted
assign magnitude = (abs_gx + abs_gy) >> 1; 

// State machine logic
always @(posedge clk or negedge rst_n) 
if (~rst_n) state <= IDLE; else
case (state)
  IDLE   : if (gauss_val)                                           state <= PADDING;
  PADDING: if (padd_x == FRAME_WIDTH+1 && padd_y == FRAME_HEIGHT+1) state <= PROCESS;
  PROCESS: if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1) state <= IDLE   ;
  default:                                                          state <= IDLE   ;
endcase

// Approximate angle calculations using shifts instead of multiplications
assign gy_gt_gx = (abs_gy > abs_gx);  // Vertical (90°)
assign gy_gt_3_8_gx = (abs_gy > (abs_gx - (abs_gx >> 2)));  // ≈ 3/8 * abs_gx
assign gy_lt_3_8_gx = (abs_gy < (abs_gx - (abs_gx >> 2)));  // ≈ 3/8 * abs_gx

// Determine gradient direction based on thresholds
assign angle = (abs_gx == 0 && abs_gy == 0) ? DIR_0 : // No gradient
               (gy_gt_gx) ? DIR_90 :  // Vertical
               (gy_lt_3_8_gx) ? DIR_0 :  // Horizontal
               ((gx[15] == gy[15]) ? DIR_45 : DIR_135); // Diagonal 45° or 135°

// Store angle in sobel_dir array
always @(posedge clk or negedge rst_n)
if (~rst_n)           sobel_dir[proc_y][proc_x] <= 'd0; else 
if (state == PROCESS) sobel_dir[proc_y][proc_x] <= angle;

// Output sobel edge detection result
always @(posedge clk or negedge rst_n)
if (~rst_n)           sobel_data[proc_y][proc_x] <= 'd0;                                     else
if (state == PROCESS) sobel_data[proc_y][proc_x] <= (magnitude > 255) ? 255 : magnitude[7:0];

// Sobel valid signal
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                  sobel_val <= 1'b0; else
if (state == PROCESS && proc_y == FRAME_HEIGHT-1 && proc_x == FRAME_WIDTH-1) sobel_val <= 1'b1; else
if (state == IDLE)                                                           sobel_val <= 1'b0;

endmodule