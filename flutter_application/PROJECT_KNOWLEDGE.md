# Bills Reimbursement (ExpenZ) — Project Knowledge

> Persistent reference compiled from a one-time full traversal of the repo.
> Keep this in sync when meaningful changes are made; do not re-traverse from scratch each request.
>
> **Cross-cutting rule:** every feature/requirement applies to BOTH Android and Web targets.
> When implementing, always handle `kIsWeb` branching, `dart:html` vs `dart:io`, multipart
> files (`bytes` for web, `path` for mobile), and verify on both platforms before declaring done.

---

## 1. Repository Layout

```
bills_reimbursement/
├── flutter_application/      # Cross-platform frontend (Android + Web; iOS/macOS/Windows scaffolding present but Android+Web are the supported targets)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # bill_model.dart, user_model.dart
│   │   ├── screens/          # login_screen, user_dashboard, admin_dashboard, add_bill_screen
│   │   └── services/         # api, notification, connectivity, compression, ocr, excel, image, offline_queue, bill_download_*, bill_file_cache
│   ├── android/              # AndroidManifest, build.gradle.kts (compileSdk 36, BCrypt, FCM via google-services)
│   ├── assets/               # icon/app_icon.png, images/{splash_icon, branding_expenz}.png
│   ├── pubspec.yaml          # Flutter deps (see §3)
│   ├── flutter_native_splash.yaml
│   └── .env                  # API_BASE_URL (dev override)
└── spring_backend/           # Java 21, Spring Boot 3.4.x, MySQL, Redis, Firebase Admin SDK
    ├── src/main/java/com/example/bills_reimbursement/bills_reimbursement/
    │   ├── BillsReimbursementApplication.java   (@EnableScheduling)
    │   ├── configs/          # SecurityConfig, FirebaseConfig
    │   ├── controllers/      # UserController, AdminController, BillController, FileController
    │   ├── dtos/             # User (JPA + UserDetails), Bill (JPA), UserResponseDTO
    │   ├── repositories/     # UserRepository, BillRepository
    │   └── services/         # CustomUserDetailsService, EmailService, FCMService, FileStorageService, OtpService, DataCleanupScheduler
    ├── src/main/resources/
    │   ├── application.properties   # all values via env vars
    │   └── firebase-service-account.json   # optional; FCM disabled silently if absent
    ├── pom.xml
    ├── uploads/              # bill files saved here on disk
    └── .env                  # DB/SMTP/CORS secrets
```

---

## 2. Stack & Versions

| Layer       | Tech                                                                 |
|-------------|----------------------------------------------------------------------|
| Frontend    | Flutter (Dart SDK ^3.9.2), Material 3                                 |
| Targets     | **Android (native)** + **Web (browser)** — primary; iOS = web PWA only |
| Backend     | Java 21, Spring Boot 3.4.11-SNAPSHOT, Spring Security, Spring Data JPA |
| DB          | MySQL (`spring.jpa.hibernate.ddl-auto=none` — schema is **not** auto-managed) |
| Cache       | Redis (localhost:6379) — used for OTP storage / rate limiting          |
| Notifications | Firebase Cloud Messaging (Admin SDK on backend, firebase_messaging on Flutter) |
| Email       | Spring Mail (Gmail SMTP, STARTTLS port 587)                           |
| Auth        | HTTP Basic Auth (BCrypt-hashed passwords) — credentials sent on every request |

App display name: **ExpenZ**. Android applicationId: `com.example.bills_reimbursement`. Backend port **8081** (note: README says 8080 but actual default is 8081; the `.env` `API_BASE_URL` overrides this entirely).

---

## 3. Flutter Dependencies (pubspec.yaml)

