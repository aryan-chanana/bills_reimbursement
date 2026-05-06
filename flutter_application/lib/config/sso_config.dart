/// Microsoft Entra ID configuration for the SSO sign-in flow.
///
/// Plug in real values once the Azure AD app registration is done. Both
/// values come from the Azure portal:
///   • [tenantId]  → `common` for multi-tenant, or "Directory (tenant) ID"
///                   for single-tenant.
///   • [clientId]  → "Application (client) ID".
///
/// `msal_auth` uses the **native MSAL SDK** under the hood; on Android/iOS
/// this means the registered redirect URI must be in the broker-friendly
/// `msauth://<package-or-bundle>/<base64-cert-hash>` format. See
/// `android/app/src/main/assets/msal_auth/android_config.json` and the
/// `MsalAuthBrowserTabActivity` block in `AndroidManifest.xml` — the URI
/// in all three places (Azure portal, JSON config, manifest) must match
/// byte-for-byte.
///
/// Pass values at build time via `--dart-define` so secrets aren't
/// committed:
///
/// ```
/// flutter run \
///   --dart-define=AZURE_AD_TENANT=common \
///   --dart-define=AZURE_AD_CLIENT_ID=<application-client-id> \
///   --dart-define=AZURE_AD_REDIRECT_URI=msauth://com.example.bills_reimbursement/<sha1-base64>
/// ```
class SsoConfig {
  static const String tenantId = String.fromEnvironment(
    'AZURE_AD_TENANT',
    defaultValue: 'common',
  );

  static const String clientId = String.fromEnvironment(
    'AZURE_AD_CLIENT_ID',
    defaultValue: 'bfddd261-b4a5-4150-8029-bcede96adaa9',
  );

  /// Scopes requested during sign-in. `openid profile email` are enough to
  /// get an ID token whose claims our backend can map to a local user.
  /// `offline_access` is intentionally omitted — Azure tenants sometimes
  /// decline it for multi-tenant apps, which makes msal_auth throw
  /// `MsalDeclinedScopeException` and discard the otherwise-valid token.
  /// We don't keep refresh tokens client-side anyway: each sign-in
  /// produces a fresh ID token that the backend turns into its own
  /// opaque session credential.
  static const String scope = 'openid profile email';

  /// Broker-compatible redirect URI in the URL-encoded form MSAL expects.
  /// Must be registered on the Azure AD app exactly as written here. The
  /// raw (unencoded) form lives in the Android manifest as the
  /// `msalCertHash` placeholder — see `android/app/build.gradle.kts`.
  ///
  /// Hard-coded as the default because passing this URI through cmd.exe
  /// `^` line continuations can introduce invisible characters that make
  /// MSAL's exact-string config check fail. Override with --dart-define
  /// only when switching to a different signing keystore.
  static const String redirectUri = String.fromEnvironment(
    'AZURE_AD_REDIRECT_URI',
    defaultValue: 'msauth://com.example.bills_reimbursement/ZB0FOV7lz5O1%2BZ4OBuYOsVKH3%2Fs%3D',
  );

  static bool get isConfigured =>
      tenantId.isNotEmpty && clientId.isNotEmpty && redirectUri.isNotEmpty;
}
