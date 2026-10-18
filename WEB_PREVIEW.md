# vvewell Web preview

Live URL: https://vvewell-web-preview-357361255240.asia-east1.run.app

Google Cloud project: `claw-wendy`; Cloud Run service: `vvewell-web-preview`; region: `asia-east1`.

## Scope

This is a Flutter Web adaptation of the existing panda app, not a rewrite. The original sample health data, five primary tabs, family pages, service catalogs, orders and membership demonstrations remain in place. The preview banner identifies the sample data. Hardware routes retain their entry points and show the browser limitation and record/report view; direct Bluetooth, radar, thermal-camera and native rPPG measurements require the mobile app.

Doctor recommendations are integrated into the primary Chat tab, alongside Reports, Nutrition, Medication, Health and Sleep. The Home shortcut selects that same Chat workspace, preserving the doctor conversation; `/find-doctor` opens the complete app shell at Chat. It uses the updated 878-doctor catalog (11 hospitals with doctors), conversational follow-up questions and SSE progress through `/api/chat/stream`. Cards use English labels and romanized physician names; original Chinese catalog names are retained only in backend metadata. Physician romanization may differ from their preferred English spelling. Districts are English and original expertise paragraphs are omitted. The doctor chat restores Patient age, Sex at birth and Current country immediately above the message input. The optional age/sex inputs are validated and passed to the agent, so patients do not have to repeat them in the conversation. The country selector offers 30 commonly used countries in English A–Z order, with Other last. It defaults to Other, never infers the user’s location, and sends the explicit selection to the backend for country-specific emergency guidance. AI replies are instructed to use English. Hospital filtering and exclusion of previously displayed doctors are retained. The recommendation module calls Google Vertex AI Express using `gemini-3.5-flash`. General health-record consultation and OCR retain their existing Gemini-compatible provider so the new text adapter cannot break image uploads. No model API key is included in Flutter assets. AI preview endpoints allow public trial use with a process-wide limit of 20 requests per minute and at most two concurrent AI requests; the Cloud Run service has a maximum of one instance. The new chat routes additionally enforce 12 requests/minute and 200/day per IP and a 64 KiB body limit. These counters are in memory and reset on instance restarts. These limits are prototype safeguards, not a billing budget guarantee. Recommendation patient logs are disabled.

Nutrition capture retains the original mock-analysis workflow and uses browser image bytes instead of native File paths. Browser-created sample meal and cycle records are kept for the current preview session. Medical-report upload supports real OCR through the backend, or the explicitly identified sample-report workflow. Without a linked private profile, extracted reports remain in the session and are not saved to another user's cloud profile.

Private cloud-data APIs still require a valid Supabase user session. The optional real-profile interface and additive migration `cloud_db/migrations/0016_web_preview.sql` are separate from the demonstration preview. The migration has NOT been applied: both supplied management tokens were rejected and direct database access was unavailable. This does not block browsing the sample app or trying AI.

## Source

- `alloop-SDK/lib/main_web.dart`: browser entry point, routes and preview banner.
- `alloop-SDK/lib/features/main/home_page.dart`: original five-tab UI and added doctor-search entry.
- `alloop-SDK/lib/features/doctor_recommendation/`: reused doctor-search Flutter page.
- `alloop-SDK/lib/web/`: browser HTTP, report upload and hardware record adapters.
- `web_backend/server.py`: same-origin static hosting, AI proxy and private-data boundaries.
- `web_backend/doctor_v2/`: updated conversation agent, Google model adapter, recommendation tools, English presentation and catalog copied from the updated ZIP. The older recommendation code remains only for compatibility and the existing OCR/health-consult integration.
- `doctor-recommendation/`: recommendation logic and physician directory from the supplied ZIP.
- `Dockerfile`, `.dockerignore`, `.gcloudignore`, `web_deploy/`: reproducible build and deployment.

The work is isolated in Git worktree `web-preview`, branch `codex/web-preview`. The original `Android` checkout is separate.

## Local build

```sh
cd github-upload
ENV_FILE="$PWD/.env" ./web_deploy/build.sh
ENV_FILE="$PWD/.env" PORT=4190 python3 web_backend/server.py
```

Open http://127.0.0.1:4190 . The build excludes embedded demonstration cloud/OCR credential bundles and scans the public assets for private environment values.

## Tests

```sh
cd alloop-SDK
flutter test test/web_preview_test.dart test/web_home_browser_test.dart test/web_workflows_browser_test.dart test/doctor_chat_browser_test.dart test/chat_workspace_browser_test.dart test/doctor_country_selector_test.dart test/doctor_english_display_test.dart test/web_english_render_test.dart --platform chrome
flutter test test/avatar_coach/home_page_test.dart test/medical_ocr_service_test.dart
cd ..
python3 -m unittest discover -s web_backend/tests
python3 -m unittest discover -s doctor-recommendation/2-推荐逻辑/tests
```

