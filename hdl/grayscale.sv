//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : grayscale.svh
// Author      : Mihaela - Georgiana Berciu
// Date        : 05.02.2025
// Description : Conversion from RGB colorspace to Grayscale 
//---------------------------------------------------------------------

module grayscale#(
  FRAME_WIDTH  = 640,     // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480,     // frame height parameter  -default VGA res
  PIX_WIDTH    =  24      // 8 bits for red[23:16], green[15:8], blue[7:0]
)(
  input                          clk      , // clock
  input                          rst_n    , // reset, asynchronous low
  // input frame interface
  input                          pix_val  , // pixel valid
  input                          pix_sof  , // pixel start of frame
  input                          pix_eof  , // pixel end of frame
  input                          pix_sol  , // pixel start of line
  input                          pix_eol  , // pixel end of line
  input      [ PIX_WIDTH   -1:0] pix_data , // pixel rgb value, red[23:16], green[15:8], blue[7:0]
  // output frame interface
  output reg                     gray_val , // grayscale valid
  output reg                     gray_sof , // grayscale start of frame
  output reg                     gray_eof , // grayscale end of frame
  output reg                     gray_sol , // grayscale start of line
  output reg                     gray_eol , // grayscale end of line
  output reg [(PIX_WIDTH/3)-1:0] gray_data  // grayscale output pixel - 8 bits
);

// internal declarations
wire [7:0] pix_red  ;  // input red value of pixel
wire [7:0] pix_blue ;  // input green value of pixel
wire [7:0] pix_green;  // input blue value of pixel

// weighted color channels calculated by the RGB2Gray NTSC formula
wire [18:0] weighted_red  ; 
wire [18:0] weighted_green;
wire [18:0] weighted_blue ;
wire [18:0] weighted_sum  ;

// position counters
reg [$clog2(FRAME_WIDTH )-1:0] x_pos;
reg [$clog2(FRAME_HEIGHT)-1:0] y_pos;

// first pixel detection
reg first_pixel;

// delayed control signals
reg pix_val_d;
reg pix_sof_d;
reg pix_eof_d;
reg pix_sol_d;
reg pix_eol_d;
reg first_pixel_d;

// split values of pix_data into red, green and blue values
assign pix_red   = pix_data[23:16];
assign pix_green = pix_data[15: 8];
assign pix_blue  = pix_data[ 7: 0];

// weighted values of each color using 2048-based coefficients:
assign weighted_red   = (pix_red   << 9) + (pix_red   << 6) + (pix_red   << 5) + (pix_red   << 2) + pix_red;                        // Red weight   = 613/2048  = 0.299316406 (vs 0.299) : 613 = 512 + 64 + 32 + 4 + 1     = 2^9 + 2^6 + 2^5 + 2^2 + 2^0
assign weighted_green = (pix_green << 10) + (pix_green << 7) + (pix_green << 5) + (pix_green << 4) + (pix_green << 1) + pix_green;  // Green weight = 1203/2048 = 0.587402344 (vs 0.587) : 1203 = 1024 + 128 + 32 + 16 + 2 + 1 = 2^10 + 2^7 + 2^5 + 2^4 + 2^1 + 2^0
assign weighted_blue  = (pix_blue  << 7) + (pix_blue  << 6) + (pix_blue  << 5) + (pix_blue  << 3) + (pix_blue  << 1);               // Blue weight  = 234/2048  = 0.114257813 (vs 0.114) : 234 = 128 + 64 + 32 + 8 + 2     = 2^7 + 2^6 + 2^5 + 2^3 + 2^1

// grayscale pixel = 0.299 x Red + 0.587 x Green + 0.114 x Blue
// weighted sum =  (613*red + 1203*green + 234*blue)
assign weighted_sum = weighted_red + weighted_green + weighted_blue;

// First pixel detection
always @(posedge clk or negedge rst_n)
if (~rst_n)             first_pixel <= 1'b1; else
if (pix_val && pix_sof) first_pixel <= 1'b0;

// Delay first_pixel
always @(posedge clk or negedge rst_n)
if (~rst_n) first_pixel_d <= 1'b1; else
            first_pixel_d <= first_pixel;

// Position tracking - x axis of the frame
always @(posedge clk or negedge rst_n)
if (~rst_n)    x_pos <= 'd0;        else
if (pix_val) begin
  if (pix_sof) x_pos <= 'd0;        else
  if (pix_sol) x_pos <= 'd0;        else
  if (pix_eol) x_pos <= 'd0;        else
  if (pix_eof) x_pos <= 'd0;        else
               x_pos <= x_pos + 'd1;
end

// Position tracking - y axis of the frame
always @(posedge clk or negedge rst_n)
if (~rst_n)    y_pos <= 'd0;         else
if (pix_val) begin
  if (pix_sof) y_pos <= 'd0;         else
  if (pix_sol) y_pos <= y_pos + 'd1; else
  if (pix_eof) y_pos <= 'd0;
end 

// Delay pix_val 
always @(posedge clk or negedge rst_n)
if (~rst_n) pix_val_d <= 'd0; else
            pix_val_d <= pix_val;

// Delay pix_sof
always @(posedge clk or negedge rst_n)
if (~rst_n) pix_sof_d <= 'd0; else
            pix_sof_d <= pix_sof;

// Delay pix_eof
always @(posedge clk or negedge rst_n)
if (~rst_n) pix_eof_d <= 'd0; else
            pix_eof_d <= pix_eof;

// Delay pix_sol
always @(posedge clk or negedge rst_n)
if (~rst_n) pix_sol_d <= 'd0; else
            pix_sol_d <= pix_sol;

// Delay pix_eol
always @(posedge clk or negedge rst_n)
if (~rst_n) pix_eol_d <= 'd0; else
            pix_eol_d <= pix_eol;

// output frame valid
always @(posedge clk or negedge rst_n)
if (~rst_n) gray_val <= 'd0; else
            gray_val <= pix_val_d;

// output frame start of frame 
always @(posedge clk or negedge rst_n)
if (~rst_n)                                  gray_sof <= 1'd0; else
if (pix_val_d && pix_sof_d && first_pixel_d) gray_sof <= 1'b1; else
                                             gray_sof <= 1'b0;

// output frame end of frame
always @(posedge clk or negedge rst_n)
if (~rst_n) gray_eof <= 'd0; else
            gray_eof <= pix_eof_d;

// output frame start of line
always @(posedge clk or negedge rst_n)
if (~rst_n) gray_sol <= 'd0; else
            gray_sol <= pix_sol_d;

// output frame end of line
always @(posedge clk or negedge rst_n)
if (~rst_n) gray_eol <= 'd0; else
            gray_eol <= pix_eol_d;

// output frame gray pixel value
always @(posedge clk or negedge rst_n)
if (~rst_n ) gray_data <= 'd0;       else
if (pix_val) gray_data <= weighted_sum[18:11];

endmodule