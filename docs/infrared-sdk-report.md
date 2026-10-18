# Infrared Sensor SDK Findings

Date reviewed: 2026-07-26  
SDK package: `NetSDKV6.1.9.5_build20220614_iOS_NOHPR`  
Target application: Vvewell iOS (`iOS 15+`, Swift 5.9)

## Executive summary

The supplied package is the Hikvision Mobile Device Network SDK for iOS, version 6.1.9.5. It is a general network-device SDK with thermal-camera extensions, not a dedicated HIKMICRO health-analysis SDK.

The SDK provides the lower half of an infrared health-monitoring system:

- device initialization, authentication, connection recovery, and logging;
- live encoded video and SDK-managed preview;
- still-image capture, including a thermal-aware capture structure with visible and appended data;
- device-side point/region thermometry and temperature alarms;
- face thermometry events where the camera firmware supports them;
- generic structured configuration and ISAPI XML/JSON transport;
- playback, recording, PTZ, audio, alarms, and other security-camera functions.

It does **not** provide nostril detection, respiratory-signal extraction, respiratory-rate estimation, heart-rate estimation, or clinical interpretation. Those must be implemented as an application layer above decoded thermal/radiometric frames.

The most important integration uncertainty is the format of `pP2PDataBuff` and the alarm `pThermalInfoBuff`. The header exposes those buffers but the supplied iOS guide does not define their binary layout. Before building a per-pixel temperature pipeline, obtain the model-specific thermometry/radiometry data specification or capture representative payloads and confirm their format with the vendor.

## Evidence reviewed

| Artifact | What it established |
|---|---|
| `../NetSDKV6.1.9.5_build20220614_iOS_NOHPR/doc/Mobile Device Network SDK (iOS) Developer Guide.pdf` | SDK architecture, supported workflows, lifecycle, live view, callbacks, capture, alarm, configuration, and error handling |
| `../NetSDKV6.1.9.5_build20220614_iOS_NOHPR/incEN/HCNetSDK.h` | Complete C API, thermal command IDs, structures, callbacks, and error constants |
| `../NetSDKV6.1.9.5_build20220614_iOS_NOHPR/incEN/plaympeg4.h` | Player/decoder API |
| `../NetSDKV6.1.9.5_build20220614_iOS_NOHPR/incEN/DecodeCardSdk.h` | Legacy decoder-card API; not expected to be useful on modern iOS |
| `../NetSDKV6.1.9.5_build20220614_iOS_NOHPR/SimpleDemo` | Objective-C++, Swift bridging, login, preview, capture, playback, configuration, alarms, PTZ, and voice examples |
| Static libraries under `lib/Debug-iphoneos` and `lib/Release-iphoneos` | Shipped binary architectures and likely linker inputs |

The PDF is a 248-page guide created in January 2021. The package build name is dated June 2022. The header is therefore the stronger source for thermal interfaces added after, or omitted from, the guide.

## Package inventory

### Public headers

- `HCNetSDK.h`: the principal public API. It is approximately 51,000 lines and covers many Hikvision product families.
- `plaympeg4.h`: playback/decoding functions used when the application handles encoded stream data itself.
- `DecodeCardSdk.h` and `DataType.h`: legacy decoding support.

The demo contains a duplicate `hcnetsdk.h`; use the canonical `incEN/HCNetSDK.h` when integrating.

### Libraries

The release package includes:

- `libHCNetSDK.a`: external network SDK API;
- `libHCCore.a`: core communications/runtime;
- `libplayctrl.a`: video playback and decoding;
- `libAudioEngine.a`: audio processing;
- `libSystemTransform.a`, `libNPQos.a`, `AIP.a`, `libsip.a`;
- codec libraries including AAC and Opus;
- bundled `libssl.a` and `libcrypto.a`.

Most supplied archives contain `armv7` and `arm64` device slices. The package is not an XCFramework, and the core SDK libraries do not include an iOS Simulator slice. The OpenSSL archives also contain old simulator slices, but that does not make the complete SDK simulator-compatible.

Practical consequence: production integration should initially be tested on a physical iPhone. A simulator-compatible abstraction or mock source will be needed for normal app development and automated tests.

### Framework dependencies shown by the demo

The sample project links Apple frameworks including:

- UIKit;
- CoreGraphics;
- OpenGLES;
- VideoToolbox;
- AudioToolbox;
- AVFoundation.

