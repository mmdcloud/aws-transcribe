"""
Generates a valid mono 16kHz PCM WAV test audio file using Python standard library.
No external audio tools or ffmpeg required.
"""

import math
import struct
import wave
import os

def create_sample_wav(filename: str = "tests/sample_call.wav", duration_seconds: float = 3.0):
    sample_rate = 16000  # 16 kHz recommended for speech transcription
    num_samples = int(sample_rate * duration_seconds)

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, "wb") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit PCM (2 bytes)
        wav_file.setframerate(sample_rate)

        # Generate a simulated two-frequency tone alternating like dialogue
        for i in range(num_samples):
            t = float(i) / sample_rate
            freq = 440.0 if (int(t * 2) % 2 == 0) else 880.0
            sample_val = int(16000 * math.sin(2.0 * math.pi * freq * t))
            wav_file.writeframes(struct.pack("<h", sample_val))

    print(f"Created sample audio file: {filename} ({duration_seconds}s, {sample_rate}Hz 16-bit mono)")

if __name__ == "__main__":
    create_sample_wav()
