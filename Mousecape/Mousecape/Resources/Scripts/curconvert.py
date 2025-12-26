#!/usr/bin/env python3
"""
Windows Cursor Converter for Mousecape

Converts Windows .cur (static) and .ani (animated) cursor files
to a JSON format suitable for Mousecape import.

Usage:
    curconvert.py <input_file>
    curconvert.py --folder <folder_path>

Output (JSON to stdout):
    {
        "success": true,
        "width": 32,
        "height": 32,
        "hotspotX": 0,
        "hotspotY": 0,
        "frameCount": 1,
        "frameDuration": 0.1,
        "imageData": "<base64 PNG>"
    }

For animated cursors, imageData contains a vertical sprite sheet
with all frames stacked (frame 0 at top).
"""

import sys
import json
import base64
import struct
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print(json.dumps({
        "success": False,
        "error": "Pillow is not installed. Run: pip install Pillow"
    }))
    sys.exit(1)


def parse_cur_file(filepath: str) -> dict:
    """
    Parse a Windows .cur file.

    CUR format:
    - ICONDIR header (6 bytes): reserved, type (2=cursor), count
    - ICONDIRENTRY (16 bytes each): width, height, colors, reserved, hotspotX, hotspotY, size, offset
    - Image data (BMP or PNG)
    """
    with open(filepath, 'rb') as f:
        # Read ICONDIR header
        reserved, filetype, count = struct.unpack('<HHH', f.read(6))

        if filetype != 2:
            raise ValueError(f"Not a cursor file (type={filetype}, expected 2)")

        if count < 1:
            raise ValueError("No cursor images in file")

        # Read all ICONDIRENTRY entries to find the best one
        entries = []
        for i in range(count):
            width = struct.unpack('<B', f.read(1))[0]
            height = struct.unpack('<B', f.read(1))[0]
            colors = struct.unpack('<B', f.read(1))[0]
            reserved = struct.unpack('<B', f.read(1))[0]
            hotspot_x = struct.unpack('<H', f.read(2))[0]
            hotspot_y = struct.unpack('<H', f.read(2))[0]
            size = struct.unpack('<I', f.read(4))[0]
            offset = struct.unpack('<I', f.read(4))[0]

            # Width/height of 0 means 256
            if width == 0:
                width = 256
            if height == 0:
                height = 256

            entries.append({
                'width': width,
                'height': height,
                'colors': colors,
                'hotspot_x': hotspot_x,
                'hotspot_y': hotspot_y,
                'size': size,
                'offset': offset
            })

        # Choose the largest image (prefer higher resolution)
        best_entry = max(entries, key=lambda e: e['width'] * e['height'])

        # Read image data
        f.seek(best_entry['offset'])
        image_data = f.read(best_entry['size'])

        # Try to decode as PNG first (modern cursors)
        if image_data[:8] == b'\x89PNG\r\n\x1a\n':
            img = Image.open(BytesIO(image_data))
        else:
            # It's a BMP/DIB format - need special handling
            img = decode_bmp_cursor(image_data, best_entry['width'], best_entry['height'])

        # Ensure RGBA
        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        # Convert to PNG
        png_buffer = BytesIO()
        img.save(png_buffer, format='PNG')
        png_data = png_buffer.getvalue()

        return {
            'success': True,
            'width': img.width,
            'height': img.height,
            'hotspotX': best_entry['hotspot_x'],
            'hotspotY': best_entry['hotspot_y'],
            'frameCount': 1,
            'frameDuration': 0.0,
            'imageData': base64.b64encode(png_data).decode('ascii')
        }


