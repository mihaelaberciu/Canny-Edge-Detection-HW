//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : nonmax_suppress.sv
// Author      : Mihaela - Georgiana Berciu
// Date        : 17.02.2025
// Description : Non-maximum Suppression based on Sobel magnitude and direction
//---------------------------------------------------------------------

module nonmax_suppress#(
  FRAME_WIDTH  = 640,     // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,     // frame height parameter  -default VGA res
  PIX_WIDTH    = 24       // 8 bits for pixels after grayscale conversion
)(
  input                          clk       ,                                     // clock
  input                          rst_n     ,                                     // reset, asynchronous low
  // input frame interface 
  input                          edge_val  ,                                     // sobel edge frame valid
  input      [(PIX_WIDTH/3)-1:0] edge_mag  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // sobel output frame of gradients magnitude
  input      [1:0]               edge_dir  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0],  // sobel output frame of gradients directions
  // output frame interface
  output reg                     thin_val  ,                                     // thin edge valid
  output reg [(PIX_WIDTH/3)-1:0] thin_edge [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]   // thin edge output frame
);

// State machine parameters
localparam IDLE    = 2'd0;
localparam PADDING = 2'd1;
localparam PROCESS = 2'd2;

reg [1:0] state;       // State register

// Direction definitions
localparam DIR_0   = 2'b00;  // 0°   horizontal - compare east/west
localparam DIR_45  = 2'b01;  // 45°  diagonal   - compare northeast/southwest
localparam DIR_90  = 2'b10;  // 90°  vertical   - compare north/south
localparam DIR_135 = 2'b11;  // 135° diagonal   - compare northwest/southeast

// Internal frame buffer with padding
reg [(PIX_WIDTH/3)-1:0] padded_mag [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0];  // Magnitude frame with border reflection padding
reg [1:0]               padded_dir [FRAME_HEIGHT+1:0][FRAME_WIDTH+1:0];  // Direction frame with border reflection padding

// Position counters
reg [$clog2(FRAME_WIDTH )+1:0] padd_x;   // Padding x position
reg [$clog2(FRAME_HEIGHT)+1:0] padd_y;   // Padding y position
reg [$clog2(FRAME_WIDTH )-1:0] proc_x;   // Processing x position
reg [$clog2(FRAME_HEIGHT)-1:0] proc_y;   // Processing y position

// Neighbor magnitude wires based on direction
wire [(PIX_WIDTH/3)-1:0] neighbor1;  // First neighbor in gradient direction
wire [(PIX_WIDTH/3)-1:0] neighbor2;  // Second neighbor in gradient direction