Notable: `cupertino_icons`, `path`, `image_picker`, `path_provider`, `intl`, `shared_preferences`, `excel`, `permission_handler`, `file_picker`, `file_saver`, `http`, `google_mlkit_text_recognition` + `google_mlkit_commons` (OCR — mobile only, not used on web), `flutter_native_splash`, `table_calendar`, `pdf`, `printing`, `flutter_dotenv`, `open_filex`, `flutter_image_compress`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`. Dev: `flutter_launcher_icons`, `flutter_lints`.

Assets registered: `assets/images/`, `assets/icon/`, `.env`.

---

## 4. Backend — REST API

Base URL is configured via `API_BASE_URL` build env / `.env`. Default in code: `http://192.168.102.150:8081`. Production `.env` example: `http://182.18.144.7:8000`.

### 4.1 Auth & roles
- HTTP Basic on every request. Username = `employeeId`, password = plaintext password. `User implements UserDetails`; `getAuthorities()` returns `ROLE_ADMIN` if `isAdmin`, else `ROLE_USER`. `isEnabled()` returns `!isDisabled` so disabled accounts are rejected at filter level with custom 401 message.
- Public endpoints: `POST /users` (signup), `POST /users/{id}/send-otp`, `POST /users/{id}/verify-otp`, `POST /users/{id}/update-password`, `GET /admin/ping`, all `OPTIONS`.
- Authenticated user-scoped: `/users/{employeeId}/bills/**`.
- Admin-only (ROLE_ADMIN): `GET /admin/bills`, `PUT /admin/bills/*/status`, `GET /admin/users`, `PUT /admin/users/**`, `PATCH /admin/users/**`, `DELETE /admin/users/**`.
- CORS: `*` origin patterns, `*` headers, all methods, `allowCredentials=false` (because credentials=false + `*` origins is allowed).
- Custom `AuthenticationEntryPoint` returns JSON `{ "error": "<msg>" }` with 401. Disabled accounts get `"Your account has been disabled. Please contact the administrator."`.

### 4.2 Endpoints

