# Open-Source LWIR Respiratory-Rate Repository Report

**Research date:** 2026-07-27  
**Scope:** Open-source software, pretrained weights, ONNX artifacts, example code, and datasets for estimating human respiratory rate from long-wave infrared (LWIR) thermal video.

## Executive Summary

No credible, ready-to-use repository was found that simultaneously provides:

1. human LWIR thermal-video input;
2. automated nostril or perinasal localization;
3. respiratory-rate or breathing-waveform output;
4. pretrained ONNX weights; and
5. complete, runnable example inference code.

The strongest practical candidates are:

- [Oulu Human Thermal Sensing](https://github.com/Multimodal-Sensing-Lab/oulu-human-thermal-sensing) for a documented and evaluated end-to-end signal-processing pipeline;
- [Thermal Vital Signs Toolbox](https://github.com/VM230800/Thermal-Vital-Signs-Toolbox) for its bundled 54-landmark thermal facial-pose checkpoint with explicit nostril points; and
- [ThermRNet](https://github.com/wfhhisagony/ThermRNet) for its pretrained spatiotemporal respiratory model and thermal YOLO checkpoints.

The most realistic implementation path is to combine a thermally trained face or nostril detector with a classical temperature-signal pipeline. ONNX or Core ML conversion should be performed only after the detector has been validated on frames from the target camera.

## Search Method

The search covered:

- GitHub repository metadata, source trees, READMEs, model files, test assets, and licenses;
- Hugging Face model searches for `thermal`, `thermography`, `LWIR`, `infrared`, `respiration`, `respiratory`, `breathing`, `nostril`, and `perinasal`;
- Hugging Face model file lists, specifically checking for `.onnx` artifacts;
- Hugging Face thermal-face and facial-landmark datasets;
- recent thermal-respiration papers that provide public source-code links; and
- deployment suitability for mobile and iOS environments.

Repositories were assessed for physiological relevance, bundled weights, reproducibility, licensing, deployment format, example code, and compatibility with radiometric thermal input.

## Ranked Repository Findings

| Rank | Repository | Included assets | Primary limitation | Assessment |
|---:|---|---|---|---|
| 1 | [Oulu Human Thermal Sensing](https://github.com/Multimodal-Sensing-Lab/oulu-human-thermal-sensing) | Complete LWIR processing pipeline, face landmarks, ROI extraction, filtering, Welch estimation, ground-truth evaluation | Detector weights are downloaded separately; GPL-3.0 | Best reproducible baseline |
| 2 | [Thermal Vital Signs Toolbox](https://github.com/VM230800/Thermal-Vital-Signs-Toolbox) | Bundled 54-keypoint YOLOv11 checkpoint, explicit nostril landmarks, multiple RR methods | No license or published validation results | Best nostril-localization candidate for evaluation |
| 3 | [ThermRNet](https://github.com/wfhhisagony/ThermRNet) | Pretrained respiratory model, two thermal YOLO pose models, nose cropper, sample video | Broken committed inference path; no license; no ONNX | Best deep-learning research artifact |
| 4 | [Screen Apnea](https://github.com/gajendramandal/Screen_Apnea) | Nostril annotations, YOLOv8 methodology, notebooks and thermal recordings | Advertised model path and requirements are not reproducible as documented | Useful training and research material |
| 5 | [RespThermal_RQI](https://github.com/YudaiTaka0515/RespThermal_RQI) | Boson 320 real-time application and respiratory-quality-index code | Old Keras stack; external HDF5 weight not bundled | Useful legacy reference |
| 6 | [TIPA](https://github.com/deepneuroscience/TIPA) | Thermal physiological-computing notebooks and classical processing | No modern pretrained respiratory detector | Supporting signal-processing reference |
| 7 | [Contactless-Rsp](https://github.com/mraz-mrs/Contactless-Rsp) | MIT-licensed masked-autoencoder and respiratory-learning source | No pretrained checkpoint or direct inference entry point | Useful for future model training |

## 1. Oulu Human Thermal Sensing

Repository: [Multimodal-Sensing-Lab/oulu-human-thermal-sensing](https://github.com/Multimodal-Sensing-Lab/oulu-human-thermal-sensing)

This is the most complete and reproducible thermal cardiorespiratory pipeline found. It processes raw LWIR recordings, detects facial landmarks, extracts regional temperature traces, synchronizes them with reference physiology, and estimates breathing rate.

### Included functionality

- Raw FLIR Tau 640 thermal-video decoding.
- LWIR resolution of 640 × 512 at 7.5 frames per second.
- Thermal face detection using YOLOv5-Face weights trained on the TFW dataset.
- Six anatomical facial regions.
- Spatial aggregation of thermal pixels.
- Nose-and-cheek respiratory signal extraction.
- OMIT decomposition and Welch spectral estimation.
- Synchronized contact ground truth.
- Download, visualization, extraction, analysis, and evaluation scripts.
- GPL-3.0 license.

The repository reports a breathing-rate mean absolute error of **3.1 ± 1.1 breaths per minute** on its selected SIM1 sessions.

### Limitations

- The face model is not stored in the repository. The TFW checkpoint must be downloaded separately.
- TFW provides a face box and five facial landmarks: both eyes, nose tip, and mouth corners. It does not explicitly identify the nostril apertures.
- GPL-3.0 may be unsuitable for incorporation into a closed-source mobile application without a licensing review.
- The evaluated camera and frame rate differ from the current target hardware.

### Recommended use

Use this repository as the reference architecture and evaluation harness. Its signal extraction, frequency estimation, synchronized validation, and failure analysis are more valuable than treating its detector as a final production model.

## 2. Thermal Vital Signs Toolbox

Repository: [VM230800/Thermal-Vital-Signs-Toolbox](https://github.com/VM230800/Thermal-Vital-Signs-Toolbox)

This repository is the closest functional match to automated nostril-based respiratory-rate estimation.

### Included functionality

- A real, bundled `YOLOv11_TFL_252.pt` checkpoint of 13,976,444 bytes.
- Fifty-four thermal facial landmarks.
- Explicit landmark definitions for left and right nostrils.
- Facial contour, forehead, nose, eye, and mouth landmarks.
- Per-frame landmark inference using Ultralytics YOLO.
- Nose, philtrum, cheek, and forehead ROI construction.
- Mean-temperature respiratory estimation.
- Independent component analysis across multiple ROIs.
- A Garbey-style line-spectrum method.
- Butterworth respiratory filtering at 0.1–0.5 Hz, corresponding to approximately 6–30 breaths per minute.
- FFT and peak-based rate extraction.
- BP4D+ and raw-temperature NPZ dataset loaders.
- Evaluation code for MAE, RMSE, correlation, and Bland–Altman plots.

### Important implementation observations

- Floating-point thermal frames are normalized separately to 8-bit for YOLO inference.
- The downstream signal is extracted from the processed frames. Care is required to preserve a parallel radiometric temperature frame for physiological signal extraction.
- The non-streaming path detects the initial face crop and reuses it. It does not provide a Kalman filter or robust long-term ROI tracker.
- Respiratory-rate estimates from multiple ROIs are combined using their median.

### Limitations

- The repository was created in June 2026 and has no established usage history.
- No license is declared. The source and weights therefore cannot be assumed to permit redistribution or product integration.
- No quantitative result table or immediately downloadable validation dataset is included.
- The model is PyTorch, not ONNX.
- Independent testing on the target camera is essential.

### Recommended use

Evaluate its 54-point checkpoint on recorded target-camera frames. If the nostril landmarks are stable, this is the best candidate detector for a prototype. Obtain explicit licensing permission before redistributing the checkpoint.

## 3. ThermRNet

Repository: [wfhhisagony/ThermRNet](https://github.com/wfhhisagony/ThermRNet)

ThermRNet is the strongest deep-learning artifact found specifically for thermal respiratory analysis.

### Included assets

- `ThermRNetv1.pth`, approximately 18.7 MB.
- `yolov11n_tf.pt`, approximately 5.6 MB.
- `yolov11s_tf.pt`, approximately 19.8 MB.
- A separate training checkpoint.
- A sample thermal respiratory video.
- Nose-region cropping code.
- Classical mean-temperature, bandpass, FFT, and peak-based RR estimation.
- A spatiotemporal respiratory-phase model.
- Training notebooks for two ThermRNet versions.

The face models were reportedly fine-tuned from Ultralytics YOLOv11 pose models using a private dataset and the public TFW dataset. The supplied respiratory model consumes 160 frames resized to 96 × 96 with three channels. It produces a two-class temporal sequence representing respiratory phases, from which breaths per minute are calculated.

### Reproducibility problems

The deep inference path does not run as committed:

- Configuration requests `ThermRNet.pth`, but the included file is named `ThermRNetv1.pth`.
- `rr_detector_model.py` imports functions that are commented out of `rr_models/__init__.py`.
- The inference class hardcodes `cuda:0`.
- Two different ThermRNet architectures appear in the source tree, making checkpoint compatibility ambiguous.
- The repository notes ONNX conversion as a future task rather than supplying an ONNX model.

### Licensing

No license is declared. The repository is source-visible, but it should not be treated as legally open source until the author provides terms.

### Recommended use

Treat ThermRNet as a research prototype requiring repair. First reconstruct the exact checkpoint architecture and verify PyTorch output against the included sample. Only then attempt ONNX or Core ML conversion.

## 4. Screen Apnea

Repository: [gajendramandal/Screen_Apnea](https://github.com/gajendramandal/Screen_Apnea)

Screen Apnea describes a highly relevant workflow:

- thermal facial recordings;
- manually annotated nostril regions;
- a YOLOv8n nostril detector;
- mean-pixel signal extraction;
- downsampling to 20 Hz;
- 0.1–0.5 Hz bandpass filtering; and
- comparison with chest-belt data.

The README reports:

- more than 3,500 annotated thermal frames;
- `mAP@0.5 = 0.978`;
- `mAP@0.5:0.95 = 0.815`; and
- data from 12 initial and 45 extended-study participants.

### Limitations

- The advertised `best.pt` path was not directly retrievable during verification.
- The documented `requirements.txt` was not present at the repository root.
- Much of the implementation is organized as notebooks and stored experimental artifacts.
- No license is declared.
- Reported physiological error values should be independently checked for unit consistency.

### Recommended use

Use the annotations and notebooks as references for nostril detector training. Do not plan around the checkpoint until its actual location, integrity, and license have been confirmed.

## 5. RespThermal_RQI

Repository: [YudaiTaka0515/RespThermal_RQI](https://github.com/YudaiTaka0515/RespThermal_RQI)

This project accompanies work on estimating respiratory rate using a Respiratory Likelihood or Quality Index.

### Included functionality

- Face-based respiratory estimation.
- Nose-and-mouth respiratory estimation.
- FLIR Boson 320 integration.
- A real-time GUI demonstration.
- A Keras YOLOv3-based environment.

### Limitations

- The required `weights.weights.h5` is referenced as an external shared file and is not bundled.
- The dependency stack is old.
- No license is declared.
- Porting the Keras YOLOv3 pipeline to a modern iOS environment would require considerable replacement work.

### Recommended use

Use its respiratory-quality concepts and camera-integration patterns as historical references, not as the main deployment foundation.

## 6. TIPA

Repository: [deepneuroscience/TIPA](https://github.com/deepneuroscience/TIPA)

TIPA is an older thermal physiological and affective computing toolkit. It includes notebook-based examples and references to robust mobile-thermal respiratory tracking.

It is useful for learning:

- thermal image preprocessing;
- physiological thermal ROI analysis;
- respiratory-signal extraction; and
- older high-dynamic-range thermal tracking techniques.

It does not provide a modern pretrained nostril detector, ONNX checkpoint, or a deployable respiratory-rate model.

## 7. Contactless-Rsp

Repository: [mraz-mrs/Contactless-Rsp](https://github.com/mraz-mrs/Contactless-Rsp)

This MIT-licensed repository accompanies a recent masked-autoencoder method for thermal respiratory monitoring. It contains:

- masked-autoencoder, Vision Transformer, ResNet, and ConvNeXt implementations;
- training and fine-tuning configurations;
- data loaders;
- respiratory waveform losses; and
- trainer implementations.

It does not contain a pretrained checkpoint or a clear end-user inference script. Consequently, it is a training framework rather than an off-the-shelf model.

## Hugging Face Findings

### ONNX search result

A file-level search of Hugging Face models returned no relevant model combining human thermal imagery, respiration, and an ONNX checkpoint.

The thermal-tagged ONNX models found were unrelated to respiratory monitoring:

- thermal breast-cancer classification; and
- animal or general object detection.

The current [Hugging Face thermal model listing](https://huggingface.co/models?other=thermal) is primarily composed of general detection, classification, representation-learning, and image-generation models.

### Relevant Hugging Face resources

#### TFW thermal-face dataset

Dataset: [issai/TFW](https://huggingface.co/datasets/issai/TFW)

TFW is the strongest relevant Hugging Face resource:

- MIT-identified dataset card;
- human thermal faces captured indoors and outdoors;
- 9,982 images;
- 16,509 annotated faces;
- thermal face boxes;
- five facial landmarks; and
- original FLIR T540 acquisition in the 7.5–14 µm LWIR band.

The associated [TFW GitHub repository](https://github.com/IS2AI/TFW) links to multiple pretrained YOLOv5 and YOLO5Face thermal checkpoints and includes example commands.

TFW does not contain:

- explicit left and right nostril annotations;
- respiratory waveforms;
- respiratory-rate labels; or
- ONNX exports.

It is nevertheless valuable for thermal-domain face localization and as a starting point for transfer learning.

#### MediaPipe face ONNX

Model: [Heliosoph/mediapipe-face-onnx](https://huggingface.co/Heliosoph/mediapipe-face-onnx)

This Apache-2.0 package contains face detection and six-point landmark ONNX files with example code. Its advantages are clean licensing, small models, and ready ONNX inference.

It is trained for visible-spectrum faces, not LWIR. It identifies a nose tip but not separate nostrils. It may work on palette-mapped thermal images, but that would be an unverified domain transfer and should not be assumed.

#### Qualcomm facial landmarks

Model: [qualcomm/Facial-Landmark-Detection](https://huggingface.co/qualcomm/Facial-Landmark-Detection)

This mobile-oriented model provides 68 facial landmarks and deployment artifacts, including TFLite. It is optimized for Qualcomm hardware and visible imagery. It is not a thermal respiratory model, but it is relevant as an example of a compact mobile facial-landmark network.

#### CattleFace-RGBT

Dataset: [phamtrongthang/CattleFace-RGBT](https://huggingface.co/datasets/phamtrongthang/CattleFace-RGBT)

This dataset includes paired RGB and thermal cattle faces with nostril keypoints and radiometric thermal TIFF data. It is not suitable for direct human inference, but its annotation and radiometric-data organization may be useful when designing a human thermal-nostril dataset.

## ONNX and iOS Deployment Assessment

An ONNX checkpoint is useful for cross-platform execution through ONNX Runtime Mobile, but ONNX is not mandatory for iOS.

[Apple Core ML Tools](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html) recommends converting supported PyTorch models directly to Core ML rather than using ONNX as an intermediate representation. Core ML can use the Apple CPU, GPU, and Neural Engine.

[ONNX Runtime Mobile](https://onnxruntime.ai/docs/tutorials/mobile/) remains appropriate when the same inference implementation must run across iOS, Android, desktop, or embedded platforms.

### Suggested conversion sequence

1. Load and test the original PyTorch checkpoint.
2. Record reference outputs for representative thermal frames.
3. Export or trace with a fixed input shape.
4. Convert to Core ML directly, or export ONNX if cross-platform execution is required.
5. Reproduce preprocessing exactly.
6. Compare landmark coordinates and confidence scores numerically.
7. Test video latency, memory, and thermal throttling on the target device.
8. Validate physiological output against synchronized reference measurements.

Conversion success does not demonstrate physiological validity. The target camera's palette, temperature scaling, resolution, optics, distance, frame rate, and sensor noise may differ substantially from the training data.

## Recommended Architecture

The recommended prototype is a hybrid pipeline:

```text
Radiometric LWIR frames
        |
        +--> display/palette conversion
        |
        +--> detector-specific 8-bit normalization
                    |
            thermal face/nostril detector
                    |
              ROI confidence gate
                    |
             Kalman ROI tracking
                    |
     original radiometric nostril pixels
                    |
     robust ROI statistic per timestamp
                    |
      resampling and artifact rejection
                    |
       respiratory band processing
                    |
 adaptive phase detection and valid IBI checks
                    |
       RR estimate + quality score
```

The detector and physiological streams should remain separate:

- the detector receives normalized imagery optimized for localization;
- the signal extractor receives original radiometric or stable raw-sensor values; and
- timestamps, rather than assumed frame indices, determine sampling intervals.

## Final Recommendation

For an immediate prototype:

1. Adopt the Oulu repository's pipeline structure and evaluation practices.
2. Test the Thermal Vital Signs Toolbox checkpoint for explicit nostril localization.
3. Benchmark a lightweight TFW YOLO5Face model as a thermal face-detection fallback.
4. Add Kalman-based ROI stabilization.
5. Extract robust radiometric statistics from the original nostril ROI.
6. Implement both spectral estimation and adaptive time-domain phase detection.
7. Produce a confidence score from detector confidence, ROI continuity, spectral concentration, and valid inter-breath intervals.
8. Validate against synchronized respiratory-belt data under motion, speech, pose, distance, and thermal-drift conditions.

ThermRNet should be evaluated as a second-stage research track after its checkpoint-loading path is repaired. At present, the hybrid thermal detector plus classical signal-processing approach is more transparent, portable, and testable than any available end-to-end model.

## Licensing Warning

Repositories without an explicit license do not grant normal open-source reuse rights merely because their source and weights are publicly visible. In particular, the Thermal Vital Signs Toolbox, ThermRNet, Screen Apnea, and RespThermal_RQI require author clarification before their code or weights are redistributed in a product.

