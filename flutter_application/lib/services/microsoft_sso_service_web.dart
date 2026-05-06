import 'dart:js_interop';

import '../config/sso_config.dart';

/// Web implementation of [MicrosoftSsoService]. Delegates to the
/// `@azure/msal-browser` JavaScript library, loaded by `web/index.html`
/// and wrapped by the small `window.expenzMsal` shim defined there.
///
/// The shim exposes two methods we need:
///   - `signIn(clientId, tenantId, scopes) -> Promise<idToken>`
///   - `signOut() -> Promise<void>`
///
/// `loginPopup` (used by the shim) opens Microsoft's account-picker in a
/// new browser window and returns once the user finishes. Pop-up blockers
/// reject the call unless invoked from a direct user gesture; the existing
/// "Sign in with Microsoft" button satisfies that.
class MicrosoftSsoService {
  MicrosoftSsoService._();

  /// Returns a Microsoft ID token suitable for posting to
  /// `POST /auth/microsoft`, or `null` if the user cancelled the popup.
  static Future<String?> signIn() async {
    if (!SsoConfig.isConfigured) {
      throw StateError(
        'Microsoft SSO is not configured. Set AZURE_AD_TENANT and '
        'AZURE_AD_CLIENT_ID via --dart-define and rebuild.',
      );
    }

    final shim = _shim;
    if (shim == null) {
      throw StateError(
        'Microsoft SSO shim not found. Did web/index.html load '
        'msal-browser correctly?',
      );
    }

    try {
      final token = await shim
          .signIn(
            SsoConfig.clientId.toJS,
            SsoConfig.tenantId.toJS,
            SsoConfig.scope.toJS,
          )
          .toDart;
      return token.toDart;
    } catch (e) {
      // msal-browser raises BrowserAuthError with errorCode "user_cancelled"
      // when the user closes the popup; surface as a quiet null.
      final msg = e.toString();
      if (msg.contains('user_cancelled') || msg.contains('user_canceled')) {
        return null;
      }
      throw Exception('Microsoft sign-in failed: $msg');
    }
  }

  /// Clears the MSAL.js cache so the next [signIn] re-prompts. Safe to
  /// call when no session exists.
  static Future<void> signOut() async {
    try {
      await _shim?.signOut().toDart;
    } catch (_) {
      // No account to sign out of is fine.
    }
  }
}

@JS('expenzMsal')
external _ExpenzMsal? get _shim;

extension type _ExpenzMsal._(JSObject _) implements JSObject {
  external JSPromise<JSString> signIn(
    JSString clientId,
    JSString tenantId,
    JSString scopes,
  );
  external JSPromise<JSAny?> signOut();
}