#### `/users` (UserController)
| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/users` | none | Signup. Body: `{employeeId, name, email, password, admin, fcmToken?}`. Email **must** end in `@axeno.co`. Saved with `isApproved=false`. Sends FCM "New Approval Request" to all admins. Returns 201 or 409 if id taken. |
| GET  | `/users/{employeeId}` | basic | Fetch user. Caller must be admin OR same `employeeId`. Returns `UserResponseDTO` (no password, no fcmToken). |
| POST | `/users/{employeeId}/send-otp` | none | Form fields `email`, `signUp`. For signup: rejects if email already in use. For reset: looks up email by employeeId. Rate-limited via Redis (max 3/5min, 30s cooldown). Returns `"OTP sent."` text or 429. |
| POST | `/users/{employeeId}/verify-otp` | none | Form fields `otp`, `signUp`. Returns `"OTP Verified."` or 400. Marks key `<id>_SIGNUP` or `<id>_RESET` verified for 5 min in Redis. |
| PATCH| `/users/{employeeId}/fcm-token` | basic (self) | Body `{fcmToken}`. Stores token on user row. |
| POST | `/users/{employeeId}/update-password` | none | Form field `newPassword`. Requires prior verified OTP under `<id>_RESET` key. BCrypt-hashes and saves. Clears verification flag. |

#### `/users/{employeeId}/bills` (BillController)
| Method | Path | Purpose |
|---|---|---|
| GET  | `/users/{id}/bills` | List user's bills sorted by `date DESC`. Caller must be admin or self. |
| POST | `/users/{id}/bills` | Multipart: `reimbursementFor`, `description?`, `amount`, `date` (yyyy-MM-dd), `billImage` (required), `approvalMail?`, `paymentProof?`. For non-Parking categories, `approvalMail`, `paymentProof`, and `description` are **required** (returns 400 otherwise). Status set to `"Pending"`, `createdAt = today`. Rejected with 403 if user not approved or disabled. Returns 201 + `{message, id}`. |
| GET  | `/users/{id}/bills/{billId}` | Fetch one bill (must belong to id). |
| PUT  | `/users/{id}/bills/{billId}` | Edit. Cannot edit `APPROVED` or `PAID` bills (400). Status reset to `"Pending"` on edit. Replacing a file deletes the old one from disk. |
| DELETE | `/users/{id}/bills/{billId}` | Delete. Cannot delete `PAID` (400). Removes all files from disk. |

#### `/admin` (AdminController)
| Method | Path | Purpose |
|---|---|---|
| GET  | `/admin/users` | All users sorted by name ASC, returned as `UserResponseDTO[]`. |
| DELETE | `/admin/users/{id}` | Delete user + all their bills + all uploaded files from disk. |
| PUT  | `/admin/users/{id}` | Edit name/email/approved. Email must end `@axeno.co`. On approval-flip, sends FCM "Account Approved 🎉". |
| PATCH | `/admin/users/{id}/disable` | Body `{disabled: bool}`. On disable, sends FCM "Account Disabled". |
| GET  | `/admin/bills` | All bills sorted by `date DESC`. |
| PUT  | `/admin/bills/{billId}/status` | Body `{status, remarks?}`. Rules: cannot mark PAID unless currently APPROVED; cannot change a PAID bill. On REJECTED → FCM with remarks. On PAID → FCM "Bill Paid ✅". Status uppercased on save. |
| GET  | `/admin/bills/cleanup/count` | Count of bills with `createdAt < cutoff`. Cutoff = April 1 of (currentFYStart-2). FY runs Apr 1 – Mar 31. |
| DELETE | `/admin/bills/cleanup` | Delete those old bills + files. |
| POST | `/admin/cleanup-reminder/trigger` | Manual trigger of yearly reminder (only emails if count > 0). |
| POST | `/admin/cleanup-reminder/test` | Same but always emails (config test). |
| POST | `/admin/cleanup-reminder/smtp-test` | Body `{email}` — raw SMTP test, bypasses bill logic. |
| GET  | `/admin/ping` | Public health-check used by Flutter `ConnectivityService`. |

#### `/files` (FileController)
| Method | Path | Purpose |
|---|---|---|
| GET | `/files/{filename}` | Serves a file from `uploads/`. Hardcoded `Content-Type: image/jpeg` regardless of actual type — **known limitation**, PDFs/PNGs are still served as `image/jpeg`. Authenticated (falls under `anyRequest().authenticated()`). |

### 4.3 Domain models (JPA)

**User** (`users` table) — `@Id employeeId Integer`, `name`, `email`, `password` (BCrypt), `isAdmin`, `isApproved`, `isDisabled`, `fcmToken` (write-only on JSON, never serialized out). Implements Spring Security `UserDetails`. `@JsonProperty("isAdmin"/"isApproved"/"isDisabled")` so JSON keys are the boolean form, not the Lombok `admin`/`approved`/`disabled` getter form.

**Bill** (`bills` table) — `@Id billId Integer GENERATED IDENTITY`, `@ManyToOne user` (FK `employee_id`, lazy, JsonIgnore), `ownerId` (insertable=false, updatable=false; reads FK directly so no lazy load needed), `reimbursementFor`, `billDescription?`, `amount Double`, `date LocalDate`, `approvalMailPath?`, `billImagePath`, `paymentProofPath?`, `status` (`Pending|APPROVED|REJECTED|PAID`; mixed casing — admin uppercases on update, user-side displays case-insensitively), `remarks?`, `createdAt LocalDate`. JSON exposes virtual `employeeId` from the User relation.

### 4.4 File storage
`FileStorageService.storeFile`: filename pattern `{ddMMyyyy}_{employeeId}_{fileType}{6charUUID}{originalExt}` where fileType ∈ {`bill`, `approval`, `payment`}. Saved under absolute `uploads/`. Multipart limits: 50 MB file / 50 MB request.

### 4.5 OTP (Redis)
Keys: `OTP_<id>_SIGNUP|RESET` (5 min TTL), `ATTEMPT_<id>_*` (max 5 attempts, then OTP nuked), `VERIFIED_<id>_*` (5 min after verify), `RATE_<id>_*` (3 OTPs / 5 min), `COOLDOWN_<id>_*` (30 s between sends). 6-digit numeric, `SecureRandom`.

### 4.6 Scheduling
`@EnableScheduling` on the application. `DataCleanupScheduler.sendAnnualCleanupReminder` cron `0 0 9 1 4 *` → Apr 1 at 09:00 every year. Sends `EmailService.sendOldDataCleanupReminder` to every admin with a non-blank email.

### 4.7 FCM
`FCMService.sendNotification(token, title, body)` — silently no-ops if token blank or `FirebaseApp` not initialized (i.e. `firebase-service-account.json` missing). Errors logged but never thrown — never breaks the request flow.

---

## 5. Flutter Frontend

### 5.1 Bootstrap (`main.dart`)
- Locks orientation to portrait.
- `Firebase.initializeApp()` + `NotificationService.initialize()` inside `try{}catch(_){}` — failure is non-fatal (handles web where FCM may not be configured).
- Reads `SharedPreferences` for `employee_id` + `is_admin` to decide initial route: `/login` | `/user_dashboard` | `/admin_dashboard`.
- Splash via `flutter_native_splash` (`#0D47A1` background, `splash_icon.png`, branding `branding_expenz.png` bottom).
- `MaterialApp` title `ExpenZ`, `primarySwatch: Colors.blue`, debug banner off.

