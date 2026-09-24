from pathlib import Path
import sys
from PIL import Image

# ==============================================================================
# Configuration: Sprite Dimensions and Sheet Definitions
# ==============================================================================
MAX_COLORS = 16
PAD_PALETTE_TO_16 = True  # Fully initialize all 16 entries of clut_mem (prevents uninitialized memory warnings in synthesis)

# Sprite dimension variables for each file
TILES_SPRITE_WIDTH = 16
TILES_SPRITE_HEIGHT = 16

FACE_SPRITE_WIDTH = 24
FACE_SPRITE_HEIGHT = 24

NUMBERS_SPRITE_WIDTH = 13
NUMBERS_SPRITE_HEIGHT = 23

# List of sprite sheets to process in order.
# IMPORTANT: Process tiles_sprite first so that the base palette indices (0-9)
# match existing hardware decoding and ROM implementations.
SPRITE_SHEETS = [
    {
        "name": "tiles_sprite",
        "image_file": "Tiles_Sprite.png",
        "sprite_width": TILES_SPRITE_WIDTH,
        "sprite_height": TILES_SPRITE_HEIGHT,
        "output_mem": "tiles_sprite.mem",
        "alias_mem": "sprite_rom.mem",  # Kept for backward compatibility with src/sprite_rom.sv
    },
    {
        "name": "face_sprite",
        "image_file": "Face_Sprite.png",
        "sprite_width": FACE_SPRITE_WIDTH,
        "sprite_height": FACE_SPRITE_HEIGHT,
        "output_mem": "face_sprite.mem",
        "alias_mem": None,
    },
    {
        "name": "numbers_sprite",
        "image_file": "Numbers_Sprite.png",
        "sprite_width": NUMBERS_SPRITE_WIDTH,
        "sprite_height": NUMBERS_SPRITE_HEIGHT,
        "output_mem": "numbers_sprite.mem",
        "alias_mem": None,
    },
]

# Shared color palette output file
PALETTE_OUTPUT_FILE = "palette_rom.mem"


# ==============================================================================
# Main Processing
# ==============================================================================
def main():
    # Base directory where this script and sprite images reside
    base_dir = Path(__file__).resolve().parent

    # Shared color palette across all sprite sheets
    palette = []
    generated_files = []

    print("=" * 65)
    print("Minesweeper Multi-Sprite Sheet Processor")
    print("=" * 65)

    # For loop to iterate through the different sprite sheets
    for sheet in SPRITE_SHEETS:
        sheet_name = sheet["name"]
        image_path = base_dir / sheet["image_file"]
        output_path = base_dir / sheet["output_mem"]
        alias_path = base_dir / sheet["alias_mem"] if sheet.get("alias_mem") else None

        # Variables setting sprite width and height for this file
        sprite_width = sheet["sprite_width"]
        sprite_height = sheet["sprite_height"]

        print(f"\nProcessing [{sheet_name}]:")
        print(f"  Input Image   : {image_path.name}")
        print(f"  Sprite Size   : {sprite_width}w x {sprite_height}h")
        print(f"  Output .mem   : {output_path.name}")

        try:
            # Convert to RGB to extract exact pixel color data
            img = Image.open(image_path).convert("RGB")
        except FileNotFoundError:
            print(f"Error: Could not find image at {image_path}")
            sys.exit(1)

        width, height = img.size

        # Validate that dimensions divide cleanly
        if width % sprite_width != 0 or height % sprite_height != 0:
            print(f"  Warning: Image dimensions ({width}x{height}) are not an exact multiple "
                  f"of sprite dimensions ({sprite_width}x{sprite_height})!")

        cols = width // sprite_width
        rows = height // sprite_height
        total_sprites = cols * rows

        mem_lines = []

        # Iterate through the sprites in grid layout (row by row)
        for y in range(0, height, sprite_height):
            for x in range(0, width, sprite_width):
                # Calculate sprite ID within this sheet
                sprite_id = (y // sprite_height) * cols + (x // sprite_width)
                mem_lines.append(f"// Sprite ID {sprite_id}\n")

                # Scan every pixel in this sprite block (row-major: top-to-bottom, left-to-right)
                for sy in range(sprite_height):
                    for sx in range(sprite_width):
                        px = img.getpixel((x + sx, y + sy))

                        # Add to shared palette if we haven't seen this color yet
                        if px not in palette:
                            if len(palette) >= MAX_COLORS:
                                print(f"Error: Combined sprite sheets exceed {MAX_COLORS} colors!")
                                print(f"Failed at {sheet_name}, Sprite {sprite_id}, pixel ({sx}, {sy}): color {px}")
                                sys.exit(1)
                            palette.append(px)

                        # Get the 4-bit color index in the shared palette
                        color_idx = palette.index(px)

                        # Write the single hex digit (4 bits)
                        mem_lines.append(f"{color_idx:X}\n")

        # Write to this sprite sheet's dedicated .mem file
        with open(output_path, "w") as mem_file:
            mem_file.writelines(mem_lines)
        generated_files.append(output_path.name)

        # Write to alias .mem file if specified (e.g. sprite_rom.mem for backward compatibility)
        if alias_path:
            with open(alias_path, "w") as alias_file:
                alias_file.writelines(mem_lines)
            generated_files.append(alias_path.name)
            print(f"  Alias .mem    : {alias_path.name}")

        print(f"  Sprites Found : {total_sprites}")
        print(f"  Pixels Output : {total_sprites * sprite_width * sprite_height}")
        print(f"  Palette Count : {len(palette)} unique colors so far")

    # --------------------------------------------------------------------------
    # Generate the Shared Color Palette Initialization File
    # --------------------------------------------------------------------------
    pal_path = base_dir / PALETTE_OUTPUT_FILE
    with open(pal_path, "w") as pal_file:
        pal_file.write("// 12-bit RGB Color Palette (4 bits per channel: R G B)\n")
        pal_file.write(f"// Shared palette generated across {len(SPRITE_SHEETS)} sprite sheets\n")
        pal_file.write(f"// {len(palette)} unique colors extracted\n")

        for idx, (r, g, b) in enumerate(palette):
            # Downsample 8-bit RGB (0-255) to 4-bit RGB (0-15) for standard FPGA VGA DACs
            r_4bit = r >> 4
            g_4bit = g >> 4
            b_4bit = b >> 4
            pal_file.write(f"{r_4bit:X}{g_4bit:X}{b_4bit:X} // Index {idx:2d}: Original RGB({r:3d},{g:3d},{b:3d})\n")

        # Optionally pad to 16 entries to fully initialize CLUT memory depth
        if PAD_PALETTE_TO_16 and len(palette) < MAX_COLORS:
            pal_file.write("// Padded entries to initialize all 16 words of CLUT RAM\n")
            for idx in range(len(palette), MAX_COLORS):
                pal_file.write(f"000 // Index {idx:2d}: Padded (unused)\n")

    generated_files.append(pal_path.name)

    print("\n" + "=" * 65)
    print(f"Success: Processed {len(SPRITE_SHEETS)} sprite sheets with {len(palette)} unique shared colors.")
    print("Generated files:")
    for f in generated_files:
        print(f"  - {f}")
    print("=" * 65)


if __name__ == "__main__":
    main()