//---------------------------------------------------------------------
// Project     : Dizertatie - HW Canny Edge Detection
// File        : canny.sv
// Author      : Mihaela - Georgiana Berciu
// Date        : 17.02.2025
// Description : Canny Edge Detection Module  
//---------------------------------------------------------------------

module canny#(
  FRAME_WIDTH  = 640, // frame width parameter   -default VGA res
  FRAME_HEIGHT = 480, // frame height parameter  -default VGA res
  PIX_WIDTH    =  24, // 8 bits for red[23:16], green[15:8], blue[7:0] ; 8 bits for pixels after grayscale conversion
  HIGH_THRESH  = 100, // High threshold value
  LOW_THRESH   =  50  // Low threshold value
)(
  input                          clk        ,                                    // clock
  input                          rst_n      ,                                    // reset, asynchronous low
  // input frame interface
  input                          pix_val    ,                                    // pixel valid
  input                          pix_sof    ,                                    // pixel start of frame
  input                          pix_eof    ,                                    // pixel end of frame
  input                          pix_sol    ,                                    // pixel start of line
  input                          pix_eol    ,                                    // pixel end of line
  input      [ PIX_WIDTH   -1:0] pix_data   ,                                    // pixel rgb value, red[23:16], green[15:8], blue[7:0]
  // output frame interface
  output reg                     canny_val  ,                                    // canny frame valid
  output reg [(PIX_WIDTH/3)-1:0] canny_data  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0] // canny frame
);

// Grayscale interface
logic                     gray_val  ;
logic                     gray_sof  ;
logic                     gray_eof  ;
logic                     gray_sol  ;
logic                     gray_eol  ;
logic [(PIX_WIDTH/3)-1:0] gray_data ;

// Gaussian blur frame interface
logic                     gauss_val ;
logic [(PIX_WIDTH/3)-1:0] gauss_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

// Sobel edge interface
logic                     sobel_val ;
logic [(PIX_WIDTH/3)-1:0] sobel_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];
logic [              1:0] sobel_dir  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

// Non-maximum suppression interface
logic                     nms_val  ;
logic [(PIX_WIDTH/3)-1:0] nms_data  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

// Double threshold interface
logic                     dual_val ;
logic [(PIX_WIDTH/3)-1:0] str_edge  [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];
logic [(PIX_WIDTH/3)-1:0] weak_edge [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

grayscale#(
  .FRAME_WIDTH (FRAME_WIDTH ),     // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT),     // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   )      // 8 bits for red[23:16], green[15:8], blue[7:0]
) i_gray (
  .clk      (clk      ), // clock
  .rst_n    (rst_n    ), // reset, asynchronous low
  .pix_val  (pix_val  ), // pixel valid
  .pix_sof  (pix_sof  ), // pixel start of frame
  .pix_eof  (pix_eof  ), // pixel end of frame
  .pix_sol  (pix_sol  ), // pixel start of line
  .pix_eol  (pix_eol  ), // pixel end of line
  .pix_data (pix_data ), // pixel rgb value, red[23:16], green[15:8], blue[7:0]
  .gray_val (gray_val ), // grayscale valid
  .gray_sof (gray_sof ), // grayscale start of frame
  .gray_eof (gray_eof ), // grayscale end of frame
  .gray_sol (gray_sol ), // grayscale start of line
  .gray_eol (gray_eol ), // grayscale end of line
  .gray_data(gray_data)  // grayscale output pixel - 8 bits
);

gaussian_blur#(
  .FRAME_WIDTH (FRAME_WIDTH ),    // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT),    // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   )     // 8 bits only after grayscale conversion
) i_gaussian_blur (
  .clk       (clk       ), // clock
  .rst_n     (rst_n     ), // reset, asynchronous low
  .pix_val   (gray_val  ), // pixel valid
  .pix_sof   (gray_sof  ), // pixel start of frame
  .pix_eof   (gray_eof  ), // pixel end of frame
  .pix_sol   (gray_sol  ), // pixel start of line
  .pix_eol   (gray_eol  ), // pixel end of line
  .pix_data  (gray_data ), // pixel grayscale value
  .gauss_val (gauss_val ), // gaussian frame valid
  .gauss_data(gauss_data)  // gaussian output frame
);

sobel_edge#(
  .FRAME_WIDTH (FRAME_WIDTH ), // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT), // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   )  // 8 bits for pixels after grayscale conversion
) i_sobel (
  .clk       (clk       ),  // clock
  .rst_n     (rst_n     ),  // reset, asynchronous low
  .gauss_val (gauss_val ),  // gaussian frame valid
  .gauss_data(gauss_data),  // gaussian frame
  .sobel_val (sobel_val ),  // sobel valid
  .sobel_dir (sobel_dir ),  // sobel output frame of gradients directions (angle)
  .sobel_data(sobel_data)   // sobel output frame of gradients magnitude (euclidian formula obtained)
);

nonmax_suppress#(
  .FRAME_WIDTH (FRAME_WIDTH ), // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT), // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   )  // 8 bits for pixels after grayscale conversion
) i_nms (
  .clk      (clk       ),  // clock
  .rst_n    (rst_n     ),  // reset, asynchronous low
  .edge_val (sobel_val ),  // sobel edge frame valid
  .edge_mag (sobel_data),  // sobel output frame of gradients magnitude
  .edge_dir (sobel_dir ),  // sobel output frame of gradients directions
  .thin_val (nms_val   ),  // thin edge valid
  .thin_edge(nms_data  )   // thin edge output frame
);

double_threshold#(
  .FRAME_WIDTH (FRAME_WIDTH ), // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT), // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   ), // 8 bits for pixels after grayscale conversion
  .HIGH_THRESH (HIGH_THRESH ), // High threshold value
  .LOW_THRESH  (LOW_THRESH  )  // Low threshold value
) i_double_threshold (
  .clk      (clk      ),  // clock
  .rst_n    (rst_n    ),  // reset, asynchronous low
  .thin_val (nms_val  ),  // thin edge frame valid
  .thin_edge(nms_data ),  // thin edge input frame
  .dual_val (dual_val ),  // dual threshold valid
  .str_edge (str_edge ),  // strong edges output frame
  .weak_edge(weak_edge)   // weak edges output frame
);

hyst_threshold#(
  .FRAME_WIDTH (FRAME_WIDTH ),     // frame width parameter   -default VGA res
  .FRAME_HEIGHT(FRAME_HEIGHT),     // frame height parameter  -default VGA res
  .PIX_WIDTH   (PIX_WIDTH   )      // 8 bits for pixels after grayscale conversion
) i_hysteresis_threshold (
  .clk       (clk       ),  // clock
  .rst_n     (rst_n     ),  // reset, asynchronous low
  .dual_val  (dual_val  ),  // dual threshold valid
  .str_edge  (str_edge  ),  // strong edges input frame
  .weak_edge (weak_edge ),  // weak edges input frame
  .hyst_val  (canny_val ),  // hysteresis valid
  .final_edge(canny_data)   // final edges output frame
);

endmodule