### 5.2 Models
- `Bill` — mirrors backend. `fromJson` parses `date` and `createdAt` as ISO strings; `remarks` coerced to `String?`.
- `User` — `employeeId, name, email, password, isAdmin, isApproved, isDisabled`. Reads JSON keys `admin`/`approved`/`disabled` (NOT `isAdmin` — Jackson serializes them with `@JsonProperty("isAdmin")` so client also accepts those; current Dart `fromJson` reads short forms).

### 5.3 Services

| File | Role |
|---|---|
| `api_service.dart` | All HTTP. Static methods only. `baseUrl` from `--dart-define API_BASE_URL` (default 192.168.102.150:8081). Uses Basic auth. Multipart upload via `_attachMultipartFile` that picks `bytes` (web) or `path` (mobile). |
| `notification_service.dart` | FCM init, foreground display via `flutter_local_notifications` channel `bills_channel`. On token refresh, re-uploads via `ApiService.updateFcmToken`. `requestPermissionAndGetToken()` returns the device token. |
| `connectivity_service.dart` | `hasInternet()` (via `InternetAddress.lookup` on mobile, always true on web), `isServerAlive()` hits `/admin/ping` with 3 s timeout. `isBackendAvailable()` = both. |
| `compression_service.dart` | Uses `flutter_image_compress` to JPEG-compress images to max 1920 px / quality 72. **No-op on web** (`kIsWeb` short-circuits) and on PDFs. Writes to temp dir, returns new `PlatformFile`. |
| `offline_queue_service.dart` | Persists failed bill uploads in `SharedPreferences` and retries on next app launch. **Mobile-only** (uses `path`-based files; the calling code skips queueing on web). |
| `ocr_service.dart` | ML Kit text recognition. Two parsers: Noida Auth Parking receipts (regex on `INR <amount>` and `dd MMM yy, hh:mm a`), and a generic one (largest decimal as amount, first dd[/-.]mm[/-.]yy as date). **Mobile-only** — `add_bill_screen` guards with `!kIsWeb`. |
| `image_service.dart` | Singleton wrapper around `image_picker` that copies to `<appDocs>/bill_images/bill_<ts>.jpg`. Mobile-only (uses `dart:io`). |
| `excel_service.dart` | Builds an XLSX bills report with filename `Bills_Report_{dd-MM-yyyy}.xlsx` via `file_saver` (works on both platforms). |
| `bill_file_cache.dart` | Process-wide in-memory cache of `Uint8List` for `/files/{name}` GETs. Cleared explicitly via the refresh button. |
| `bill_download_service.dart` | Conditional export shim — exports `_mobile.dart` by default, `_web.dart` if `dart.library.html` is available. Both expose `downloadBytes(bytes, filename, mime)` and `openBytes(...)`. **Web** uses `dart:html` Blob/AnchorElement (`download` attribute) and `window.open` for inline view. **Mobile** uses `file_saver` + `open_filex`. |