The demo disables bitcode, targets old iOS versions, uses Swift 4/5-era settings, and contains obsolete build settings such as `VALID_ARCHS`. Treat its project file as a linker reference, not as a modern project template.

## How the SDK works

The SDK uses opaque integer handles and C callbacks:

1. Initialize the process-wide SDK.
2. Configure timeouts, reconnection, logs, and exception callbacks.
3. Log in to a network device and retain the returned user handle.
4. Start one or more services, such as preview, remote configuration, or alarm subscription.
5. Receive data through callbacks or SDK-managed rendering.
6. Stop each service and release its handle.
7. Log out.
8. Clean up the process-wide SDK.

Nearly all operations return either:

- `BOOL`, where failure is `FALSE`; or
- a `LONG` handle, where failure is `-1`.

Call `NET_DVR_GetLastError()` immediately after a failure. `NET_DVR_GetErrorMsg()` can provide a textual form where supported. The guide groups error numbers into network, RTSP, and decoding-library ranges.

### Lifecycle and diagnostics

| Purpose | Interface |
|---|---|
| Initialize | `NET_DVR_Init()` |
| Release global resources | `NET_DVR_Cleanup()` |
| Configure connection attempts | `NET_DVR_SetConnectTime()` |
| Configure automatic reconnection | `NET_DVR_SetReconnect()` |
| Configure receive timeout | `NET_DVR_SetRecvTimeOut()` |
| Receive disconnect/reconnect exceptions | `NET_DVR_SetExceptionCallBack_V30()` |
| Enable SDK logs | `NET_DVR_SetLogToFile()` |
| Inspect SDK version | `NET_DVR_GetSDKVersion()`, `NET_DVR_GetSDKBuildVersion()` |
| Read failure information | `NET_DVR_GetLastError()`, `NET_DVR_GetErrorMsg()` |

`NET_DVR_Init()` and `NET_DVR_Cleanup()` are global lifecycle calls. The application should put them behind one reference-counted or process-lifetime owner rather than calling cleanup whenever an individual screen disappears.

### Login and device discovery

Prefer `NET_DVR_Login_V40()` with:

- `NET_DVR_USER_LOGIN_INFO` for IP/host, port, username, password, sync/async mode, and transport options;
- `NET_DVR_DEVICEINFO_V40` for returned capabilities and channel information.

The older `NET_DVR_Login_V30()` is easier to bridge but exposes fewer options.

Channel numbering cannot be assumed to start at 1 for every device. The demo derives it from:

- `byStartChan` and `byChanNum` for analog channels; or
- `byStartDChan`, `byIPChanNum`, and `byHighDChanNum` for IP channels.

Credentials must be loaded from protected configuration or Keychain. The sample prints credentials and includes hard-coded test accounts/tokens; none of that behavior should be copied.

### Live preview: two different data paths

`NET_DVR_RealPlay_V40()` starts preview using `NET_DVR_PREVIEWINFO`.

The SDK supports two conceptually different modes:

#### SDK-managed decoding and display

Set `hPlayWnd` to a view pointer and pass no data callback. The SDK/player renders the stream into the view. This is the shortest route to an on-screen preview and is what the demo's `startPreview()` uses.

This path is good for:

- operator preview;
- camera positioning;
- connection validation.

It is not sufficient by itself for biomarker extraction because the application does not receive a calibrated thermal matrix.

#### Application-managed stream data

Pass a `REALDATACALLBACK`, or register one using:

- `NET_DVR_SetRealDataCallBackEx()`; or
- `NET_DVR_SetStandardDataCallBackEx()`.

The callback first receives a system header (`NET_DVR_SYSHEAD`) and then encoded stream packets. The demo's external-decoding example allocates a PlayM4 port, opens the stream using the header, feeds subsequent packets through `PlayM4_InputData()`, and renders with `PlayM4_Play()`.

This path is useful for:

- recording the original stream;
- custom decode and frame delivery;
- offline video analysis;
- inspecting metadata data types, including `NET_DVR_METADATA_DATA`.

Important: an encoded thermal-camera video stream may be a colorized display stream rather than a radiometric temperature stream. Pixel intensity in a palette-rendered H.264/H.265 frame must not automatically be interpreted as temperature.

Stop preview with `NET_DVR_StopRealPlay()`.

### Image capture

The SDK exposes three relevant capture levels:

