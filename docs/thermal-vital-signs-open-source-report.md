# Open-Source Thermal Vital-Sign Repository Findings

Date researched: 2026-07-26  
Scope: open-source software and reproducible methods for extracting health-related signals from thermal or infrared face video, with emphasis on nostril localization and respiratory rate.

## Executive summary

There is no mature repository that can be dropped directly into this iOS application to turn the supplied Hikvision SDK stream into clinically validated vital signs.

The strongest reusable pieces are distributed across several projects:

- [Deep_Respiration](https://github.com/MohsenMozaffary/Deep_Respiration) contains the closest matching thermal-video respiratory models.
- [StressNet](https://github.com/UCSB-VRL/StressNet-Detecting-stress-from-thermal-videos) provides an MIT-licensed thermal facial physiology model and a released research dataset.
- [Thermal Image Analysis](https://github.com/detecttechnologies/Thermal_Image_Analysis) and [thermal_base](https://github.com/detecttechnologies/thermal_base) demonstrate radiometric decoding, temperature matrices, emissivity correction, and ROI statistics.
- [IR_iHR](https://github.com/natalialmg/IR_iHR) demonstrates face-region signal extraction and instantaneous heart-rate recovery from infrared video, but its near-infrared assumptions are not equivalent to long-wave thermal imaging.
- [NeuroKit2](https://github.com/neuropsychology/NeuroKit) is a useful downstream signal-processing and validation toolbox after a thermal ROI has been reduced to a one-dimensional respiratory signal.

For a first product prototype, a classical nostril-temperature pipeline is lower risk than immediately training a deep model:

1. obtain calibrated per-pixel temperatures;
2. detect the face and nose;
3. localize and track the nostril ROI;
4. extract a robust temperature statistic for each frame;
5. reject motion and poor-quality windows;
6. band-pass the signal in a physiologic breathing range;
7. detect breath events and calculate inter-breath intervals;
8. return respiratory rate with a confidence/quality score.

Deep learning should be evaluated after a labeled, device-specific dataset and a valid software-license path exist.

## Search and evaluation method

Repositories were evaluated for:

- direct use of thermal/infrared video;
- biomarker target and physiological rationale;
- input format and preprocessing;
- availability of code, weights, and datasets;
- license clarity;
- evidence from an associated paper;
- compatibility with a mobile, real-time pipeline;
- suitability for the supplied radiometric thermal camera.

Repository code was inspected locally at the commit listed below. Scientific claims were cross-checked against primary papers or official project documentation.

## Repository comparison

| Repository | Biomarker/use | Thermal match | License | Practical status |
|---|---|---:|---|---|
| [MohsenMozaffary/Deep_Respiration](https://github.com/MohsenMozaffary/Deep_Respiration) | Respiratory waveform/rate from thermal video | High | No license found | Best algorithm reference; not legally reusable until licensed |
| [UCSB-VRL/StressNet](https://github.com/UCSB-VRL/StressNet-Detecting-stress-from-thermal-videos) | ISTI and stress from thermal face video; includes breathing-related processing in paper | High | MIT | Research code and dataset; heavy/old ML stack |
| [natalialmg/IR_iHR](https://github.com/natalialmg/IR_iHR) | Non-contact PPG and instantaneous heart rate from IR face video | Medium-low | No license found | Valuable signal-extraction reference; spectral modality differs |
| [detecttechnologies/Thermal_Image_Analysis](https://github.com/detecttechnologies/Thermal_Image_Analysis) | Radiometric image inspection, ROI statistics, emissivity correction, export | High for preprocessing | MIT | Useful concepts/utilities; file formats are FLIR/DJI, not Hikvision |
| [detecttechnologies/thermal_base](https://github.com/detecttechnologies/thermal_base) | Thermal-file decoding to temperature/raw matrices | High for preprocessing | MIT | Useful decoder reference but archived and format-specific |
| [neuropsychology/NeuroKit](https://github.com/neuropsychology/NeuroKit) | Respiratory and cardiac signal processing | Modality-independent | MIT | Strong offline/reference validation layer after ROI extraction |

## 1. Deep_Respiration

Repository: [MohsenMozaffary/Deep_Respiration](https://github.com/MohsenMozaffary/Deep_Respiration)  
Inspected commit: `5cc1383` (2026-02-26)  
Associated paper: [Respiratory Rate Estimation from Thermal Video Data Using Spatio-Temporal Deep Learning](https://www.mdpi.com/1424-8220/24/19/6386)

### What it implements

The repository contains PyTorch implementations of:

- PhysNet;
- DeepPhys adapted to single-channel thermal input;
- StressNet adapted for respiratory extraction;
- PhysLSTM and related CNN/RNN/attention variants;
- custom losses combining waveform and frequency behavior;
- a NumPy thermal-video/respiration-label loader;
- a minimal training script.

The paper's proposed pipeline uses face ROI detection, a shallow 3D CNN, a bidirectional LSTM, band-pass filtering, and peak-frequency selection. It studied 22 participants in sitting/standing and masked/unmasked conditions. The paper reports an average respiratory-rate error of `1.6 +/- 0.4` breaths/minute and describes 10-second windows, thermal video downsampled to 5 fps, and 128 x 128 face crops.

### Reusable ideas

- Treat respiration extraction as waveform reconstruction, not only direct BPM regression.
- Use spatio-temporal convolutions for short thermal patterns and an LSTM for longer breathing dependencies.
- Use maximum cross-correlation in the loss because facial thermal airflow and an abdominal reference belt can be phase shifted.
- Include peak-frequency error in the training objective.
- Downsample temporal data to reduce cost while preserving the sub-1 Hz respiratory band.
- Evaluate masked and unmasked cases separately; the mask itself may carry a strong thermal breathing signal.

### Gaps and cautions

- No `LICENSE` file was found. Public visibility does not grant permission to copy or ship the code.
- No pretrained weights, labeled dataset, detector code, or end-to-end inference application were present in the inspected checkout.
- `main.py` is a training sketch with placeholder paths and hard-coded CUDA use.
- The loader assumes paired `.npy` files in `thermal/` and `resp/`, normalizes with fixed constants, and repeats frames across channels in a way that must be reconciled with individual model inputs.
- The repository README says four algorithms, but the code contains more experimental architectures. Documentation is sparse.
- Training data came from a high-end FLIR T650sc at 640 x 480 and 30 fps; performance may not transfer to this camera's resolution, noise, palette, calibration, or compression.
- The paper's face-level model is not the same as explicit nostril localization. It may learn from the nose, mask, head, and neck.

### Recommendation

Use this repository to define offline benchmarks after a device-specific dataset exists. Do not import its source into the application until the author supplies an explicit license.

## 2. StressNet

Repository: [UCSB-VRL/StressNet-Detecting-stress-from-thermal-videos](https://github.com/UCSB-VRL/StressNet-Detecting-stress-from-thermal-videos)  
Inspected commit: `870d02e` (2026-06-26)  
Associated paper: [StressNet: Detecting Stress in Thermal Videos](https://openaccess.thecvf.com/content/WACV2021/html/Kumar_StressNet_Detecting_Stress_in_Thermal_Videos_WACV_2021_paper.html)

### What it implements

StressNet is an end-to-end research pipeline for:

- preprocessing thermal facial video;
- modeling thermal emission and frame-to-frame changes;
- predicting Initial Systolic Time Interval (ISTI), a cardiac sympathetic marker;
- classifying stress state from the predicted signal.

The repository includes separate ISTI and stress predictors, training scripts, dataloaders, model modules, and an MIT license. Its README now points to a released thermal-video dataset on UCSB's BisQue platform; dataset terms may differ from the code license.

### Reusable ideas

- Combine static thermal emission with temporal differences instead of treating frames as ordinary grayscale video.
- Normalize and register a face tube before physiological inference.
- Use spatio-temporal networks for thermal facial dynamics.
- Keep physiological-signal reconstruction separate from the downstream health-state classifier.
- The paper also describes extracting a breathing signal below the nostrils and band-pass filtering it between 0.1 and 0.85 Hz before using it to improve stress detection.

### Gaps and cautions

- The main target is ISTI/stress, not respiratory rate.
- It requires supervised ECG and impedance-cardiography-derived targets for the core model.
- Dependencies are pinned around 2020 (`torch 1.4`, old NumPy/OpenCV/dlib), so direct installation on a current Apple or Python stack is unlikely to work without porting.
- The training pipeline is workstation/GPU-oriented, not iOS-ready.
- Dataset access and redistribution terms need separate review.
- The paper reports research-cohort results, not clinical validation or general-population performance.

### Recommendation

This is the best licensed reference for future thermal stress research and for designing a thermal temporal representation. It should not be part of the first respiratory-rate milestone.

## 3. IR_iHR

Repository: [natalialmg/IR_iHR](https://github.com/natalialmg/IR_iHR)  
Inspected commit: `71ae747` (2020-02-29)  
Associated paper: [Non-contact photoplethysmogram and instantaneous heart rate estimation from infrared face video](https://arxiv.org/abs/1902.05194)

### What it implements

The project provides notebooks and Python utilities for:

- dlib face landmarks;
- subdivision of the face into small spatial regions;
- mean infrared activity per region over time;
- matrix denoising/decomposition;
- signal-quality ranking and component reconstruction;
- short-time Fourier analysis and instantaneous heart-rate curve extraction.

### Reusable ideas

- Use many small facial regions instead of trusting one fixed ROI.
- Build a region-by-time matrix and suppress common motion/illumination components.
- Rank candidate physiological components using a signal-quality index.
- Reconstruct a consensus signal from multiple high-quality components.
- Extract a smoothly varying frequency path from a spectrogram rather than selecting each frame's independent maximum.

### Critical modality caveat

The paper used a Microsoft Kinect infrared camera and relies on infrared reflectance/PPG behavior. That is near-infrared imaging, not necessarily long-wave radiometric thermography. Blood-volume-driven reflectance changes and emitted-temperature changes have different physics.

The spatial/statistical methods may transfer, but the physiological assumptions and frequency performance must be revalidated on true thermal data.

### Gaps and cautions

- No repository license was found.
- The study involved seven healthy participants with relatively fixed heads.
- The code is notebook/research oriented.
- Dlib landmarks trained on visible faces may fail on low-resolution thermal frames.
- The method is not a nostril-temperature respiratory pipeline.

### Recommendation

Use it as a design reference for multi-region denoising and time-frequency tracking. Do not reuse code without a license, and do not describe it as validated thermal heart-rate extraction for this sensor.

## 4. Thermal Image Analysis and thermal_base

Repositories:

- [detecttechnologies/Thermal_Image_Analysis](https://github.com/detecttechnologies/Thermal_Image_Analysis), inspected commit `8c9d8b3` (2022-05-08);
- [detecttechnologies/thermal_base](https://github.com/detecttechnologies/thermal_base).

Both use the MIT license. `thermal_base` is archived.

### What they implement

`thermal_base` decodes supported FLIR/DJI files into:

- a temperature matrix;
- raw sensor values;
- extracted metadata.

It also includes temperature manipulation utilities such as ROI-specific emissivity changes.

The desktop Thermal Image Analysis application adds:

- spot temperatures;
- line profiles;
- polygon ROI minimum/maximum/average values;
- ROI contrast scaling;
- colormaps;
- reflected-temperature and emissivity adjustments;
- CSV/TIFF export of temperature matrices.

### Reusable ideas

- Preserve raw sensor values, calibrated temperatures, display colors, and metadata as separate representations.
- Apply emissivity and reflected-temperature corrections in the radiometric domain.
- Export temperature matrices for reproducible algorithm development.
- Use point/line/region statistics to validate the vendor SDK's thermometry output.
- Keep palette/contrast operations out of quantitative temperature data.

### Gaps and cautions

- Supported decoders target FLIR RJPEG/SEQ and DJI formats, not Hikvision's appended payload.
- They operate primarily on files, not low-latency network streams.
- `thermal_base` relies on ExifTool and format-specific embedded metadata.
- An archived decoder should not become a critical production dependency without ownership and tests.

### Recommendation

Port the representation and calibration concepts, not the decoder. The Hikvision payload needs its own adapter. These tools can serve as offline comparison utilities if frames are exported to a supported neutral format.

## 5. NeuroKit2

Repository: [neuropsychology/NeuroKit](https://github.com/neuropsychology/NeuroKit)  
Documentation: [NeuroKit2 respiration processing](https://neuropsychology.github.io/NeuroKit/functions/rsp.html)  
License: MIT

### What it contributes

NeuroKit2 is modality-independent. Once the nostril ROI has produced a scalar temperature series, its respiration tools can provide:

- signal cleaning;
- peak and trough detection;
- instantaneous respiration rate;
- inspiration/expiration phase;
- amplitude;
- respiratory-rate variability;
- interval-level summary features and plots.

`rsp_rate()` supports breath-onset and cross-correlation methods. `rsp_process()` provides a complete reference pipeline.

### Gaps and cautions

- The functions expect a respiratory waveform, commonly from a belt. They do not find a face or nostril.
- Default filter ranges and peak detectors may not suit low-rate, low-frame-rate thermal data.
- It is a Python validation tool, not an iOS deployment library.
- Some output metrics, such as respiratory volume per time, should not be interpreted literally from nostril temperature without validation.

### Recommendation

Use NeuroKit2 in the offline research harness to compare the application's Swift/DSP implementation against a known open-source signal-processing stack.

## Strong methods without reusable repositories

The repository search also found highly relevant published pipelines whose code or trained assets were not clearly available for reuse.

### Automated nostril detection and tracking

[Adaptive Thermal Imaging Signal Analysis for Real-Time Non-Invasive Respiratory Rate Monitoring](https://www.mdpi.com/1424-8220/26/1/278) describes:

- YOLOv8n nostril detection in 256 x 192 thermal frames;
- detection every second frame;
- an eight-state constant-velocity Kalman tracker between detections;
- the coldest temperature in the nostril ROI as the frame signal;
- a 20-second sliding buffer;
- a fourth-order 0.08-0.7 Hz zero-phase Butterworth band-pass;
- median/MAD adaptive thresholds, hysteresis, and flicker suppression;
- inter-breath-interval validation over 5-42 BPM;
- weighted and exponential smoothing.

The paper reports `0.57 +/- 0.36` BPM mean absolute error across ten participants and multiple controlled conditions. This is the clearest recent blueprint for the requested nostril example, but the paper, model, dataset, and exact evaluation conditions must be independently reproduced before product use.

### Motion-robust classical tracking

[Robust tracking of respiratory rate in high-dynamic range scenes using mobile thermal imaging](https://arxiv.org/abs/1705.06628) proposes:

- adaptive temperature quantization;
- thermal-gradient flow for nostril tracking;
- a thermal-voxel representation instead of simple spatial averaging.

These ideas are valuable when the display palette, ambient temperature, or head motion makes a fixed intensity ROI unstable.

### Broad evidence review

[Thermal Cameras for Continuous and Contactless Respiration Monitoring](https://pmc.ncbi.nlm.nih.gov/articles/PMC11679429/) reviews the field and reinforces common failure modes: ROI motion, head rotation, distance, sensor resolution, environmental drift, weak nasal airflow, and nostril occlusion.

## Recommended respiratory-rate architecture

### 1. Acquisition

Required input:

- calibrated temperature matrix in degrees Celsius;
- monotonic frame timestamp;
- sensor width/height;
- calibration/FFC state;
- optional visible frame and alignment transform.

Reject a data source that provides only a palette-colored JPEG unless the algorithm is explicitly designed and validated for palette intensity.

### 2. Face and nose localization

Preferred sequence:

1. Use the visible-light channel for face landmarks if it is synchronized and geometrically calibrated.
2. Map the nose region into thermal coordinates using the SDK's valid rectangles and a measured transform.
3. Within the thermal nose crop, detect the nostril pair or a combined sub-nasal airflow ROI.
4. Fall back to a thermal-specific detector when visible imagery is unavailable.

Do not rely on a visible-light dlib model directly on thermal frames without measuring detection performance.

### 3. ROI tracking

Track center, width, and height with velocity. Update from the detector periodically and predict between detections. Reject:

- boxes outside the valid thermal image;
- implausible jumps or size changes;
- low detector confidence;
- excessive face yaw/pitch;
- too few radiometric pixels.

Maintain separate `detectorConfidence`, `trackerConfidence`, and `thermalSignalQuality`.

### 4. Per-frame signal extraction

Evaluate at least:

- mean temperature;
- trimmed mean;
- lower percentile;
- coldest stable pixel/patch;
- hottest-coldest difference;
- thermal-voxel or gradient-weighted statistic.

The single minimum pixel can be noisy. A lower percentile or the mean of the coldest connected patch may be more stable while preserving inhalation cooling.

Record motion and FFC flags alongside every sample.

### 5. Signal conditioning

- Resample onto a uniform time grid if frame timing is irregular.
- Remove invalid frames and interpolate only short gaps.
- Remove slow baseline drift.
- Use a physiologically justified band, initially around `0.08-0.7 Hz` (`5-42 BPM`) for adults, with the target population defined explicitly.
- For real-time output, use causal filters and account for group delay.
- Use zero-phase filtering only in offline analysis because it depends on future samples.

### 6. Rate estimation

Implement two independent estimators:

- time-domain breath events and inter-breath intervals;
- frequency-domain dominant respiratory peak.

Publish a result only when the estimators agree within a configured tolerance and the window has sufficient signal quality.

### 7. Quality and failure states

Return no measurement when:

- the face or nostrils are absent/occluded;
- the subject is speaking or predominantly mouth breathing;
- motion exceeds threshold;
- thermal contrast is too low;
- the ROI is too small;
- FFC/freezing corrupts the window;
- the spectral peak is broad, unstable, or non-physiological;
- too few breath cycles are observed.

An explicit unavailable result is safer than a plausible but unsupported BPM.

## Suggested evaluation plan

### Phase A: radiometric validation

- Compare SDK per-pixel/ROI temperatures with device-reported thermometry.
- Test emissivity, distance, ambient changes, and FFC.
- Verify timestamps and dropped frames.
- Establish thermal-to-visible alignment error.

### Phase B: controlled breathing dataset

Collect synchronized:

- thermal matrices;
- visible frames if available;
- reference respiratory belt or validated capnography;
- device/subject distance and pose;
- ambient conditions;
- FFC events.

Include resting, paced slow/normal/fast breathing, speech, yaw, pitch, glasses/facial hair variation, masks, and deliberate nostril occlusion. Split train/test data by participant, never by random frame.

### Phase C: algorithm baselines

Compare:

1. fixed manual ROI plus mean temperature;
2. tracked ROI plus robust percentile;
3. tracked ROI plus adaptive time-domain detector;
4. tracked ROI plus FFT;
5. Deep_Respiration models if licensing and data permit.

Report MAE, RMSE, bias/limits of agreement, coverage, time-to-first-result, and failure rate. Accuracy on emitted measurements alone is insufficient; coverage matters.

### Phase D: mobile feasibility

Measure:

- detector and tracker latency;
- memory and thermal load;
- battery consumption;
- sustained frame rate;
- data retained on device;
- model size and update strategy.

The simplest detector-plus-DSP pipeline should be the mobile baseline.

## Licensing and product-use conclusions

- **Safe code references to prototype from:** StressNet, Thermal Image Analysis, thermal_base, and NeuroKit2 are MIT-licensed, subject to attribution/license preservation.
- **Do not copy without permission:** Deep_Respiration and IR_iHR had no license in the inspected checkout.
- **Dataset rights are separate:** a repository's code license does not automatically cover faces, thermal videos, model weights, or labels.
- **Research is not clinical validation:** reported cohort accuracy does not establish safety, efficacy, or regulatory suitability for Vvewell.
- **Model provenance matters:** record repository URL, commit, license, training data, preprocessing, and modifications for every incorporated component.

## Final recommendation

Build the first prototype around:

- the SDK's verified radiometric data route;
- a visible-to-thermal face/nose mapping when possible;
- thermal-specific nostril refinement and Kalman tracking;
- robust per-frame nostril temperature extraction;
- a 20-30 second quality-controlled signal window;
- time-domain inter-breath intervals plus a frequency-domain cross-check;
- an offline NeuroKit2 comparison harness.

Use Deep_Respiration as an experimental benchmark, not the first production dependency. Defer heart rate and stress until respiratory acquisition, calibration, motion handling, and reference-sensor validation are reliable.

