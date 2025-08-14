# Install dependencies
!pip install pillow pydub matplotlib

# Install FFmpeg for MP3 export
!apt-get install -y ffmpeg

import os
import math
import io
import zipfile
import struct
import wave
from PIL import Image, ImageDraw, ImageFont
from pydub import AudioSegment
import matplotlib.font_manager as fm
from IPython.display import FileLink

# === Output directories ===
base_dir = "/content/pistelaskuri"
frames_dir = os.path.join(base_dir, "frames")
sounds_dir = os.path.join(base_dir, "sounds")
os.makedirs(frames_dir, exist_ok=True)
os.makedirs(sounds_dir, exist_ok=True)

# === Numbers to generate ===
numbers_list = ["0", "300", "800", "1500", "2500", "3500", "4500", "5000"]

# === Font selection ===
available_fonts = fm.findSystemFonts(fontext='ttf')
font_path = next((f for f in available_fonts if any(k in f for k in ["Comic", "Impact", "Sans"])), None)
if font_path is None and available_fonts:
    font_path = available_fonts[0]

try:
    font_base = ImageFont.truetype(font_path, 180)
except OSError:
    font_base = ImageFont.load_default()

# === PNG generation ===
img_size = (800, 400)
outline_range = 6

for num in numbers_list:
    img = Image.new("RGBA", img_size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Use getbbox for better centering
    bbox = font_base.getbbox(num)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (img_size[0] - w) // 2
    y = (img_size[1] - h) // 2 - bbox[1]

    # Outline
    for ox in range(-outline_range, outline_range + 1):
        for oy in range(-outline_range, outline_range + 1):
            if ox != 0 or oy != 0:
                draw.text((x + ox, y + oy), num, font=font_base, fill=(0, 0, 0, 255))

    # Yellow fill
    draw.text((x, y), num, font=font_base, fill=(255, 215, 0, 255))

    img.save(os.path.join(frames_dir, f"{num}.png"))

# === Sound generation (MP3 directly in memory) ===
def generate_pling_mp3(path, duration_ms=150, freq=1500):
    sample_rate = 44100
    num_samples = int(sample_rate * duration_ms / 1000)
    audio = []

    for x in range(num_samples):
        val = (math.sin(2 * math.pi * freq * x / sample_rate) +
               0.5 * math.sin(2 * math.pi * freq * 2 * x / sample_rate))
        val *= math.sin(math.pi * x / num_samples)  # smooth fade in/out
        audio.append(val)

    max_val = max(abs(min(audio)), max(audio))
    audio = [int(v / max_val * 32767) for v in audio]

    # Create WAV in memory
    wav_buffer = io.BytesIO()
    with wave.open(wav_buffer, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for v in audio:
            wf.writeframes(struct.pack("<h", v))

    wav_buffer.seek(0)
    mp3_audio = AudioSegment.from_wav(wav_buffer)
    mp3_audio.export(path, format="mp3")

for num in numbers_list:
    generate_pling_mp3(os.path.join(sounds_dir, f"{num}.mp3"))

# === Create ZIP with only frames/ and sounds/ ===
zip_path = "/content/pistelaskuri.zip"
with zipfile.ZipFile(zip_path, 'w') as zipf:
    for folder_name in [frames_dir, sounds_dir]:
        for file in os.listdir(folder_name):
            folder_label = os.path.basename(folder_name)
            file_path = os.path.join(folder_name, file)
            zipf.write(file_path, arcname=f"{folder_label}/{file}")

# Show download link
FileLink(zip_path)