Browser tests cover the five primary tabs, session cycle recording and meal photo preview/confirmation using an in-memory picker. The operating-system file chooser and physical hardware have not been tested by these automated tests.

## Publish an update

After building and verifying `.web-dist`, deploy with the installed `gcloud` CLI:

```sh
gcloud run deploy vvewell-web-preview --source=. --project=claw-wendy --region=asia-east1 --no-traffic --tag=preview-update
# After verifying the tagged revision, explicitly route to the new revision.
gcloud run services update-traffic vvewell-web-preview --to-latest --project=claw-wendy --region=asia-east1
```

The first deployment created the runtime service account `vvewell-web-runtime` and the Secret Manager secret `vvewell-web-gemini-api`. The runtime account has accessor permission on that secret. The updated recommendation credential is in the separate `vvewell-web-google-api` secret, exposed to the backend as `GOOGLE_API`; `DOCTOR_GEMINI_MODEL` is independent of the old `GEMINI_MODEL`. Model credentials remain in Secret Manager; the Supabase management token, database password and service-role key are not deployed. Subsequent deployments retain the existing service configuration and secret binding.

To stop serving the preview without deleting code or data, use the Google Cloud console to restrict service access. To remove the service when no longer needed, delete `vvewell-web-preview` in Cloud Run; the model credential secret is managed separately.

## Recommendation update validation

Deterministic catalog, hospital filtering, doctor exclusion, urgent-keyword handling, HTTP/SSE validation and OCR compatibility tests are in `web_backend/tests/test_doctor_v2.py`. Browser tests use an injected streaming HTTP client to exercise progress, bilingual cards, conversation history and displayed-doctor IDs. Real Google calls have returned follow-up questions and recommendation cards; response times vary and the ZIP performance figures are not guarantees. Clinical accuracy and the full danger-evaluation dataset have not been independently revalidated.

The initial recommendation update was validated on revision `vvewell-web-preview-00004-bis`: health reports 878 doctors; real Google SSE requests restricted to HKU Shenzhen returned two doctors, then two additional doctors without repetition (6.5 s / 5.1 s in this run). The urgent-keyword response, private-path rejection and legacy health consultation also passed on that revision before traffic promotion.

The Chat integration and English adaptation passed 13 Chrome tests, 22 existing interface/report tests and 24 backend tests. The Chrome checks cover the 390px integrated workspace, report/nutrition/medication entry points, country selection, English cards and the visible text on all five primary tabs. Existing English interface tests also passed at 320px. A real Google request using Chinese input and the selected Japan country returned English text and English display cards. Original Chinese user-entered content and report source material are not rewritten.

The integrated English Chat release was validated on revision `vvewell-web-preview-00006-fig`. The deployed JavaScript matches the tested release bundle by SHA-256. Live requests verified Japan → 119, Other → local emergency number, and Chinese input → English reply and romanized physician names (5.9 seconds for the recommendation in this check).

## Final UI corrections

Revision `vvewell-web-preview-00009-ven` includes removal of the Web header language switch, restored bottom Patient age / Sex at birth / Current country controls, and 30 practical countries in English A–Z order with Other last. Insurance and Peer community pages, their dialogs and forms, and Home recommended-reading titles, summaries and personalized tags now use English display translations. Original catalog values, demo data and user-authored community content are preserved. English community search matches translated display values.

Validation: 9 combined Chrome UI tests passed (including insurance, community, referral, reading, form controls and country ordering), plus 27 backend tests; the independent Care regression suite passed all 4 VM tests. The staged release JavaScript matched the tested build by SHA-256. A live request with age/sex/country only in the form fields returned English doctor recommendations for 3 hospitals in 5.1 seconds. Explicit traffic promotion is required after deploying a new tagged revision because the service uses revision-pinned traffic.

The single-row correction is deployed as `vvewell-web-preview-00011-goj`. Age, sex at birth and country remain on one bottom row at 320px and 390px; the compact country popup uses the available viewport width. The introductory badge block and fixed Shenzhen wording were removed from the entry UI and progress messages. Hospital proper names and the underlying catalog remain unchanged. Verification includes 3 focused Flutter tests, 27 backend tests, the built-bundle scan, a real 390px Chrome screenshot and public-bundle SHA-256 verification after explicit traffic promotion.

The chat-layout alignment release is `vvewell-web-preview-00013-vab`. Doctor, Reports, Nutrition, Medication, Health and Sleep use `features/main/chat_composer.dart` for the same docked message input and send button. The doctor welcome header, spacing, suggestion cards and message bubbles follow the existing Chat theme; welcome content hides once the conversation starts. Doctor-specific age/sex/country controls remain on one row above the shared input. Validation: 19 Flutter regression tests and 5 Chrome checks passed, including exact message-input vertical alignment across Doctor and Reports, 320px/390px patient-row geometry and doctor streaming/history. A real 390px browser screenshot is at `output/playwright/doctor-shared-layout-390.png`.