| Interface | Result | Relevance |
|---|---|---|
| `NET_DVR_CapturePictureBlock_New()` | Decoded preview image in memory | Useful for displayed-frame snapshots; not necessarily radiometric |
| `NET_DVR_CaptureJPEGPicture_NEW()` | Device JPEG in caller buffer | Useful for normal device snapshots |
| `NET_DVR_CaptureJPEGPicture_WithAppendData()` | JPEG plus appended/visible data and alignment rectangles | Highest-priority interface to test for radiometric capture |

`NET_DVR_JPEGPICTURE_WITH_APPENDDATA` contains:

- thermal/display JPEG pointer, length, width, and height;
- `pP2PDataBuff` and its length;
- freeze-data indicator;
- visible-light image pointer and length;
- normalized valid rectangles for thermal and visible images.

The paired valid rectangles are valuable for aligning the thermal and visible channels. The meaning and encoding of `pP2PDataBuff`, however, are not documented in the supplied guide or header. Do not design the temperature decoder until this payload is confirmed for the exact camera model and firmware.

### Device-side thermometry

The header includes a substantial thermometry model.

#### Basic measurement configuration

Command IDs:

- `NET_DVR_GET_THERMOMETRY_BASICPARAM_CAPABILITIES` (`3620`);
- `NET_DVR_GET_THERMOMETRY_BASICPARAM` (`3621`);
- `NET_DVR_SET_THERMOMETRY_BASICPARAM` (`3622`);
- `NET_DVR_GET_THERMAL_CAPABILITIES` (`3634`).

`NET_DVR_THERMOMETRY_BASICPARAM` includes:

- enablement and display overlay flags;
- temperature range and unit;
- emissivity;
- environmental temperature and humidity;
- object distance and distance unit;
- reflected-temperature correction;
- thermal optical transmittance;
- external-window correction;
- alert/alarm values and filtering times;
- display of center, minimum, maximum, and average temperatures.

These values affect measurement validity. They are not cosmetic settings.

#### Point and region rules

Relevant commands and structures:

- `NET_DVR_GET/SET_THERMOMETRY_PRESETINFO`;
- `NET_DVR_THERMOMETRY_PRESETINFO`;
- `NET_DVR_THERMOMETRY_PRESETINFO_PARAM`;
- `NET_DVR_THERMOMETRY_COND`.

The SDK supports up to 40 thermometry regions/rules. A rule can carry normalized point or polygon geometry, distance, emissivity, reflected temperature, and a name.

The region statistics model includes:

- maximum temperature;
- minimum temperature;
- average temperature;
- temperature difference;
- hottest and coldest coordinates;
- center-point temperature.

This can be useful for a stable, device-side facial ROI, but a small moving nostril ROI will probably require application-side tracking unless the camera firmware exposes a suitable face thermometry mode.

#### Realtime thermometry

`NET_DVR_GET_REALTIME_THERMOMETRY` (`3629`) pairs with:

- `NET_DVR_REALTIME_THERMOMETRY_COND`;
- `NET_DVR_THERMOMETRY_UPLOAD`.

The condition can select a channel, rule, time/temperature-difference mode, and interval. Upload results contain point or polygon statistics, special-point temperatures and positions, timestamp, channel, face rectangle, and freeze state.

The naming and asynchronous result structure indicate that this command is intended for the generic remote-configuration flow:

- `NET_DVR_StartRemoteConfig()`;
- remote callback/status handling;
- `NET_DVR_StopRemoteConfig()`.

This mapping must be verified against the exact device's integration manual before implementation because the supplied iOS guide does not document this thermal command.

#### Thermometry alarms

Alarm command values include:

- `COMM_THERMOMETRY_ALARM` (`0x5212`);
- `COMM_THERMOMETRY_DIFF_ALARM` (`0x5211`);
- `COMM_FACE_THERMOMETRY_ALARM` (`0x4994`);
- `COMM_ISAPI_ALARM` (`0x6009`) for transmitted ISAPI event content.

Associated structures include:

- `NET_DVR_THERMOMETRY_ALARM`;
- `NET_DVR_THERMOMETRY_DIFF_ALARM`;
- `NET_DVR_FACE_THERMOMETRY_ALARM`.

Thermometry alarm payloads can include current/rule temperatures, rule geometry, thermal and visible images, thermal information buffers, and hottest-point information. Face thermometry events can include face bounds, visible/face images, and minimum/average/maximum temperature information.

