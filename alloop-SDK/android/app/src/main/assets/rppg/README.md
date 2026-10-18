# ME-rPPG runtime assets

This directory is reserved for the runtime assets sourced from:

`https://github.com/leehangyue/knowell`

Expected files:

- `model.onnx`
- `state.json`
- `ms_deploy.json`

The Android pipeline follows the source implementation's 36×36 face crop,
frame-delta input, recurrent state loop, BVP output, 0.7–2.5 Hz physiological
band, harmonic suppression, SQI, and HRV post-processing.

Raw camera frames remain on-device and are not persisted or uploaded.