### 5.4 Screens

#### `login_screen.dart`
Combined login + signup form. Signup adds Name + Email (validated to end with `@axeno.co`). Signup flow: send OTP → verify OTP dialog → create user. Login flow: `ApiService.login` → check `isApproved` → save session (`employee_id`, `name`, `is_admin`, `password` in `SharedPreferences`) → upload FCM token → navigate. Forgot Password flow: prompts employee ID → send OTP (signUp=false) → verify → new password → `resetPassword`. All API calls gated by `ConnectivityService.isBackendAvailable()` first. Password obscure-toggle button.

#### `user_dashboard.dart`
- App bar shows `NAME, employeeId`. Actions: refresh (clears `BillFileCache`), change password (same forgot-flow), admin-dashboard switch (only if `is_admin`), logout.
- Filters: category, status, date range (table_calendar via `_openCustomDatePicker`); supports filtering on `billDate` vs `submissionDate`.
- Default range = current month; `_isShowAllRange()` = start year 2020 ≡ "all".
- Monthly total card uses `createdAt` for "this month".
- List of `_glassCard` items with status pill + colored side bar (Pending=amber, Approved=green, Rejected=red, Paid=blue).
- Tap → details modal with view-document buttons that fetch via `BillFileCache` and open via `BillDownloadService` (web: new tab / download, mobile: `OpenFilex`).
- FAB → `AddBillScreen`.
- Edit dialog: full glass/blur form with file replace. Uses `CompressionService.compressNullable` before submit (no-op on web).
- Delete confirmation modal calls `ApiService.deleteBill`.
- Offline queue replay on init via `OfflineQueueService.trySubmitQueuedBills`.

#### `admin_dashboard.dart` (largest file)
- Two tabs: **Bills** and **Employees** (`TabController length=2`).
- Theme: greens (`#4CAF50` / `#A5D6A7`) and a soft green gradient bg.
- Bills tab: filters by employee (dropdown), category, status, date range; per-bill admin modal (`_showAdminBillDetailsModal`) shows employee details and status-change controls (Approve / Reject with remarks dialog / Mark Paid). Status transition rules mirror backend (no PAID without prior APPROVED; no edit after PAID).
- Employees tab: search, sort, edit (`_showEditUserDialog`), enable/disable (`_showToggleDisableDialog`), delete (`_showDeleteUserDialog`), pending requests (`_showUserRequestsDialog` for `!isApproved`), disabled users sheet (`_showDisabledUsersSheet`), create user dialog (`_showCreateUserDialog`).
- Settings sheet (`_showSettingsSheet`) — includes "Delete Old Data" calling `getOldBillsCount` + `deleteOldBills` and the cleanup-reminder triggers.
- Exports: Excel (`ExcelService.generateBillsReport`) and PDF (`pdf` + `printing`, `_appendBillPages`/`_appendDocumentPages`). Both work on both platforms via `file_saver` / browser print dialog.
- FCM token uploaded on init for the admin user too.

