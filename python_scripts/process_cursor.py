import sys
from PIL import Image

palette = {
    (255, 255, 255): 0,
    (192, 192, 192): 1,
    (128, 128, 128): 2,
    (255, 0, 0): 3,
    (0, 0, 0): 4,
    (0, 0, 255): 5,
    (0, 128, 0): 6,
    (0, 0, 128): 7,
    (128, 0, 0): 8,
    (0, 128, 128): 9,
    (255, 255, 0): 10,
    (128, 128, 0): 11,
    (255, 0, 255): 15,
}

def closest_color(rgb):
    if rgb in palette:
        return palette[rgb]
    # Find closest based on Euclidean distance
    min_dist = float('inf')
    best_idx = 15
    for p_rgb, idx in palette.items():
        dist = (rgb[0] - p_rgb[0])**2 + (rgb[1] - p_rgb[1])**2 + (rgb[2] - p_rgb[2])**2
        if dist < min_dist:
            min_dist = dist
            best_idx = idx
    return best_idx

def main():
    try:
        img = Image.open('Cursor.png').convert('RGB')
    except Exception as e:
        print(f"Error opening image: {e}")
        return

    width, height = img.size
    print(f"Cursor size: {width}x{height}")

    with open('../src/mem/cursor_sprite.mem', 'w') as f:
        for y in range(height):
            for x in range(width):
                px = img.getpixel((x, y))
                idx = closest_color(px)
                f.write(f"{idx:X}\n")

    print("Created ../src/mem/cursor_sprite.mem")

if __name__ == "__main__":
    main()
