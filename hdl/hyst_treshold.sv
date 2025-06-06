//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : hyst_threshold.sv 
// Author      : Mihaela - Georgiana Berciu
// Date        : 17.02.2025
// Description : Hysteresis Threshold for Canny Edge Detection - Edge Tracking
//---------------------------------------------------------------------

module hyst_threshold#(
  FRAME_WIDTH  = 640,     // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,     // frame height parameter  -default VGA res
  PIX_WIDTH    = 24       // 8 bits for pixels after grayscale conversion
)(
  input                          clk       ,                                     // clock
  input                          rst_n     ,                                     // reset, asynchronous low
  // input frame interface 
  input                          dual_val  ,                                     // dual threshold valid
  input      [(PIX_WIDTH/3)-1:0] str_edge  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // strong edges input frame
  input      [(PIX_WIDTH/3)-1:0] weak_edge [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // weak edges input frame
  // output frame interface
  output reg                     hyst_val  ,                                     // hysteresis valid
  output reg [(PIX_WIDTH/3)-1:0] final_edge[FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]   // final edges output frame
);

// State machine parameters
localparam IDLE    = 2'd0;
localparam PADDING = 2'd1;
localparam PROCESS = 2'd2;

// State register
reg [1:0] state;       

// Internal frame buffers with padding
reg [(PIX_WIDTH/3)-1:0] padded_str  [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0];  // Strong edges frame with padding
reg [(PIX_WIDTH/3)-1:0] padded_weak [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0];  // Weak edges frame with padding

// Position counters
reg [$clog2(FRAME_WIDTH )+1:0] padd_x;   // Padding x position
reg [$clog2(FRAME_HEIGHT)+1:0] padd_y;   // Padding y position
reg [$clog2(FRAME_WIDTH )-1:0] proc_x;   // Processing x position
reg [$clog2(FRAME_HEIGHT)-1:0] proc_y;   // Processing y position

// Wire to check if any neighbor is a strong edge
wire has_strong_neighbor;
// Wire to count strong neighbors
wire [3:0] strong_count;

// Border reflection padding for strong edges
always @(posedge clk or negedge rst_n)
if (~rst_n) padded_str[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from str_edge to padded_str with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) 
    padded_str[padd_y][padd_x] <= str_edge[padd_y-1][padd_x-1];
  
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if (padd_x ==             0) padded_str[0][0]             <= str_edge[1][1];             else 
    if (padd_x == FRAME_WIDTH+1) padded_str[0][FRAME_WIDTH+1] <= str_edge[1][FRAME_WIDTH-2]; else  
                                 padded_str[0][padd_x]        <= str_edge[1][padd_x-1];
  end
  
  // Bottom row padding (reflect from second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if (padd_x ==             0) padded_str[FRAME_HEIGHT+1][0]             <= str_edge[FRAME_HEIGHT-2][1];             else 
    if (padd_x == FRAME_WIDTH+1) padded_str[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= str_edge[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                 padded_str[FRAME_HEIGHT+1][padd_x]        <= str_edge[FRAME_HEIGHT-2][padd_x-1];
  end
  
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y ==              0) padded_str[0][0]              <= str_edge[1][1];              else 
    if (padd_y == FRAME_HEIGHT+1) padded_str[FRAME_HEIGHT+1][0] <= str_edge[FRAME_HEIGHT-2][1]; else  
                                  padded_str[padd_y][0]         <= str_edge[padd_y-1][1];
  end
  
  // Right column padding (reflect from second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y ==              0) padded_str[0][FRAME_WIDTH+1]              <= str_edge[1][FRAME_WIDTH-2];              else 
    if (padd_y == FRAME_HEIGHT+1) padded_str[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= str_edge[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else  
                                  padded_str[padd_y][FRAME_WIDTH+1]         <= str_edge[padd_y-1][FRAME_WIDTH-2];
  end
end

// Border reflection padding for weak edges
always @(posedge clk or negedge rst_n)
if (~rst_n) padded_weak[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from weak_edge to padded_weak with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) 
    padded_weak[padd_y][padd_x] <= weak_edge[padd_y-1][padd_x-1];
  
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if (padd_x ==             0) padded_weak[0][0]             <= weak_edge[1][1];             else 
    if (padd_x == FRAME_WIDTH+1) padded_weak[0][FRAME_WIDTH+1] <= weak_edge[1][FRAME_WIDTH-2]; else  
                                 padded_weak[0][padd_x]        <= weak_edge[1][padd_x-1];
  end
  
  // Bottom row padding (reflect from second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if (padd_x ==             0) padded_weak[FRAME_HEIGHT+1][0]             <= weak_edge[FRAME_HEIGHT-2][1];             else 
    if (padd_x == FRAME_WIDTH+1) padded_weak[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= weak_edge[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                 padded_weak[FRAME_HEIGHT+1][padd_x]        <= weak_edge[FRAME_HEIGHT-2][padd_x-1];
  end
  
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y ==              0) padded_weak[0][0]              <= weak_edge[1][1];              else 
    if (padd_y == FRAME_HEIGHT+1) padded_weak[FRAME_HEIGHT+1][0] <= weak_edge[FRAME_HEIGHT-2][1]; else  
                                  padded_weak[padd_y][0]         <= weak_edge[padd_y-1][1];
  end
  
  // Right column padding (reflect from second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y ==              0) padded_weak[0][FRAME_WIDTH+1]              <= weak_edge[1][FRAME_WIDTH-2];              else 
    if (padd_y == FRAME_HEIGHT+1) padded_weak[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= weak_edge[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else  
                                  padded_weak[padd_y][FRAME_WIDTH+1]         <= weak_edge[padd_y-1][FRAME_WIDTH-2];
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

// State machine logic
always @(posedge clk or negedge rst_n) 
if (~rst_n) state <= IDLE; else
case (state)
  IDLE   : if (dual_val)                                             state <= PADDING;
  PADDING: if (padd_x == FRAME_WIDTH+1 && padd_y == FRAME_HEIGHT+1) state <= PROCESS;
  PROCESS: if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1) state <= IDLE   ;
  default:                                                          state <= IDLE   ;
endcase

// Check if any 8-connected neighbor is a strong edge
assign has_strong_neighbor = (state == PROCESS) ? (
    // Check all 8 neighbors for strong edges (value of 255)
    (padded_str[proc_y][proc_x]     == 8'd255) || // Top-left
    (padded_str[proc_y][proc_x+1]   == 8'd255) || // Top
    (padded_str[proc_y][proc_x+2]   == 8'd255) || // Top-right
    (padded_str[proc_y+1][proc_x]   == 8'd255) || // Left
    // Current pixel is at [proc_y+1][proc_x+1]
    (padded_str[proc_y+1][proc_x+2] == 8'd255) || // Right
    (padded_str[proc_y+2][proc_x]   == 8'd255) || // Bottom-left
    (padded_str[proc_y+2][proc_x+1] == 8'd255) || // Bottom
    (padded_str[proc_y+2][proc_x+2] == 8'd255)    // Bottom-right
) : 1'b0;

// Count the number of strong neighbors
assign strong_count = (state == PROCESS) ? (
    ((padded_str[proc_y][proc_x]     == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y][proc_x+1]   == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y][proc_x+2]   == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y+1][proc_x]   == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y+1][proc_x+2] == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y+2][proc_x]   == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y+2][proc_x+1] == 8'd255) ? 4'd1 : 4'd0) +
    ((padded_str[proc_y+2][proc_x+2] == 8'd255) ? 4'd1 : 4'd0)
) : 4'd0;

// Final edge detection output
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                               final_edge[proc_y][proc_x] <= 'd0; else
if (state == PROCESS) begin
   if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1)               final_edge[proc_y][proc_x] <= 'd0; else
   if (padded_str[proc_y+1][proc_x+1] == 8'd255)                          final_edge[proc_y][proc_x] <= 8'd255; else
   // For weak edges, require at least two strong neighbors
   if (padded_weak[proc_y+1][proc_x+1] == 8'd128 && strong_count >= 4'd2) final_edge[proc_y][proc_x] <= 8'd255; else
                                                                          final_edge[proc_y][proc_x] <= 8'd0;
end

// Hysteresis valid signal
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                  hyst_val <= 1'b0; else
if (state == PROCESS && proc_y == FRAME_HEIGHT-1 && proc_x == FRAME_WIDTH-1) hyst_val <= 1'b1; else
if (state == IDLE)                                                           hyst_val <= 1'b0;

endmodule