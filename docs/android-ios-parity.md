# Android to iOS parity ledger

Source baseline: `vvewell-physical-ai-2026/alloop-SDK`
iOS target: `vvewell-physical-ai-2026-ios`
Infrared decision: intentionally skipped because the 0728 manufacturer package is incomplete.

This is the implementation checklist and acceptance ledger for the native iOS rewrite. A row is only marked aligned after its navigation, visible state, and primary interaction have been exercised on iOS. "Native" means the iOS repository contains a usable implementation or vendor binary. "Protocol" means the Android source exposes enough BLE protocol detail to implement the equivalent with CoreBluetooth. "UI only" means there is no usable iOS SDK or public protocol in the supplied sources.

## App shell and home

| Surface | Android appearance and behavior | iOS gap before this pass | iOS target | Support | Status |
| --- | --- | --- | --- | --- | --- |
| Splash | Branded Vvewell splash and automatic route into the five-tab shell | Native launch screen differs | Match mark, background, and transition | Native | Aligned |
| Main tabs | Home, Health, Chat, Medical, Profile with green active state | Tab order was aligned, but icon sizing and labels differ | Match order, labels, active tint, and navigation behavior | Native | Aligned |
| Home header | Vvewell brand, active family member, language and cloud-sync actions | Greeting-first header without equivalent controls | Add brand, profile switch, language, and sync affordances | Native | Aligned |
| Interactive panda coach | Large animated panda; normal, happy, warning, completed boost, sleepy, inactive, stressed, and recovery states; speech bubble and task actions | One static panda image in a compact card; no bubble or interactions | Use the Android panda state assets, animated playback, task completion/snooze/decline, scenario state changes, and health-derived status | Native | Aligned |
| Health rings | Animated nested health indices with legend and deltas | One static score ring | Match multi-ring display, legend, and score transitions | Native | Aligned |
| Risk and data state | Loading, fallback, risk priority, retest, and system status rows | Always-normal static status | Implement loading/fallback/risk/status states | Native | Aligned |
| Basic health summary | Compact heart rate, SpO2, temperature/stress and related metrics | Separate legacy overview lower on page | Put the same compact metrics directly below coach | Native | Aligned |
| Quick entries | Devices, phone rPPG, medical, health record, nutrition, infrared | Different labels/actions; infrared was still represented in legacy code | Match entries except replace infrared with an explicitly unavailable row; never initialize it | Native except infrared | Partial |
| Connected-device banner | Shows connected family/count and opens device center | Static ring-oriented banner | Drive from all registered/connected iOS device families | Native/protocol | Aligned |
| Recommendations | Health-tag-driven recommendation cards/catalog | Generic static article cards | Match recommendation hierarchy and filtering using local data | Native | Partial: cards now route to chat/medical flows; health-tag filtering remains local-native |
| Reminders | Coach tasks and reminder state feed panda behavior | Separate static reminder cards | Connect reminder actions to coach state | Native | Aligned |

## Device center and BLE entry points

| Surface/device | Android appearance and behavior | iOS gap before this pass | iOS target | Support | Status |
| --- | --- | --- | --- | --- | --- |
| Device center | Branded device overview, connected cards, one-tap check, scan/add, supported-device catalog and shopping entries | Ring-centric list with generic discovery button | Match sections and provide an entry for every Android family | Native | Aligned |
| Unified scan | Animated radar, connected devices, type filters, discovered cards, scan/stop, correct detail routing | Generic radar scan limited to ring/watch/band registry | Add family filters and route each result to its own detail page | Native/protocol | Aligned |
| Alloop Ring | Dashboard, battery/status, trends, one-tap measurement, algorithm verify, history sync/debug | Real RingSDK detail, check, settings, ECG, glucose, emotion, sleep, sport and OTA exist but use a different hierarchy | Preserve real RingSDK and add Android-equivalent dashboard/verify/history entry hierarchy | Native vendor frameworks | Partial |
| AIZORING | Detail, instant heart rate/SpO2/temperature/stress/UV, continuous PPI, health history, sleep and ECG | No AIZORING-named GUI entry; equivalent ring capabilities exist under generic RingSDK screens | Add AIZORING entry and route supported operations to RingSDK services without claiming unsupported equivalence | Native vendor frameworks | Partial |
| Xiaozhi health assistant | BLE connect, Wi-Fi scan/provision, compatible commands, text, listen controls, proactive greetings, MCP tools | No entry or BLE implementation | Add discover/connect and control screen; enable commands only when a compatible iOS transport/profile is known | Source-dependent | Explicitly unavailable: no supplied iOS transport/profile |
| vvewell Robot | BLE connect, expression panel, SG90 angle and power control | No entry or implementation | Implement CoreBluetooth using service `D6F00001`, RX `D6F00002`, TX `D6F00003`; match controls | Protocol | Aligned |
| JDY-23 radar | BLE connect, wake/start/stop, I/Q vitals, point cloud, bin config, CSV export and advanced HIF | No entry or implementation | Implement CoreBluetooth FFE0/FFE1 transport and expose safe controls; port parser/estimator where source permits | Protocol plus Android bridge source | Aligned |
| Rokid glasses | Companion app authorization, CXRLink session, status and device info | No entry; supplied Rokid integration is Android-only | Add catalog/detail entry that clearly reports iOS SDK unavailable; do not simulate a connection | UI only | Explicitly unavailable: no supplied iOS CXRLink SDK |
| Phone rPPG | Camera measurement with progress/result | Existing native rPPG/health check flow is reached through differently named shortcuts | Add matching device-center and home entry and align copy/state | Native | Partial |
| Infrared camera | Android camera connection and thermal page | Manufacturer iOS package for the 0728 branch is incomplete; stale source remains excluded from the target | No active scan, route, SDK initialization, or claim of support; show unavailable reason only where catalog parity requires it | **UNAVAILABLE** | Intentionally skipped |