def decode_bmp_cursor(data: bytes, width: int, height: int) -> Image.Image:
    """
    Decode BMP/DIB format cursor image data.

    The DIB in cursor files has:
    - BITMAPINFOHEADER (40 bytes)
    - Color table (if applicable)
    - XOR mask (color data)
    - AND mask (transparency)
    """
    # Read BITMAPINFOHEADER
    header_size = struct.unpack('<I', data[0:4])[0]
    bmp_width = struct.unpack('<i', data[4:8])[0]
    bmp_height = struct.unpack('<i', data[8:12])[0]  # Doubled for XOR+AND masks
    planes = struct.unpack('<H', data[12:14])[0]
    bit_count = struct.unpack('<H', data[14:16])[0]
    compression = struct.unpack('<I', data[16:20])[0]

    # Actual height is half (top half is XOR, bottom half is AND)
    actual_height = abs(bmp_height) // 2

    if bit_count == 32:
        # 32-bit BGRA - most common for modern cursors
        pixel_offset = header_size
        row_size = bmp_width * 4

        pixels = []
        for y in range(actual_height):
            row_offset = pixel_offset + (actual_height - 1 - y) * row_size
            row = []
            for x in range(bmp_width):
                px_offset = row_offset + x * 4
                b, g, r, a = struct.unpack('BBBB', data[px_offset:px_offset + 4])
                row.append((r, g, b, a))
            pixels.append(row)

        img = Image.new('RGBA', (bmp_width, actual_height))
        for y, row in enumerate(pixels):
            for x, pixel in enumerate(row):
                img.putpixel((x, y), pixel)

        return img

    elif bit_count == 24:
        # 24-bit BGR with separate AND mask
        pixel_offset = header_size
        row_size = ((bmp_width * 3 + 3) // 4) * 4  # Padded to 4 bytes

        # Read color data
        pixels = []
        for y in range(actual_height):
            row_offset = pixel_offset + (actual_height - 1 - y) * row_size
            row = []
            for x in range(bmp_width):
                px_offset = row_offset + x * 3
                b, g, r = struct.unpack('BBB', data[px_offset:px_offset + 3])
                row.append((r, g, b, 255))
            pixels.append(row)

        # Read AND mask (1-bit transparency)
        and_row_size = ((bmp_width + 31) // 32) * 4
        and_offset = pixel_offset + row_size * actual_height

        for y in range(actual_height):
            row_offset = and_offset + (actual_height - 1 - y) * and_row_size
            for x in range(bmp_width):
                byte_idx = x // 8
                bit_idx = 7 - (x % 8)
                if row_offset + byte_idx < len(data):
                    mask_byte = data[row_offset + byte_idx]
                    if (mask_byte >> bit_idx) & 1:
                        # AND mask bit set = transparent
                        r, g, b, _ = pixels[y][x]
                        pixels[y][x] = (r, g, b, 0)

        img = Image.new('RGBA', (bmp_width, actual_height))
        for y, row in enumerate(pixels):
            for x, pixel in enumerate(row):
                img.putpixel((x, y), pixel)

        return img

    else:
        # For other bit depths, try using PIL's built-in BMP decoder
        # by wrapping the DIB with a BMP file header
        bmp_header = b'BM' + struct.pack('<I', len(data) + 14) + b'\x00\x00\x00\x00' + struct.pack('<I', 14 + header_size)
        try:
            img = Image.open(BytesIO(bmp_header + data))
            return img.convert('RGBA')
        except Exception:
            # Fallback: create a placeholder
            return Image.new('RGBA', (width, height), (255, 0, 255, 128))


def parse_ani_file(filepath: str) -> dict:
    """
    Parse a Windows .ani (animated cursor) file.

    ANI format is RIFF-based:
    - RIFF header
    - ACON type
    - anih chunk: animation header
    - rate chunk: frame durations (optional, in jiffies: 1/60 sec)
    - seq chunk: frame sequence (optional)
    - LIST chunk with 'fram' type containing icon chunks
    """
    with open(filepath, 'rb') as f:
        data = f.read()

    # Verify RIFF header
    if data[0:4] != b'RIFF':
        raise ValueError("Not a valid RIFF file")

    if data[8:12] != b'ACON':
        raise ValueError("Not an animated cursor file")

    # Parse chunks
    pos = 12
    anih_data = None
    rate_data = None
    frames = []

    while pos < len(data) - 8:
        chunk_id = data[pos:pos + 4]
        chunk_size = struct.unpack('<I', data[pos + 4:pos + 8])[0]
        chunk_data = data[pos + 8:pos + 8 + chunk_size]

        if chunk_id == b'anih':
            anih_data = parse_anih_chunk(chunk_data)
        elif chunk_id == b'rate':
            rate_data = parse_rate_chunk(chunk_data, anih_data['num_frames'] if anih_data else 0)
        elif chunk_id == b'LIST':
            list_type = chunk_data[0:4]
            if list_type == b'fram':
                frames = parse_fram_list(chunk_data[4:])

        # Move to next chunk (padded to even boundary)
        pos += 8 + chunk_size
        if chunk_size % 2 == 1:
            pos += 1

    if not frames:
        raise ValueError("No frames found in ANI file")

    if not anih_data:
        anih_data = {'num_frames': len(frames), 'num_steps': len(frames), 'display_rate': 10}

    # Calculate frame duration (jiffies to seconds)
    if rate_data:
        # Use average rate if variable
        avg_rate = sum(rate_data) / len(rate_data)
        frame_duration = avg_rate / 60.0
    else:
        frame_duration = anih_data.get('display_rate', 10) / 60.0

    # Get dimensions and hotspot from first frame
    first_frame = frames[0]
    width = first_frame['width']
    height = first_frame['height']
    hotspot_x = first_frame['hotspot_x']
    hotspot_y = first_frame['hotspot_y']

    # Create sprite sheet (all frames stacked vertically)
    sprite_sheet = Image.new('RGBA', (width, height * len(frames)))

    for i, frame in enumerate(frames):
        img = frame['image']
        # Resize if needed
        if img.width != width or img.height != height:
            img = img.resize((width, height), Image.Resampling.LANCZOS)
        sprite_sheet.paste(img, (0, i * height))

    # Convert to PNG
    png_buffer = BytesIO()
    sprite_sheet.save(png_buffer, format='PNG')
    png_data = png_buffer.getvalue()

    return {
        'success': True,
        'width': width,
        'height': height,
        'hotspotX': hotspot_x,
        'hotspotY': hotspot_y,
        'frameCount': len(frames),
        'frameDuration': frame_duration,
        'imageData': base64.b64encode(png_data).decode('ascii')
    }


def parse_anih_chunk(data: bytes) -> dict:
    """Parse the anih (animation header) chunk."""
    if len(data) < 36:
        return {}

    return {
        'header_size': struct.unpack('<I', data[0:4])[0],
        'num_frames': struct.unpack('<I', data[4:8])[0],
        'num_steps': struct.unpack('<I', data[8:12])[0],
        'width': struct.unpack('<I', data[12:16])[0],
        'height': struct.unpack('<I', data[16:20])[0],
        'bit_count': struct.unpack('<I', data[20:24])[0],
        'num_planes': struct.unpack('<I', data[24:28])[0],
        'display_rate': struct.unpack('<I', data[28:32])[0],
        'flags': struct.unpack('<I', data[32:36])[0]
    }


def parse_rate_chunk(data: bytes, num_frames: int) -> list:
    """Parse the rate chunk (frame durations in jiffies)."""
    rates = []
    for i in range(num_frames):
        if i * 4 + 4 <= len(data):
            rate = struct.unpack('<I', data[i * 4:i * 4 + 4])[0]
            rates.append(rate)
    return rates


def parse_fram_list(data: bytes) -> list:
    """Parse the fram LIST containing icon chunks."""
    frames = []
    pos = 0

    while pos < len(data) - 8:
        chunk_id = data[pos:pos + 4]
        chunk_size = struct.unpack('<I', data[pos + 4:pos + 8])[0]
        chunk_data = data[pos + 8:pos + 8 + chunk_size]

        if chunk_id == b'icon':
            frame = parse_icon_chunk(chunk_data)
            if frame:
                frames.append(frame)

        pos += 8 + chunk_size
        if chunk_size % 2 == 1:
            pos += 1

    return frames


def parse_icon_chunk(data: bytes) -> dict:
    """Parse an icon chunk (same format as .cur file)."""
    # Check if it's a complete ICO/CUR file
    if len(data) < 6:
        return None

    reserved, filetype, count = struct.unpack('<HHH', data[0:6])

    if filetype not in (1, 2) or count < 1:
        return None

    # Read first ICONDIRENTRY
    width = data[6] or 256
    height = data[7] or 256
    hotspot_x = struct.unpack('<H', data[10:12])[0]
    hotspot_y = struct.unpack('<H', data[12:14])[0]
    size = struct.unpack('<I', data[14:18])[0]
    offset = struct.unpack('<I', data[18:22])[0]

    if offset + size > len(data):
        return None

    image_data = data[offset:offset + size]

    # Decode image
    if image_data[:8] == b'\x89PNG\r\n\x1a\n':
        img = Image.open(BytesIO(image_data))
    else:
        img = decode_bmp_cursor(image_data, width, height)

    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    return {
        'width': img.width,
        'height': img.height,
        'hotspot_x': hotspot_x,
        'hotspot_y': hotspot_y,
        'image': img
    }


def convert_file(filepath: str) -> dict:
    """Convert a cursor file and return result dict."""
    path = Path(filepath)

    if not path.exists():
        return {'success': False, 'error': f"File not found: {filepath}"}

    ext = path.suffix.lower()

    try:
        if ext == '.cur':
            return parse_cur_file(filepath)
        elif ext == '.ani':
            return parse_ani_file(filepath)
        else:
            return {'success': False, 'error': f"Unsupported file type: {ext}"}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def convert_folder(folder_path: str) -> dict:
    """Convert all cursor files in a folder."""
    path = Path(folder_path)

    if not path.is_dir():
        return {'success': False, 'error': f"Not a directory: {folder_path}"}

    results = []

    for file in path.iterdir():
        if file.suffix.lower() in ('.cur', '.ani'):
            result = convert_file(str(file))
            result['filename'] = file.stem  # Name without extension
            results.append(result)

    return {
        'success': True,
        'cursors': results
    }


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            'success': False,
            'error': 'Usage: curconvert.py <file> or curconvert.py --folder <path>'
        }))
        sys.exit(1)

    if sys.argv[1] == '--folder':
        if len(sys.argv) < 3:
            print(json.dumps({
                'success': False,
                'error': 'Missing folder path'
            }))
            sys.exit(1)
        result = convert_folder(sys.argv[2])
    else:
        result = convert_file(sys.argv[1])

    print(json.dumps(result))


if __name__ == '__main__':
    main()
