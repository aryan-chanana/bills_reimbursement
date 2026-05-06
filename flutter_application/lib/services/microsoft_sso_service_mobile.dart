import 'package:msal_auth/msal_auth.dart';

import '../config/sso_config.dart';

/// Wraps the `msal_auth` package with two affordances over plain OAuth:
///
/// 1. **Silent-first acquisition** — if Microsoft Authenticator (or any
///    other MSAL-aware Microsoft app like Outlook/Teams) is signed into an
///    @axeno.co account, `acquireTokenSilent` returns a fresh ID token with
///    no user interaction. The user goes straight to the dashboard.
/// 2. **Interactive fallback** — when no cached account exists, or the
///    silent path fails (no broker, refresh expired, user signed out), it
///    falls through to `acquireToken` which uses the broker if installed
///    and a system browser tab otherwise. Either way the experience reuses
///    OS-level Microsoft session state, so the user is rarely prompted for
///    a password.
class MicrosoftSsoService {
  MicrosoftSsoService._();

  static SingleAccountPca? _pca;

  static Future<SingleAccountPca> _ensurePca() async {
    if (!SsoConfig.isConfigured) {
      throw StateError(
        'Microsoft SSO is not configured. Set AZURE_AD_TENANT and '
        'AZURE_AD_CLIENT_ID via --dart-define and rebuild.',
      );
    }
    return _pca ??= await SingleAccountPca.create(
      clientId: SsoConfig.clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_auth/android_config.json',
        redirectUri: SsoConfig.redirectUri,
      ),
      appleConfig: AppleConfig(
        // For multi-tenant we let MSAL pick the authority from the bundled
        // config; passing it here only matters for B2C.
        authorityType: AuthorityType.aad,
        broker: Broker.msAuthenticator,
      ),
    );
  }

  /// Returns a Microsoft ID token suitable for posting to
  /// `POST /auth/microsoft`. Always shows Microsoft's account picker so
  /// the user can choose which Microsoft account to sign in with — the
  /// broker still lights up any device-registered accounts in that
  /// picker, so picking the usual account is one tap with no password.
  ///
  /// Returns `null` only if the user cancelled the picker.
  static Future<String?> signIn() async {
    final pca = await _ensurePca();

    // SingleAccountPca only stores one identity at a time, so a stale
    // cached account from a previous sign-in can clash with whatever the
    // user picks now ("signed in account does not match"). Wipe before
    // each interactive attempt.
    try {
      await pca.signOut();
    } on MsalException {
      // No cached account to clear — fine.
    }

    try {
      final interactive = await pca.acquireToken(
        scopes: _scopesAsList(),
        // Forces Microsoft to show its account chooser every time.
        prompt: Prompt.selectAccount,
      );
      return interactive.idToken;
    } on MsalUserCancelException {
      return null;
    } on MsalException catch (e) {
      throw Exception('Microsoft sign-in failed: ${e.message}');
    }
  }

  /// Clears the cached Microsoft account so the next [signIn] re-prompts.
  /// Wire this into your app-wide logout flow if you want SSO state cleared
  /// alongside the local session.
  static Future<void> signOut() async {
    if (_pca == null) return;
    try {
      await _pca!.signOut();
    } on MsalException {
      // No account to sign out of is fine.
    }
  }

  static List<String> _scopesAsList() => SsoConfig.scope
      .split(' ')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}
