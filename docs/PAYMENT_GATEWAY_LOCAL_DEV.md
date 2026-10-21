# Payment gateway round trip – local development

How the web app is run locally so that leaving for the payment gateway (or any
external link) and coming back keeps both the `flutter run` session and the
user's place in the app.

## The problem

| Symptom | Cause |
|---|---|
| Return URL shows "This site can't be reached" | `flutter run -d chrome` shuts its dev server down when the tab navigates away to the gateway. |
| Port changes between runs | Without `--web-port`, Flutter picks a random port, but the gateway's return / cancel URL is fixed at `http://localhost:8000/` (`lib/open/invoice_review_dialog.dart`). |
| Return fails even on the right port | The gateway sends the user back with a **POST** (form fields `errorStatus`, `collectResponseMessage`, …). Flutter's dev server only answers GET. |
| User lands on the login screen | The app reloads from scratch on return. While the saved session was being restored (JDE token refresh + session setup, ~20 s), the login form was shown. |

## The setup

```
Browser ──► localhost:8000  scripts/dev_payment_proxy.py
                │   GET / websocket / SSE  ──► piped to localhost:8001
                │   gateway POST to a page ──► 303 redirect, same path,
                │                              form fields as query params
                ▼
            localhost:8001  flutter run -d web-server   (session never stops)
```

- `flutter run -d web-server` keeps serving whatever the browser tab does, so
  the one session lives through any number of payment round trips.
- The proxy keeps the app on origin `localhost:8000`, so localStorage,
  sessionStorage and the drift database stay the same before and after the
  gateway.
- The gateway's POST becomes a normal GET, e.g.
  `/?errorStatus=0&collectResponseMessage={...}`, which `_logGatewayReturn()`
  in `lib/login/login_controller.dart` records with the payment log.
- POSTs from Flutter's debug service (paths starting with `$`, e.g.
  `$dwdsSseHandler`) are passed through untouched.
- Each proxied request uses its own connection (except websockets), so a
  gateway POST on a reused browser connection is still caught.

## Running it

From the project root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_web_payment_test.ps1
```

This starts the proxy, opens Chrome on `http://localhost:8000` with a separate
dev profile (`--disable-web-security` for the JDE AIS calls, dev only), runs
`flutter run`, and stops the proxy when Flutter quits. Refresh the tab once
Flutter prints `lib\main.dart is being served at http://localhost:8001`.

Or in VS Code: launch **"Flutter Web (Payment, port 8000 via proxy)"**. It
starts the proxy through the `payment proxy` task in `.vscode/tasks.json`.

Or by hand in two terminals:

```powershell
py -u scripts\dev_payment_proxy.py 8000 8001
flutter run -d web-server --web-port 8001
```

Always open **8000**, never 8001. Python is started with the `py` launcher
because `python` is not on PATH on this machine.

### Hot reload

In web-server mode, `r` / `R` recompile, but the browser only picks up the
change when the tab is refreshed, unless the Dart Debug Chrome extension is
installed. After a gateway return, the reloaded page always runs the latest
compiled code.

### Troubleshooting

- **"Flutter failed to delete a directory at build\flutter_assets"**:
  `flutter run` deletes that folder on start and fails while any program has
  a file in it open. This is usually a previous `flutter run` that was closed
  abruptly and is still streaming `assets\B2B.mp4`. The script handles it:
  1. stops leftover `flutter run -d web-server --web-port 8001` and proxy
     processes;
  2. retries the delete for up to 20 s;
  3. if the folder is still locked, prints which program holds it (for
     example `Held open by: dart.exe (PID 1234)`) and exits. Close that
     program, or run `Stop-Process -Id 1234`, then run the script again.

  `.vscode/settings.json` excludes `build/` from VS Code's file watcher for
  the same reason. Reload the VS Code window once after it is added.
- **"flutter run is not serving yet"** in the browser: the proxy is up but
  Flutter is still building. Refresh when it is serving.
- **What did the gateway send back?** The proxy prints each return POST (the
  first 500 bytes of the body). The app's step-by-step payment log is in
  localStorage under `paymentLog` and is printed to the browser console with a
  `[PAYMENT]` prefix.

## Coming back to the same page

`lib/common/payment_return.dart` saves a marker in the tab's sessionStorage
just before leaving the app: the nav rail index (the open tab), the receipt
number for a payment, and the time. Markers older than 30 minutes are ignored.

On load, `LoginController._checkUser()` checks for the marker:

1. Marker present: the state is set to `LoginState.resuming` straight away,
   and `lib/app/app.dart` shows a "Taking you back..." loader instead of the
   login form.
2. The saved user and password are found and the JDE token refreshes: the
   user is logged in, `HomeController.rxNavRailIndex` is set to the saved tab,
   and for a payment the status is checked and shown.
3. If anything fails, the password screen is shown and
   `session_restore_failed` is written to the payment log. No saved user or
   password means the normal login screen.

### Using it for other external links

Open external pages in the same tab with `leaveAppTo` and the user returns to
the same tab, still logged in:

```dart
await leaveAppTo(
  'https://example.com/terms',
  navRailIndex: Get.find<HomeController>().rxNavRailIndex.value,
);
```

The payment dialogs (`invoice_review_dialog.dart`,
`advance_payment_dialog.dart`) call `savePaymentReturn(navRailIndex:,
receiptNumber:)` before submitting the gateway form. Without a receipt
number, only the tab is restored and no payment status is checked.

## Files

| File | Role |
|---|---|
| `scripts/dev_payment_proxy.py` | Proxy on 8000: pass-through plus POST → GET for gateway returns |
| `scripts/run_web_payment_test.ps1` | One command: proxy + Chrome dev profile + `flutter run` |
| `.vscode/launch.json`, `.vscode/tasks.json` | Same setup from VS Code |
| `lib/common/payment_return.dart` | Return marker, `leaveAppTo` |
| `lib/login/login_controller.dart` | `LoginState.resuming`, session restore in `_checkUser()` |
| `lib/app/app.dart` | Loader shown while resuming |
| `scripts/payment_test_server.py` | Older alternative: serves a built `build/web_uat` on 8000, no hot reload |
