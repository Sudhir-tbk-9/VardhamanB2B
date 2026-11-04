/// Query parameter added to [appCancelUrl]. The gateway sends nothing back
/// when the user cancels, so this is how a cancel is told apart from a
/// return after paying.
const gatewayCancelParameter = 'gatewayCancel';

/// URL the app is being served from (scheme, host, port and base path, no
/// route or query: the last path segment, e.g. `open` in `/vytldev/open`, is
/// the tab and is dropped), e.g. `http://localhost:8000/` locally or
/// `https://b2b.amefird.in/vytldev/` when deployed. Used as the payment
/// gateway's return URL so the user always comes back to the same app
/// instance, whatever host or port it runs on.
String get appReturnUrl {
  final base = Uri.base;

  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path.endsWith('/')
        ? base.path
        : base.path.substring(0, base.path.lastIndexOf('/') + 1),
  ).toString();
}

/// [appReturnUrl] marked as a cancel, for the gateway's cancel-url.
String get appCancelUrl => '$appReturnUrl?$gatewayCancelParameter=1';