#### `add_bill_screen.dart`
- Categories: Parking, Travel, Food, Office Supplies, Other. **Parking** is special — does NOT require description / approvalMail / paymentProof.
- Two modes: single bill, batch (toggle). Batch shares category + description + approvalMail across entries; each entry has own bill file, amount, date, paymentProof.
- File picking via `file_picker` for jpg/jpeg/png/pdf, plus camera via `image_picker` (mobile only — guarded with `kIsWeb`).
- OCR auto-runs on picked images (mobile only, non-PDF) and pre-fills amount/date/category.
- All images compressed before submit (no-op on web/PDF).
- If backend offline AND single-mode AND file has a path: queue offline. Otherwise show error (web cannot queue because no fs path).
- Glass-card UI throughout (`BackdropFilter`).

### 5.5 Cross-platform branching pattern (CRITICAL)

When touching anything that handles files, paths, or platform APIs:
- Use `kIsWeb` guards.
- Multipart: prefer `file.bytes` on web, fall back to `file.path` on mobile (already implemented in `_attachMultipartFile`).
- Compression: `compressFile` returns the input unchanged when `kIsWeb` or the file is a PDF.
- Offline queue: skip on web — relies on a persistent fs path.
- Camera (`image_picker.pickImage(source: camera)`): mobile only.
- OCR (`google_mlkit_text_recognition`): mobile only.
- File save / open: route through `bill_download_service.dart` (conditional export) — never import `dart:io` or `dart:html` directly from a screen.
- ML Kit OCR meta in `AndroidManifest.xml` (`com.google.mlkit.vision.DEPENDENCIES = ocr`).

### 5.6 Android specifics
- `AndroidManifest.xml`: permissions INTERNET, POST_NOTIFICATIONS, CAMERA, READ_EXTERNAL_STORAGE. Activity launchMode `singleTop`. `androidx.core.content.FileProvider` declared with authority `${applicationId}.fileprovider` (xml resource `file_paths`).
- `build.gradle.kts`: `compileSdk = 36`, `targetSdk = 36`, Java 11, core-library desugaring on (`com.android.tools:desugar_jdk_libs:2.1.4`), R8 minify + resource shrink in release, debug signing for now (TODO real signing config), Google Services plugin for FCM.
- App label = `ExpenZ`. Adaptive icon foreground = `assets/icon/app_icon.png`, background `#0D47A1`.

---

## 6. Configuration & Secrets

### Backend `.env` (do NOT commit real values)
```
DB_URL=jdbc:mysql://localhost:3306/bills_reimbursement
DB_USERNAME=...
DB_PASSWORD=...
CORS_ALLOWED_ORIGIN=http://<host>:<port>     # currently unused at runtime — SecurityConfig hardcodes "*"
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...        # gmail app password
```
Read via `me.paulschwarz:spring-dotenv`. Plus optional `src/main/resources/firebase-service-account.json`.

### Frontend `.env`
Just `API_BASE_URL = http://<host>:<port>`. Loaded by `flutter_dotenv` (asset-registered) but **the live read in `ApiService` is via `String.fromEnvironment('API_BASE_URL', defaultValue:...)` — i.e. compile-time `--dart-define`, not the .env file at runtime.** README confirms: pass `--dart-define=API_BASE_URL=...` at build/run.

---

## 7. Build & Run

### Backend
```
cd spring_backend
./mvnw spring-boot:run        # listens on :8081 (or whatever server.port resolves to)
```
Requires MySQL (schema created by you — `ddl-auto=none`) and Redis up locally. Firebase admin file optional.

### Frontend
```
cd flutter_application
flutter pub get

# Android dev
flutter run --dart-define=API_BASE_URL=http://<server>:<port>

# Web dev
flutter run -d chrome --dart-define=API_BASE_URL=http://<server>:<port>

# Release APK
flutter build apk --release --dart-define=API_BASE_URL=http://<server>:<port>

# Release Web
flutter build web --release --dart-define=API_BASE_URL=http://<server>:<port>
```

---

## 8. Status Lifecycle (single source of truth)

