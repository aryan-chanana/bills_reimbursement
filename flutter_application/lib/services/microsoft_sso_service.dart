/// Conditional-export shim — picks the mobile or web implementation at
/// compile time based on whether `dart.library.html` is available.
///
/// Both implementations expose the same surface:
///   - `MicrosoftSsoService.signIn() -> Future<String?>` (ID token, or
///     null on user cancellation)
///   - `MicrosoftSsoService.signOut() -> Future<void>`
///
/// Mobile uses the native `msal_auth` package (broker-aware). Web uses
/// `@azure/msal-browser` via the JS shim defined in `web/index.html`.
export 'microsoft_sso_service_mobile.dart'
    if (dart.library.html) 'microsoft_sso_service_web.dart';
