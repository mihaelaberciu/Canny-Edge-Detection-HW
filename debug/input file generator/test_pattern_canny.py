import cv2
import numpy as np
from pathlib import Path

def image_to_txt(image_path, output_file='image_pixels.txt'):
    """
    Convert an image to a 150x150 text file with RGB values.
    Each line contains space-separated RGB hex values.
    
    Args:
        image_path (str): Path to the input image
        output_file (str): Name of the output text file
    
    Returns:
        bool: True if conversion was successful, False otherwise
    """
    # Fixed dimensions
    OUTPUT_WIDTH = 50
    OUTPUT_HEIGHT = 50
    
    try:
        # Verify input path
        image_path = Path(image_path)
        if not image_path.exists():
            print(f"Error: Image file not found at {image_path}")
            return False
            
        # Read image
        img = cv2.imread(str(image_path))
        if img is None:
            print(f"Error: Could not read image at {image_path}")
            return False
            
        # Get original dimensions
        original_height, original_width = img.shape[:2]
        print(f"Original image dimensions: {original_width}x{original_height}")
        
        # Resize image
        img = cv2.resize(img, (OUTPUT_WIDTH, OUTPUT_HEIGHT), interpolation=cv2.INTER_AREA)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)  # Convert BGR to RGB
        
        # Create output text
        with open(output_file, 'w') as f:
            for y in range(OUTPUT_HEIGHT):
                row = []
                for x in range(OUTPUT_WIDTH):
                    r, g, b = img[y, x]
                    # Format as 24-bit RGB value (matches your SystemVerilog input format)
                    rgb_hex = f"{r:02x}{g:02x}{b:02x}"
                    row.append(rgb_hex)
                # Write row of hex values
                f.write(' '.join(row) + '\n')
        
        print(f"\nConversion successful!")
        print(f"Generated pixel data file: {output_file}")
        print(f"Output dimensions: {OUTPUT_WIDTH}x{OUTPUT_HEIGHT}")
        print(f"Format: Each pixel is represented as a 24-bit RGB hex value (RRGGBB)")
        print(f"File structure: {OUTPUT_HEIGHT} rows x {OUTPUT_WIDTH} space-separated values per row")
        
        # Calculate and display file size
        file_size = Path(output_file).stat().st_size
        print(f"Output file size: {file_size/1024:.2f} KB")
        
        return True
        
    except Exception as e:
        print(f"Error during conversion: {str(e)}")
        return False

if __name__ == "__main__":
    try:
        image_path = input("Enter the path to your image: ").strip()
        if image_path:
            image_to_txt(image_path)
        else:
            print("Error: No image path provided")
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
    except Exception as e:
        print(f"Unexpected error: {str(e)}")