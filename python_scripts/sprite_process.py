from PIL import Image
import sys

# Configuration
IMAGE_PATH = "Tiles_Sprite.png"
SPRITE_SIZE = 16
MAX_COLORS = 16

try:
    # Convert to RGB to extract exact pixel data
    img = Image.open(IMAGE_PATH).convert("RGB")
except FileNotFoundError:
    print(f"Error: Could not find {IMAGE_PATH}")
    sys.exit(1)

width, height = img.size
palette = []

# Open output files
with open("sprite_rom.mem", "w") as mem_file:
    # Iterate through the sprites (assuming a grid layout)
    for y in range(0, height, SPRITE_SIZE):
        for x in range(0, width, SPRITE_SIZE):
            
            # Add a comment in the .mem file to mark the start of a new sprite
            sprite_id = (y // SPRITE_SIZE) * (width // SPRITE_SIZE) + (x // SPRITE_SIZE)
            mem_file.write(f"// Sprite ID {sprite_id}\n")
            
            # Scan every pixel in this 16x16 block
            for sy in range(SPRITE_SIZE):
                for sx in range(SPRITE_SIZE):
                    px = img.getpixel((x + sx, y + sy))
                    
                    # Add to palette if we haven't seen it yet
                    if px not in palette:
                        if len(palette) >= MAX_COLORS:
                            print(f"Error: Image contains more than {MAX_COLORS} colors!")
                            sys.exit(1)
                        palette.append(px)
                    
                    # Get the 4-bit color index
                    color_idx = palette.index(px)
                    
                    # Write the single hex digit (4 bits)
                    mem_file.write(f"{color_idx:X}\n")

# Generate the Color Palette Initialization File
with open("palette_rom.mem", "w") as pal_file:
    pal_file.write("// 12-bit RGB Color Palette (4 bits per channel: R G B)\n")
    for idx, (r, g, b) in enumerate(palette):
        # Downsample 8-bit RGB (0-255) to 4-bit RGB (0-15) for standard FPGA VGA DACs
        r_4bit = r >> 4
        g_4bit = g >> 4
        b_4bit = b >> 4
        pal_file.write(f"{r_4bit:X}{g_4bit:X}{b_4bit:X} // Index {idx}: Original RGB({r},{g},{b})\n")

print(f"Success: Processed {len(palette)} unique colors.")
print("Generated sprite_rom.mem and palette_rom.mem")