// Border reflection padding for magnitude frame
always @(posedge clk or negedge rst_n)
if (~rst_n) padded_mag[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from edge_mag to padded_mag with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) padded_mag[padd_y][padd_x] <= edge_mag[padd_y-1][padd_x-1]; else
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if      (padd_x == 0)              padded_mag[0][0]                           <= edge_mag[1][1];             else
    if      (padd_x == FRAME_WIDTH+1)  padded_mag[0][FRAME_WIDTH+1]               <= edge_mag[1][FRAME_WIDTH-2]; else
                                       padded_mag[0][padd_x]                      <= edge_mag[1][padd_x-1];
  end else
  // Bottom row padding (reflect from second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if      (padd_x == 0)              padded_mag[FRAME_HEIGHT+1][0]              <= edge_mag[FRAME_HEIGHT-2][1];             else
    if      (padd_x == FRAME_WIDTH+1)  padded_mag[FRAME_HEIGHT+1][FRAME_WIDTH+1]  <= edge_mag[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                       padded_mag[FRAME_HEIGHT+1][padd_x]         <= edge_mag[FRAME_HEIGHT-2][padd_x-1];
  end else
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y == 0)              padded_mag[0][0]                                <= edge_mag[1][1];              else
    if (padd_y == FRAME_HEIGHT+1) padded_mag[FRAME_HEIGHT+1][0]                   <= edge_mag[FRAME_HEIGHT-2][1]; else
                                  padded_mag[padd_y][0]                           <= edge_mag[padd_y-1][1];
  end else
  // Right column padding (reflect from second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y == 0)              padded_mag[0][FRAME_WIDTH+1]                    <= edge_mag[1][FRAME_WIDTH-2];              else
    if (padd_y == FRAME_HEIGHT+1) padded_mag[FRAME_HEIGHT+1][FRAME_WIDTH+1]       <= edge_mag[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                  padded_mag[padd_y][FRAME_WIDTH+1]               <= edge_mag[padd_y-1][FRAME_WIDTH-2];
  end
end

// Border reflection padding for direction frame
always @(posedge clk or negedge rst_n)
if (~rst_n) padded_dir[padd_y][padd_x] <= 'd0; else 
if (state == PADDING) begin
  // Copy pixels from edge_dir to padded_dir with an offset of +1 in both dimensions
  if ((padd_y >= 1 && padd_y <= FRAME_HEIGHT) && (padd_x >= 1 && padd_x <= FRAME_WIDTH)) padded_dir[padd_y][padd_x] <= edge_dir[padd_y-1][padd_x-1]; else
  // Top row padding (reflect from row 2)
  if (padd_y == 0) begin
    if (padd_x == 0)              padded_dir[0][0]                          <= edge_dir[1][1];             else
    if (padd_x == FRAME_WIDTH+1)  padded_dir[0][FRAME_WIDTH+1]              <= edge_dir[1][FRAME_WIDTH-2]; else
                                  padded_dir[0][padd_x]                     <= edge_dir[1][padd_x-1];
  end else
  // Bottom row padding (reflect from second last row)
  if (padd_y == FRAME_HEIGHT+1) begin
    if (padd_x == 0)              padded_dir[FRAME_HEIGHT+1][0]             <= edge_dir[FRAME_HEIGHT-2][1];             else
    if (padd_x == FRAME_WIDTH+1)  padded_dir[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= edge_dir[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                  padded_dir[FRAME_HEIGHT+1][padd_x]        <= edge_dir[FRAME_HEIGHT-2][padd_x-1];
  end else
  // Left column padding (reflect from column 2)
  if (padd_x == 0) begin
    if (padd_y == 0)              padded_dir[0][0]                          <= edge_dir[1][1];              else
    if (padd_y == FRAME_HEIGHT+1) padded_dir[FRAME_HEIGHT+1][0]             <= edge_dir[FRAME_HEIGHT-2][1]; else
                                  padded_dir[padd_y][0]                     <= edge_dir[padd_y-1][1];
  end else
  // Right column padding (reflect from second last column)
  if (padd_x == FRAME_WIDTH+1) begin
    if (padd_y == 0)              padded_dir[0][FRAME_WIDTH+1]              <= edge_dir[1][FRAME_WIDTH-2];              else
    if (padd_y == FRAME_HEIGHT+1) padded_dir[FRAME_HEIGHT+1][FRAME_WIDTH+1] <= edge_dir[FRAME_HEIGHT-2][FRAME_WIDTH-2]; else
                                  padded_dir[padd_y][FRAME_WIDTH+1]         <= edge_dir[padd_y-1][FRAME_WIDTH-2];
  end
end

// Padding tracking - X axis of the frame - PADDING 
always @(posedge clk or negedge rst_n) 
if (~rst_n) padd_x <= 'd0; else 
if (state == PADDING) begin
    if (padd_x == FRAME_WIDTH+1) padd_x <= 'd0;          else 
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
if (~rst_n)                      proc_x <= 'd0;         else 
if (state == PROCESS) begin 
    if (proc_x == FRAME_WIDTH-1) proc_x <= 'd0;         else 
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

// Assign neighbors based on gradient direction
assign neighbor1 = ((state == PROCESS) ? ((padded_dir[proc_y+1][proc_x+1] == DIR_0 ) ? padded_mag[proc_y+1][proc_x+2]  :     // east  - horizontal edge
                                          (padded_dir[proc_y+1][proc_x+1] == DIR_90) ? padded_mag[proc_y+2][proc_x+1]  :     // south - vertical edge
                                          (padded_dir[proc_y+1][proc_x+1] == DIR_45) ? padded_mag[proc_y+2][proc_x+2]  :     // southeast - 45° diagonal
                                                                                       padded_mag[proc_y+2][proc_x  ]) : 0);  // southwest - 135° diagonal

assign neighbor2 = ((state == PROCESS) ? ((padded_dir[proc_y+1][proc_x+1] == DIR_0)  ? padded_mag[proc_y+1][proc_x  ]  :     // west  - horizontal edge 
                                          (padded_dir[proc_y+1][proc_x+1] == DIR_90) ? padded_mag[proc_y  ][proc_x+1]  :     // north - vertical edge
                                          (padded_dir[proc_y+1][proc_x+1] == DIR_45) ? padded_mag[proc_y  ][proc_x  ]  :     // northwest - 45° diagonal
                                                                                       padded_mag[proc_y  ][proc_x+2]) : 0);  // northeast - 135° diagonal

// State machine logic
always @(posedge clk or negedge rst_n) 
if (~rst_n) state <= IDLE; else
case (state)
  IDLE   : if (edge_val)                                            state <= PADDING;
  PADDING: if (padd_x == FRAME_WIDTH+1 && padd_y == FRAME_HEIGHT+1) state <= PROCESS;
  PROCESS: if (proc_x == FRAME_WIDTH-1 && proc_y == FRAME_HEIGHT-1) state <= IDLE   ;
  default:                                                          state <= IDLE   ;
endcase

// Non-maximum suppression output
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                                        thin_edge[proc_y][proc_x] <= 'd0;                            else
if (state == PROCESS) 
   if (proc_x == 0 || proc_y == 0 || proc_x == FRAME_WIDTH-1 || proc_y == FRAME_HEIGHT-1)          thin_edge[proc_y][proc_x] <= 'd0;                            else 
   if (padded_mag[proc_y+1][proc_x+1] >= neighbor1 && padded_mag[proc_y+1][proc_x+1] >= neighbor2) thin_edge[proc_y][proc_x] <= padded_mag[proc_y+1][proc_x+1]; else
                                                                                                   thin_edge[proc_y][proc_x] <= 'd0;

// Thin edge valid signal
always @(posedge clk or negedge rst_n)
if (~rst_n)                                                                  thin_val <= 1'b0; else
if (state == PROCESS && proc_y == FRAME_HEIGHT-1 && proc_x == FRAME_WIDTH-1) thin_val <= 1'b1; else
if (state == IDLE)                                                           thin_val <= 1'b0;

endmodule