## Ring dashboards and diagnostics

| Android page | Required iOS destination | Existing iOS capability | Status |
| --- | --- | --- | --- |
| Alloop device detail | Ring dashboard with connection, battery, measurement and trend actions | `RingDetailViewController`, `RingCheckViewController` | Partial |
| SpO2 algorithm verification | Live SpO2, PPG and accelerometer verification view | Ring measurement/original data services exist; raw PPG/ACC verification stream is not exposed by the supplied iOS framework | Partial: live measurement/trends routed; raw verification explicitly unavailable |
| History sync debug | Device status, progress, clear/sync and result list | Ring health/sleep stores exist; Android batch history API is not exposed by the supplied iOS framework | Partial: local trends routed; batch sync/export explicitly unavailable |
| AIZORING instant measurement | Type selector and live progress/result | `RingHealthService` and ring check UI | Partial |
| AIZORING health history | Date selection, local/ring records and sync | `RingHealthService`, `HealthMetricStore` | Partial |
| AIZORING sleep | Date selection and stages/summary | `RingSleepService` | Partial |
| AIZORING ECG | Wear hand, waveform, start/stop and diagnosis | `RingECGService`, `ECGViewController` | Partial |

## Health, chat, and family

| Surface | Android appearance and behavior | iOS gap before this pass | iOS target | Status |
| --- | --- | --- | --- | --- |
| Health tab | Health score, trends, women health, records, report OCR and family context | Rich native health dashboard and OCR already exist but hierarchy/copy differ | Reorder/label to Android hierarchy while retaining extra native functionality | Partial |
| Women health | Cycle-aware panel and record state | No equivalent visible panel | Add panel and local state entry | Aligned |
| Medical report OCR | Upload/camera, parse, store and history; Android includes embedded demo credential fallback | Native OCR upload/history exists with different fallback plumbing | Align entry and state copy; keep credentials out of UI | Partial |
| Family member switcher | Home header selector; member management, authorization, add/switch and health record | Native profile manager and family screen exist but are not surfaced the same way | Add home selector and matching routes | Partial |
| Health record | Member overview, tags, health data, confirm/complete profile | Native health/profile screens split across controllers | Add a coherent Android-equivalent entry and route | Partial |
| Chat tab | Topic pills (健康咨询/报告咨询/营养顾问/睡眠助手), per-topic welcome with member-personalized subtitle, context card with health tags, upload-report action and suggestion cards; routing uses the real AI backend with topic context prefixed to the outgoing message | Native symptom chat/history/attachments exist but no topic layer | Add topic strip above the chat scroll view plus per-topic welcome card; preserve streaming/history/attachments | Aligned |

## Medical and nutrition

| Surface | Android appearance and behavior | iOS gap before this pass | iOS target | Status |
| --- | --- | --- | --- | --- |
| Medical hub | Header/profile context; recommended service; one primary service; candidate medical resources; coverage-gap analysis; protection plans; community feed | Three generic cards only | Rebuild the tab with the Android sections and route existing Global Care flows from the relevant actions | Aligned |
| Expert consultation | Specialist/global expert option and service selection | Covered indirectly by Global Care application | Add explicit card and route | Aligned |
| Special examination | Diagnostic/specialist examination coordination | No direct entry | Add service option and order context | Aligned |
| Global referral | Cross-border referral coordination | Existing Global Care flow | Add explicit card and route | Aligned |
| Insurance analysis | Separated critical illness/medical/accident gaps and candidate plans | No equivalent tab section | Add read-only analysis and plan actions using local demo model | Aligned |
| Patient community | Topic chips, feed, safety framing and actions | No equivalent | Add local feed and interactions | Aligned |
| Nutrition center | Daily supplement check-ins, meal capture, AI adviser, plan cards, intake, supplement catalog/cart | Generic native nutrition mall | Build Android section hierarchy; reuse camera/photo picker and local persistence | Aligned |

