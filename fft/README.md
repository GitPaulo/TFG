# `fft.py`

This works by preprocessing the songs to compute their Fast Fourier Transform (FFT) data and saves the results in a compressed format using MessagePack.

It's kind of dumb but it works neatly and saves the game from computing it real-time.

### How it works

1. Converts MP3 audio files to WAV format for easier processing.
2. Computes FFT for overlapping chunks of the audio signal.
3. Normalizes and quantizes FFT magnitudes for efficient storage.
4. Saves the processed FFT data in a compressed MessagePack file.

### Usage

```sh
  pip install -r requirements.txt
```