```
Pending  ──(admin approves)──▶  APPROVED  ──(admin marks paid)──▶  PAID  (terminal)
   │                                │
   └────(admin rejects)──────▶  REJECTED  (admin can re-approve)
```
- User edit/delete allowed only on `Pending` and `REJECTED` (delete blocked on PAID; edit blocked on APPROVED & PAID — see `BillController.editBill`/`deleteBill`).
- Admin cannot directly skip `Pending → PAID` (must go through APPROVED first).
- Status string casing varies — backend stores uppercase after admin update, but new bills are saved as literal `"Pending"`. Always compare case-insensitively (frontend already does this).

---

## 9. Notification Triggers (FCM)

| Event | Recipient | Title | Body |
|---|---|---|---|
| New signup | All admins | "New Approval Request 👤" | `<name> (ID: <id>) has registered and is awaiting approval.` |
| User approval flipped → true | Approved user | "Account Approved 🎉" | "Your account has been approved. You can now submit reimbursement bills." |
| User disabled | Disabled user | "Account Disabled" | "Your account has been disabled by the admin. Please contact your administrator." |
| Bill REJECTED | Bill owner | "Bill Rejected ❌" | `Your ₹<amt> <category> bill was rejected. Remarks: <remarks or "No remarks provided">` |
| Bill PAID | Bill owner | "Bill Paid ✅" | `Your ₹<amt> <category> bill has been marked as paid.` |

All silently no-op when FCM token is blank or Firebase not initialized.

---

## 10. Known Quirks / Gotchas

1. `FileController` always returns `Content-Type: image/jpeg` regardless of actual file type. PDFs and PNGs work in browsers due to sniffing, but check before relying on the header.
2. `application.properties` declares `cors.allowed.origin=${CORS_ALLOWED_ORIGIN}` but `SecurityConfig` hardcodes `setAllowedOriginPatterns(["*"])` — the property is read but never applied. Either wire it through or accept the wildcard.
3. `ddl-auto=none` — schema must be applied manually. There are no Flyway/Liquibase migrations in the repo.
4. The README claims port 8080; actual `application.properties` has `server.port=8081`.
5. Default `API_BASE_URL` baked into `ApiService` is a LAN IP (`192.168.102.150:8081`) — always supply `--dart-define` for non-dev builds.
6. `flutter_dotenv` is in pubspec but `ApiService` does not actually read from it; it uses `String.fromEnvironment`. Don't be misled.
7. Offline queue is mobile-only — web builds silently can't queue.
8. OCR + camera are mobile-only — the web build's add-bill flow has no equivalent (just file picker).
9. Admin can mark PAID only when current status is APPROVED; trying from PENDING/REJECTED returns 400.
10. `User` JPA entity exposes `getAuthorities()` and `isEnabled()` from `UserDetails`. Disabled users authenticate but are rejected by Spring with a `DisabledException`, surfaced as 401 with the friendly disabled message.

---

## 11. Where to look for…

- **Adding a new API endpoint:** controller in `spring_backend/.../controllers/`, register security rule in `SecurityConfig.securityFilterChain`, add Flutter call in `lib/services/api_service.dart`.
- **Changing bill statuses or rules:** `AdminController.updateBillStatus` (server) + status-color/pill helpers + admin modal status buttons (client).
- **Tweaking notifications:** `FCMService` is the only sender on the backend; frontend listens in `NotificationService`.
- **Modifying file storage layout:** `FileStorageService.storeFile` (server) + `FileController` (server) + `BillFileCache.fetch` (client) + `BillDownloadService` (client).
- **OCR rules:** `lib/services/ocr_service.dart` — currently has special handling only for "Noida Auth Parking" receipts.
- **Old-data retention policy:** `DataCleanupScheduler` + `AdminController` cleanup endpoints. Cutoff is start of FY two years before the current FY (April-based fiscal year).

---

*Last full traversal: 2026-04-27 (commit `511014d`). Prefer updating this file when you make non-trivial structural changes; do not re-derive from scratch unless it's clearly stale.*