## Profile and service pages

| Surface | Android appearance and behavior | iOS gap before this pass | iOS target | Status |
| --- | --- | --- | --- | --- |
| Profile home | Identity/level, orders, benefits, devices, family, reports, notification/language/settings rows | Similar profile shell but several rows have no matching destinations | Align row grouping, order, labels and routes | Partial |
| Orders | Segmented status filter and order cards/actions | No matching page | Add native page with the Android demo order states | Aligned |
| Benefits | Level/points, benefits, daily tasks and point history | No matching page | Add native page and local task interactions | Aligned |
| Notification settings | Master switch, health/device/family/order/community toggles and do-not-disturb range | No matching detailed page | Add persisted native settings | Aligned |
| Language settings | Chinese/English segmented choice | Language sheet supports more languages, not Android layout | Add Android-equivalent settings page while preserving supported languages | Aligned |

## SDK and integration disposition

| Dependency/integration | Android | iOS target disposition |
| --- | --- | --- |
| `alloop_blue_lite` | Local Flutter plugin with Android implementation | Do not embed the Android plugin. Use supplied arm64 `RingSDK.framework` through existing native services. |
| `aizoring_blue_lite` | Local Flutter plugin with Android implementation | Do not claim the Android plugin runs on iOS. Map only operations demonstrably provided by the supplied iOS ring frameworks. |
| RingSDK / glucose / FOTA | Android dependencies hidden behind plugins | Supplied `RingSDK.framework`, `EiotGluSdk.framework`, and `AB_FOTA.framework`; already integrated for device arm64. |
| Robot | Android native GATT bridge | Port known GATT profile and UTF-8 command transport to CoreBluetooth. |
| Radar | Android native JDY-23 GATT plus radar parser/bridge | Port FFE0/FFE1 transport; port source-owned decoding where feasible. |
| Xiaozhi | Android BLE plugin/command service | Implement only protocol operations backed by supplied source; unsupported MCP/Wi-Fi transport must remain visibly disabled, not faked. |
| Rokid | Android proprietary CXRLink integration | No supplied iOS SDK. Provide an honest unavailable state and installation guidance only if an iOS companion URL is known locally. |
| Infrared/HikMicro | Android thermal bridge; incomplete iOS 0728 vendor package | Excluded from compilation and runtime by explicit user direction. |
| Cloud sync | Flutter Supabase service with embedded encrypted demo credentials | Reuse native relay/profile sync. Do not copy credentials across platforms. |
| OCR | Flutter remote OCR with embedded encrypted demo credential fallback | Reuse native OCR pipeline and its existing development fallback policy. |

## Explicit dirty hacks to preserve and label

These behaviors are part of the Android prototype and must remain recognizable during parity work rather than being silently presented as production integrations.

1. **DIRTY HACK - panda scenarios:** Android's avatar coach is driven by `MockAvatarCoachService` and scenario fixtures. The iOS scenario switcher must be labeled in source and accessibility metadata as demo/mock behavior.
2. **DIRTY HACK - recommendation/demo commerce data:** Android recommendations, orders, benefits, insurance candidates, community feed, and nutrition catalog use local fixtures. iOS must keep fixture factories separate and mark them `DIRTY HACK: Android parity demo data` in source.
3. **DIRTY HACK - OCR/cloud fallback:** Android includes embedded encrypted demo credentials. iOS keeps its existing development fallback policy but must not copy or expose Android secrets.
4. **DIRTY HACK - simulator devices:** iOS registers mock ring/watch/band devices in the simulator. Keep this for visual and navigation tests and retain the explicit simulator notice.
5. **UNAVAILABLE - infrared:** thermal source files remain in the repository for later vendor-package recovery but stay excluded from the Xcode target. No mock thermal readings or fake connection may be shown.
6. **UNAVAILABLE - proprietary SDK gaps:** Rokid and any Xiaozhi operation without a supplied iOS SDK/protocol must be disabled with a concrete reason. A disabled but honest entry is preferable to a false success state.

## Acceptance criteria

- Every Android route above has an iOS entry point, equivalent native screen, or explicit unavailable state justified by a missing proprietary iOS dependency.
- The first home viewport visually follows Android: Vvewell header, interactive panda/bubble, health rings, status, basic metrics, then quick entries.
- Device center and unified scan expose all supported iOS families and never route every result to the ring page.
- Ring operations use the real supplied iOS frameworks on a physical arm64 device.
- Robot and radar scans use their documented BLE identifiers and do not manufacture connected state.
- Infrared code is not linked or initialized.
- Mock/demo paths are marked `DIRTY HACK` in source.
- Tests pass, signed device build succeeds, and the app is installed and launched on EifonOreo.
