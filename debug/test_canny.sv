module test_canny;

  // Parameters
  localparam FRAME_WIDTH  =  50;     // Width matches input image
  localparam FRAME_HEIGHT =  50;     // Height matches input image
  localparam PIX_WIDTH    =  24;      // 8 bits each for R,G,B
  localparam HIGH_THRESH  = 100;     // High threshold for double threshold stage
  localparam LOW_THRESH   =  50;      // Low threshold for double threshold stage
  
  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Input frame interface
  logic                    pix_val ;
  logic                    pix_sof ;
  logic                    pix_eof ;
  logic                    pix_sol ;
  logic                    pix_eol ;
  logic [PIX_WIDTH-1:0]    pix_data;
  
  // Output frame interface
  logic                     canny_val;
  logic [(PIX_WIDTH/3)-1:0] canny_data [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

  // File handle and line buffer
  integer file;
  string line;
  logic [7:0] char;
  
  // Store frames for verification
  logic [PIX_WIDTH-1:0]     input_frame [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0];

  // Monitor signals
  integer current_row;
  integer current_col;
  logic   in_frame   ;
  logic   in_line    ;

  // Debug signals
  logic [31:0] cycle_count;
  logic [31:0] timeout_cycles = 1000000; // 1M cycles timeout

  // Print Edge Statistics
    int strong_edge_count = 0;
    int weak_edge_count = 0;
    int final_edge_count = 0;

  // Instantiate canny module
  canny #(
    .FRAME_WIDTH (FRAME_WIDTH),
    .FRAME_HEIGHT(FRAME_HEIGHT),
    .PIX_WIDTH   (PIX_WIDTH),
    .HIGH_THRESH (HIGH_THRESH),
    .LOW_THRESH  (LOW_THRESH)
  ) u_canny (
    .clk       (clk       ),
    .rst_n     (rst_n     ),
    .pix_val   (pix_val   ),
    .pix_sof   (pix_sof   ),
    .pix_eof   (pix_eof   ),
    .pix_sol   (pix_sol   ),
    .pix_eol   (pix_eol   ),
    .pix_data  (pix_data  ),
    .canny_val (canny_val ),
    .canny_data(canny_data)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Cycle counter for timeout
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cycle_count <= 0;
    else
      cycle_count <= cycle_count + 1;
  end

  // Function to convert hex character to 4-bit value
  function logic [3:0] hex_char_to_val(logic [7:0] hex_char);
    case (hex_char)
      "0"    : return 4'h0;
      "1"    : return 4'h1;
      "2"    : return 4'h2;
      "3"    : return 4'h3;
      "4"    : return 4'h4;
      "5"    : return 4'h5;
      "6"    : return 4'h6;
      "7"    : return 4'h7;
      "8"    : return 4'h8;
      "9"    : return 4'h9;
      "a","A": return 4'ha;
      "b","B": return 4'hb;
      "c","C": return 4'hc;
      "d","D": return 4'hd;
      "e","E": return 4'he;
      "f","F": return 4'hf;
      default: return 4'h0;
    endcase
  endfunction

  // Helper function to get state names
  function string get_state_name(logic [1:0] state);
    case (state)
      2'd0:    return "IDLE"   ;
      2'd1:    return "CAPTURE";
      2'd2:    return "PADDING";
      2'd3:    return "PROCESS";
      default: return "UNKNOWN";
    endcase
  endfunction

  // Test stimulus
  initial begin
    $display("\n=== Starting Canny Edge Detection Test ===");
    
    // Initialize signals
    rst_n       = 0;
    pix_val     = 0;
    pix_sof     = 0;
    pix_eof     = 0;
    pix_sol     = 0;
    pix_eol     = 0;
    pix_data    = 0;
    current_row = 0;
    current_col = 0;
    in_frame    = 0;
    in_line     = 0;

    // Reset sequence
    $display("\nStarting reset sequence at %0t", $time);
    repeat(10) @(posedge clk);
    rst_n = 1'b1;
    repeat(5) @(posedge clk);
    $display("Reset sequence complete at %0t", $time);

    // Open pixel data file
    file = $fopen("../image_pixels.txt", "r");
    if (file == 0) begin
      $display("Error: Failed to open image_pixels.txt");
      $finish;
    end

    // Process pixel data
    pix_val   = 1;
    pix_sof   = 1;
    in_frame  = 1;
    
    // Read each line
    for (current_row = 0; current_row < FRAME_HEIGHT; current_row++) begin
      // Start of line
      pix_sol = 1;
      in_line = 1;
      $display("\nProcessing row %0d", current_row);
      
      // Read line from file
      void'($fgets(line, file));
      
      // Process each pixel
      for (current_col = 0; current_col < FRAME_WIDTH; current_col++) begin
        // Convert 6 hex chars to 24-bit pixel value
        pix_data = 0;
        for (int i = 0; i < 6; i++) begin
          char     = line.getc(current_col*7 + i); // 7 chars per pixel (6 hex + 1 space)
          pix_data = (pix_data << 4) | hex_char_to_val(char);
        end
        
        // Store in input frame
        input_frame[current_row][current_col] = pix_data;
        
        // Set end of line/frame flags
        if (current_col == FRAME_WIDTH-1) begin
          pix_eol = 1;
          in_line = 0;
          if (current_row == FRAME_HEIGHT-1) begin
            pix_eof  = 1;
            in_frame = 0;
          end
        end
        
        @(posedge clk);
        
        // Clear flags after one cycle
        pix_sof = 0;
        pix_sol = 0;
        pix_eol = 0;
        pix_eof = 0;
      end
      
      // Start of next line
      if (current_row < FRAME_HEIGHT-1) begin
        pix_sol = 1;
      end
    end
    
    // Close file
    $fclose(file);
    
    // Clear valid signal
    pix_val = 0;
    
    // Wait for processing to complete or timeout
    $display("\nWaiting for processing to complete...");
    fork
      begin
        wait(canny_val);
        $display("Processing complete at %0t", $time);
      end
      begin
        repeat(timeout_cycles) @(posedge clk);
        $display("ERROR: Simulation timeout after %0d cycles", timeout_cycles);
        display_gaussian_debug();
        $finish;
      end
    join_any
    disable fork;
    
    // Display results
    display_all_frames();
    
    #100 $finish;
  end

  // Enhanced monitoring block
  initial begin
    string states[] = '{"IDLE", "CAPTURE", "PADDING", "PROCESS"};
    forever @(posedge clk) begin
      // Monitor Gaussian blur state transitions
      if (u_canny.i_gaussian_blur.state != $past(u_canny.i_gaussian_blur.state)) begin
        $display("\nTime %0t: Gaussian Blur state change: %s -> %s", 
                $time,
                states[$past(u_canny.i_gaussian_blur.state)],
                states[u_canny.i_gaussian_blur.state]);
      end

      // Monitor position counters in Gaussian blur
      if (u_canny.i_gaussian_blur.state == u_canny.i_gaussian_blur.PROCESS) begin
        $display("Time %0t: Gaussian Processing position: (%0d,%0d)", 
                $time, 
                u_canny.i_gaussian_blur.proc_x,
                u_canny.i_gaussian_blur.proc_y);
        
        // Monitor window values being processed
        if (u_canny.i_gaussian_blur.window_sum != 0) begin
          $display("Window sum at (%0d,%0d): %0d", 
                  u_canny.i_gaussian_blur.proc_x,
                  u_canny.i_gaussian_blur.proc_y,
                  u_canny.i_gaussian_blur.window_sum);
        end
      end

      // Monitor padding process
      if (u_canny.i_gaussian_blur.state == u_canny.i_gaussian_blur.PADDING) begin
        $display("Time %0t: Gaussian Padding position: (%0d,%0d)", 
                $time,
                u_canny.i_gaussian_blur.padd_x,
                u_canny.i_gaussian_blur.padd_y);
      end

      // Monitor stage completion flags
      if (u_canny.gray_val) begin
        $display("\nTime %0t: *** Grayscale conversion complete ***", $time);
        display_sample_pixels(u_canny.i_gaussian_blur.internal_frame);
      end

      if (u_canny.gauss_val) begin
        $display("\nTime %0t: *** Gaussian blur complete ***", $time);
        display_sample_pixels(u_canny.gauss_data);
      end

      if (u_canny.sobel_val) begin
        $display("\nTime %0t: *** Sobel edge detection complete ***", $time);
      end

      if (u_canny.nms_val) begin
        $display("\nTime %0t: *** Non-maximum suppression complete ***", $time);
      end

      if (u_canny.dual_val) begin
        $display("\nTime %0t: *** Double threshold complete ***", $time);
      end

      // Monitor frame control signals
      if (u_canny.i_gaussian_blur.state == u_canny.i_gaussian_blur.CAPTURE) begin
        if (pix_sof) $display("Time %0t: Gaussian receiving Start of Frame", $time);
        if (pix_eof) $display("Time %0t: Gaussian receiving End of Frame", $time);
        if (pix_sol) $display("Time %0t: Gaussian receiving Start of Line", $time);
        if (pix_eol) $display("Time %0t: Gaussian receiving End of Line", $time);
      end

      // Monitor Gaussian -> Sobel transition
      if (u_canny.gauss_val) begin
          $display("\nTime %0t: Detailed transition monitoring:", $time);
          $display("  Gaussian valid signal: %b", u_canny.gauss_val);
          $display("  Sobel state: %s", get_state_name(u_canny.i_sobel.state));
          $display("  Sobel input signals:");
          $display("    - gauss_val: %b", u_canny.i_sobel.gauss_val);
          // Sample a few pixels from the Gaussian output
          $display("  Gaussian output sample (first 3x3):");
          for (int i = 0; i < 3; i++) begin
              for (int j = 0; j < 3; j++) begin
                  $write("%3d ", u_canny.gauss_data[i][j]);
              end
              $write("\n");
          end
      end
      
      // Monitor Sobel module state changes
      if (u_canny.i_sobel.state != $past(u_canny.i_sobel.state)) begin
          $display("\nTime %0t: Sobel state change: %s -> %s",
                  $time,
                  get_state_name($past(u_canny.i_sobel.state)),
                  get_state_name(u_canny.i_sobel.state));
      end

      // Monitor Sobel processing
      if (u_canny.i_sobel.state == u_canny.i_sobel.PROCESS) begin
          $display("Time %0t: Sobel processing position (%0d,%0d)",
                  $time,
                  u_canny.i_sobel.proc_x,
                  u_canny.i_sobel.proc_y);
      end
    end
  end

  // Task to display sample pixels from a frame
  task display_sample_pixels(input logic [(PIX_WIDTH/3)-1:0] frame [FRAME_HEIGHT-1:0][FRAME_WIDTH-1:0]);
    $display("Sample pixels (first 5 from first row):");
    for (int i = 0; i < 5; i++) begin
      $write("%3d ", frame[0][i]);
    end
    $write("\n");
  endtask

  // Task to display gaussian debug information
  task display_gaussian_debug();
    $display("\n=== Gaussian Blur Debug Information ===");
    
    // Display padded frame
    $display("\nPadded Frame (first 5x5 region):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.i_gaussian_blur.border_reflect_frame[y][x]);
      end
      $write("\n");
    end

    // Display internal frame
    $display("\nInternal Frame (first 5x5 region):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.i_gaussian_blur.internal_frame[y][x]);
      end
      $write("\n");
    end

    // Display current state and counters
    $display("\nCurrent State: %s", get_state_name(u_canny.i_gaussian_blur.state));
    $display("Processing Position: (%0d,%0d)", 
             u_canny.i_gaussian_blur.proc_x,
             u_canny.i_gaussian_blur.proc_y);
    $display("Padding Position: (%0d,%0d)",
             u_canny.i_gaussian_blur.padd_x,
             u_canny.i_gaussian_blur.padd_y);
    $display("Cycle count: %0d", cycle_count);
  endtask

  // Task to display all frames
  task display_all_frames();
    $display("\n=== Displaying All Processing Stages ===\n");

    // Input RGB Frame (first 5x5 region)
    $display("\nInput RGB Frame (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("(%3d,%3d,%3d) ", 
               input_frame[y][x][23:16],
               input_frame[y][x][15:8],
               input_frame[y][x][7:0]);
      end
      $write("\n");
    end

    // Grayscale Frame
    $display("\nGrayscale Frame (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.i_gaussian_blur.internal_frame[y][x]);
      end
      $write("\n");
    end

    // Gaussian Blur Output
    $display("\nGaussian Blur Output (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.gauss_data[y][x]);
      end
      $write("\n");
    end
    
    // Sobel Edge
        // Sobel Edge Magnitudes
    $display("\nSobel Edge Magnitudes (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.sobel_data[y][x]);
      end
      $write("\n");
    end

    // Sobel Edge Directions
    $display("\nSobel Edge Directions (5x5 sample, 0=0°, 1=45°, 2=90°, 3=135°):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        case(u_canny.sobel_dir[y][x])
          2'b00: $write("  0° ");
          2'b01: $write(" 45° ");
          2'b10: $write(" 90° ");
          2'b11: $write("135° ");
        endcase
      end
      $write("\n");
    end

    // Non-Maximum Suppression Output
    $display("\nNon-Maximum Suppression Output (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.nms_data[y][x]);
      end
      $write("\n");
    end

    // Strong Edges
    $display("\nStrong Edges (5x5 sample, Above High Threshold %0d):", HIGH_THRESH);
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.str_edge[y][x]);
      end
      $write("\n");
    end

    // Weak Edges
    $display("\nWeak Edges (5x5 sample, Between Thresholds %0d-%0d):", LOW_THRESH, HIGH_THRESH);
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", u_canny.weak_edge[y][x]);
      end
      $write("\n");
    end

    // Final Canny Output
    $display("\nFinal Canny Edge Detection Output (5x5 sample):");
    for(int y = 0; y < 5; y++) begin
      for(int x = 0; x < 5; x++) begin
        $write("%3d ", canny_data[y][x]);
      end
      $write("\n");
    end

    // Print Processing Statistics
    $display("\n=== Processing Statistics ===");
    $display("Total cycles taken: %0d", cycle_count);
    $display("Total pixels processed: %0d", FRAME_WIDTH * FRAME_HEIGHT);
    $display("Average cycles per pixel: %0.2f", 
             $itor(cycle_count) / (FRAME_WIDTH * FRAME_HEIGHT));
    $display("Frame resolution: %0d x %0d", FRAME_WIDTH, FRAME_HEIGHT);
    
    // Print Threshold Information
    $display("\n=== Threshold Settings ===");
    $display("High threshold: %0d", HIGH_THRESH);
    $display("Low threshold: %0d", LOW_THRESH);
    
    
    
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
      for(int x = 0; x < FRAME_WIDTH; x++) begin
        if(u_canny.str_edge[y][x] > 0) strong_edge_count++;
        if(u_canny.weak_edge[y][x] > 0) weak_edge_count++;
        if(canny_data[y][x] > 0) final_edge_count++;
      end
    end
    
    $display("\n=== Edge Detection Statistics ===");
    $display("Strong edges detected: %0d pixels (%0.2f%%)", 
             strong_edge_count, 100.0 * strong_edge_count / (FRAME_WIDTH * FRAME_HEIGHT));
    $display("Weak edges detected: %0d pixels (%0.2f%%)", 
             weak_edge_count, 100.0 * weak_edge_count / (FRAME_WIDTH * FRAME_HEIGHT));
    $display("Final edges after hysteresis: %0d pixels (%0.2f%%)", 
             final_edge_count, 100.0 * final_edge_count / (FRAME_WIDTH * FRAME_HEIGHT));

    // Save output to file
    save_output_image();
  endtask

  // Task to save the output image to a file
  // Replace the existing save_output_image task with:
task save_output_image();
    integer outfile, debugfile;
    outfile = $fopen("canny_output.txt", "w");
    debugfile = $fopen("debug_outputs.txt", "w");
    
    if (outfile == 0 || debugfile == 0) begin
        $display("Error: Could not create output files");
        return;
    end

    // Write header information to canny output
    $fwrite(outfile, "// Canny Edge Detection Output\n");
    $fwrite(outfile, "// Resolution: %0dx%0d\n", FRAME_WIDTH, FRAME_HEIGHT);
    $fwrite(outfile, "// Thresholds: High=%0d, Low=%0d\n\n", HIGH_THRESH, LOW_THRESH);

    // Write canny output data
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(outfile, "%3d ", canny_data[y][x]);
        end
        $fwrite(outfile, "\n");
    end

    // Write debug information
    $fwrite(debugfile, "=== All Processing Stages ===\n\n");

    // Write Grayscale data
    $fwrite(debugfile, "=== Grayscale Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.i_gaussian_blur.internal_frame[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    // Write Gaussian data
    $fwrite(debugfile, "\n=== Gaussian Blur Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.gauss_data[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    // Write Sobel magnitude data
    $fwrite(debugfile, "\n=== Sobel Magnitude Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.sobel_data[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    // Write Sobel direction data
    $fwrite(debugfile, "\n=== Sobel Direction Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            case(u_canny.sobel_dir[y][x])
                2'b00: $fwrite(debugfile, "  0° ");
                2'b01: $fwrite(debugfile, " 45° ");
                2'b10: $fwrite(debugfile, " 90° ");
                2'b11: $fwrite(debugfile, "135° ");
            endcase
        end
        $fwrite(debugfile, "\n");
    end

    // Write NMS data
    $fwrite(debugfile, "\n=== Non-Maximum Suppression Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.nms_data[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    // Write Strong edges data
    $fwrite(debugfile, "\n=== Strong Edges Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.str_edge[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    // Write Weak edges data
    $fwrite(debugfile, "\n=== Weak Edges Output ===\n");
    for(int y = 0; y < FRAME_HEIGHT; y++) begin
        for(int x = 0; x < FRAME_WIDTH; x++) begin
            $fwrite(debugfile, "%3d ", u_canny.weak_edge[y][x]);
        end
        $fwrite(debugfile, "\n");
    end

    $fclose(outfile);
    $fclose(debugfile);
    $display("\nSaved edge detection result to: canny_output.txt");
    $display("Saved debug outputs to: debug_outputs.txt");
endtask

  // Debug monitors
  initial begin
    $timeformat(-9, 2, " ns", 20);
    $dumpfile("test_canny.vcd");
    $dumpvars(0, test_canny);
  end

endmodule