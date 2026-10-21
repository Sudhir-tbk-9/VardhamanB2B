/// URL the app is being served from (scheme, host, port and base path, no
/// route or query), e.g. `http://localhost:8000/` locally or
/// `https://b2b.amefird.in/vytldev/` when deployed. Used as the payment
/// gateway's return / cancel URL so the user always comes back to the same
/// app instance, whatever host or port it runs on.
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