The normal subscription flow is:

1. Register `NET_DVR_SetDVRMessageCallBack_V31()`.
2. Call `NET_DVR_SetupAlarmChan_V41()` or another supported arming version.
3. Parse callback data according to `lCommand`.
4. Close with `NET_DVR_CloseAlarmChan_V30()` or the matching API.

Alarm callbacks are suitable for threshold events. They are not a reliable continuous waveform source unless the firmware explicitly provides the required event cadence.

### Generic configuration and ISAPI

The SDK has three configuration styles:

- legacy `NET_DVR_GetDVRConfig()` / `NET_DVR_SetDVRConfig()`;
- structured `NET_DVR_GetSTDConfig()` / `NET_DVR_SetSTDConfig()`;
- `NET_DVR_STDXMLConfig()` for URI-based XML, JSON, or form data.

`NET_DVR_STDXMLConfig()` is the escape hatch for firmware features that have an ISAPI endpoint but no convenient C structure. Capability discovery should come before feature use. Relevant examples in the guide include `/ISAPI/System/capabilities` and access-control face-temperature event capability nodes.

Do not assume a command or endpoint is supported merely because its constant exists in `HCNetSDK.h`; the header spans many device families.

### Playback, recording, PTZ, audio, and management

The SDK also contains:

- local stream recording and remote manual recording;
- playback by time or filename and playback controls;
- file and picture search/download;
- PTZ movement and presets;
- voice talk and audio encoding/decoding;
- alarm input/output;
- remote upgrade, reboot, disk, and serial-port management;
- face library, access control, traffic, heat-map, and many unrelated product APIs.

These are available but should remain outside the first infrared biomarker milestone.

## Thermal data structures to remember

| Structure | Why it may matter later |
|---|---|
| `NET_DVR_JPEGPICTURE_WITH_APPENDDATA` | Candidate still-frame path to thermal JPEG, appended radiometric content, visible image, and alignment rectangles |
| `NET_DVR_THERMOMETRY_BASICPARAM` | Emissivity, distance, environment, reflected temperature, optical correction, range, and unit |
| `NET_DVR_THERMOMETRY_PRESETINFO_PARAM` | Point/polygon rule geometry and per-rule measurement parameters |
| `NET_DVR_REALTIME_THERMOMETRY_COND` | Subscription condition for realtime measurement results |
| `NET_DVR_THERMOMETRY_UPLOAD` | Point/region statistics, special temperatures/locations, face bounds, channel, and timestamp |
| `NET_DVR_THERMOMETRY_ALARM` | Threshold event with visible, thermal, and thermal-info buffers |
| `NET_DVR_THERMOMETRY_DIFF_ALARM` | Difference between two thermometry rules |
| `NET_DVR_FACE_THERMOMETRY_ALARM` | Face detection state, face region/images, and face temperature statistics |
| `NET_VCA_RECT`, `NET_VCA_POINT`, `NET_VCA_POLYGON` | Normalized geometry used throughout the SDK |
| `NET_DVR_PREVIEWINFO` | Channel, stream type, link mode, display view, blocking mode, and metadata flag |
| `NET_DVR_USER_LOGIN_INFO` | Connection and authentication configuration |

## Callback and memory rules

- Initialize every C structure to zero and set its `dwSize` member where present.
- Treat callback buffers as borrowed memory valid only for the callback unless the vendor explicitly says otherwise.
- Copy needed bytes before returning from the callback.
- Do not perform image analysis, disk I/O, or UI work directly inside SDK callbacks.
- Enqueue copied data onto a dedicated serial processing queue.
- Keep the callback context object alive until the associated SDK handle is stopped.
- Stop preview, remote configuration, and alarms before logout.
- Keep error reads adjacent to the failed call; later SDK calls can overwrite the last-error state.
- Normalize timestamps and track dropped or duplicated frames before spectral analysis.

## Recommended Vvewell integration

### Layer 1: Objective-C++ SDK adapter

Create a narrow Objective-C++ wrapper around the C header and static libraries. It should expose only:

- initialize/shutdown;
- login/logout;
- start/stop preview;
- start/stop radiometric capture or realtime thermometry;
- thermometry configuration;
- typed connection/error events.

Do not expose raw SDK structures across the Swift boundary.

### Layer 2: Swift concurrency boundary

Wrap the adapter with a single serialized owner, such as an actor or a dedicated dispatch queue. Model handles as explicit session objects:

- `InfraredDeviceSession`;
- `InfraredPreviewSession`;
- `InfraredThermometrySession`.

Make teardown idempotent. Never let a view controller own global SDK cleanup.

### Layer 3: normalized frame model

Convert vendor output into an application-owned type such as:

```swift
struct ThermalFrame {
    let timestamp: ContinuousClock.Instant
    let width: Int
    let height: Int
    let temperaturesCelsius: [Float]
    let displayImage: CGImage?
    let visibleImage: CGImage?
    let thermalValidRect: CGRect
    let visibleValidRect: CGRect
    let calibration: ThermalCalibration
}
```

Only populate `temperaturesCelsius` after the vendor payload format and calibration have been verified.

### Layer 4: biomarker pipeline

Keep health interpretation independent of the SDK:

1. face/nose/nostril detection;
2. ROI tracking and confidence scoring;
3. temperature-signal extraction;
4. motion and drift rejection;
5. filtering and breath-event detection;
6. rate/quality calculation;
7. validation and storage.

This separation permits prerecorded test fixtures and a simulator implementation without linking the proprietary SDK.

## First implementation spike

The smallest useful device experiment is:

1. Link only the minimum required SDK libraries in a physical-device test target.
2. Initialize and print the SDK/build versions.
3. Log in using `NET_DVR_Login_V40()`.
4. Query thermal capabilities.
5. Start an SDK-rendered preview to confirm channel selection.
6. Call `NET_DVR_CaptureJPEGPicture_WithAppendData()`.
7. Record lengths, dimensions, valid rectangles, and the first payload signatures without logging credentials or personal imagery.
8. Start realtime thermometry if the device reports support.
9. Configure one small point/region and compare reported values with the captured frame.
10. Stop all handles, log out, and clean up.

This spike answers the blocking questions before building any UI or biomarker model.

## Risks and unresolved questions

### Must resolve with the exact camera

- Exact device model, firmware version, thermal sensor resolution, frame rate, and spectral range.
- Whether the camera provides true per-pixel radiometric data over this iOS SDK.
- Binary layout and endianness of appended P2P/thermal-info buffers.
- Whether visible and thermal streams are synchronized and how their valid rectangles map.
- Which channel number represents thermal, visible, and fused output.
- Supported thermometry ranges and face-thermometry modes.
- Whether realtime thermometry can report at a cadence adequate for respiration.
- The effect and cadence of flat-field correction/freezing on the time series.

### Build and maintenance risks

- Old static-library packaging, no XCFramework, and no complete simulator slice.
- Large legacy C header and Objective-C++ bridging requirement.
- Bundled OpenSSL/codec versions may be old and should be reviewed before production distribution.
- The demo uses deprecated APIs, manual signing, embedded credentials, and obsolete build settings.
- The package does not include a clear SDK license file in the inspected directory; redistribution rights must be confirmed.
- Newer iOS/Xcode compatibility is unproven until a physical-device link and run succeeds.

### Health-product risks

- Thermal values are sensitive to emissivity, distance, ambient temperature, humidity, reflected temperature, optical windows, sensor drift, and motion.
- A valid-looking waveform does not establish clinical accuracy.
- Face and thermal video are sensitive health/biometric data and require explicit privacy, retention, access, and consent design.
- Any user-facing vital sign needs signal-quality output, failure states, reference-sensor validation, and carefully scoped claims.

## Working checklist for future SDK tasks

- Confirm branch and target before adding proprietary binaries.
- Keep the SDK package outside Git unless redistribution is authorized.
- Prefer `NET_DVR_Login_V40()`.
- Query device capabilities before selecting a thermal command.
- Distinguish rendered video from radiometric temperature data.
- Test `NET_DVR_CaptureJPEGPicture_WithAppendData()` early.
- Verify all thermal payload formats with model-specific documentation.
- Zero structures and set `dwSize`.
- Copy callback data immediately and process it off-callback.
- Preserve timestamps and quality metadata.
- Stop service handles before logout and cleanup.
- Never log passwords, tokens, raw faces, or thermal health frames.
- Develop biomarker algorithms against a vendor-neutral `ThermalFrame`.
- Validate on a physical device; use mocks on the simulator.

