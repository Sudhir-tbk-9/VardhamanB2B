# PD (production) environment checklist

Everything in the code that differs between PY (UAT, `https://b2b.amefird.in/vytldev/`)
and PD (production, `https://b2b.amefird.in/`). Line numbers are from branch
`deploy/prod-sync`, 22-Nov-2026.

There is no `--dart-define` or flavor: switching means editing these files by
hand (marked `// for PD` / `// for PY` in the code).

**On `deploy/prod-sync` the code is set to PD everywhere** (section 1). The
PY values are kept as comments next to each one. The `deploy/uat-4` and
`deploy/uat-4.1` branches stay on PY.

Secrets are not copied here; only where they are set.

---

## 1. Switched to PD on `deploy/prod-sync`

| # | What | File:line | PD (now active) | PY (commented) |
|---|------|-----------|-----------------|----------------|
| 1 | JDE AIS base URL | `lib/api/api.dart:71-72` | `https://erp.vardhmanthreads.in/jderest` | `https://erptest.vardhmanthreads.in/jderest` |
| 2 | Login OTP (portal users) | `lib/login/login_controller.dart:392-395` | `Api.generateAndSendOtp(...)` | Fixed `_otp = "1234"` |
| 3 | OTP generation and SMS | `lib/api/api.dart:393-413` | Random 4-digit OTP, sent by `ORCH55_SendOTPB2BPortal` | Returns `'1234'`, no SMS |
| 4 | Payment encryption orchestration | `lib/api/api.dart:3398-3399` | `/orchestrator/ORCH55_ICICIEncryptProd` | `/orchestrator/ORCH_55_EncryptPlainText` |
| 5 | Payment status request | `lib/api/api.dart:3449-3455` | `walletClientCode: WT-1573`, `ReceiptNumber: { "txn-id": … }` | `walletClientCode: WT-2519` |
| 6 | Advance payment message and form | `lib/open/advance_payment_dialog.dart:112-205` | See 1.1 | JSON body, `clientCode WT-2519`, `collectRequestMessage`, `digicxuat` UAT gateway |
| 7 | Invoice payment message and form | `lib/open/invoice_review_dialog.dart:171-279` | See 1.1 | Same as row 6 |
| 8 | `app_url.dart` import (both dialogs) | `advance_payment_dialog.dart:9`, `invoice_review_dialog.dart:10` | Commented out (only PY uses it) | Uncomment with the PY blocks |

### 1.1 Payment gateway for PD

ICICI confirmed (22-Nov-2026) that PD uses the **old ipay2corp gateway** for now.
Both payment screens send:

- Message: pipe-separated plain text
  `txn-id=<receipt>|txn-datetime=dd/MM/yyyy HH:mm:ss|txn-amount=<amount>|txn-for=payment|wallet-payment-mode=2|return-url=https://b2b.amefird.in|cancel-url=https://b2b.amefird.in|`
- Encrypted by `ORCH55_ICICIEncryptProd`
- Form `POST` to `https://generic.ipay2corp.icici.bank.in/gp2c-api/ws/payment`
- Hidden fields `walletClientCode = WT-1573` and `walletRequestMessage = <encrypted>`

Notes:
- **Amounts.** The invoice payment sends `selectedDiscountedAmount`. The advance
  payment sends `rxAdvancePaymentAmount`, the same amount as the JDE entry. The
  original commented PD block sent `selectedDiscountedAmount` for advances
  too, which looked like a bug.
- **Return URL.** It is fixed at `https://b2b.amefird.in`, as in the original
  code. ICICI must allow it as the return URL for `WT-1573`.
- **Cancel.** The cancel URL is the same as the return URL, so the app can't
  tell a cancel from a return. The sessionStorage marker still logs the user
  back in, and the status check (row 5) reports the payment's real state.
  Confirm this in the PD smoke test.
- **Moving to the new gateway later.** Swap the `// for PD` and `// for PY`
  blocks in both dialogs. Ask ICICI for the production finhub-collect URL and
  client code, and use `appReturnUrl` / `appCancelUrl`.

---

## 2. Same for PY and PD: check they're right for production

| What | File:line | Value | Check |
|------|-----------|-------|-------|
| Invoice PDF file server | `lib/api/api.dart:37`, `:3324` | `https://b2b.amefird.in:8081` (`/download/CAMSInvoicing/<file>`) | PD uses the same server and port 8081 is open |
| File server credentials | `lib/api/api.dart:38` | Basic auth header, hard-coded | Same account for PD |
| JDE AIS login user | `lib/api/api.dart:343-344` | Service user and password, hard-coded | PD JDE (`erp`) has the same user and password |
| Order SMS | `lib/api/api.dart:446-459` | JDE `ORCH55_SendSMSNotification` | Orchestration exists in PD JDE |
| Order WhatsApp | `lib/api/api.dart:461-480` | Airtel IQ WhatsApp API, template `01jj1c8d…`, sender `9313503051`, Basic auth hard-coded | Right template and sender for production |
| Login page video | `lib/login/login_controller.dart:113` | `https://b2b.amefird.in/vytlold/assets/img/B2B.mp4` (old app folder) | This file stays on the server after PD replaces the root app |
| Mock data fallback | `lib/api/api.dart:3531`, `:3608` (`lib/sample_data.dart`) | When the JDE UOM-description or item-master call **fails**, built-in sample data is used | Decide if PD should show an error instead of stale sample data |

---

## 3. Build for PD

- Base href:
  - PY builds with `--base-href /vytldev/` (`scripts/build_web_uat.ps1`).
  - PD is served at the site root, so build with `--base-href /`.
  - There is no PD build script yet.
- Keep `--no-tree-shake-icons`:
  - Without it, a browser holding an older cached icon font shows newer icons blank (seen on PY).
- Build from PowerShell, not Git Bash. Git Bash rewrites `/vytldev/` into a Windows path.
- Check the output has `sqlite3.wasm` and `drift_worker.js`, and that `index.html` has the right `<base href>`.

Suggested PD command:

```powershell
flutter build web --release --base-href / --no-wasm-dry-run --no-tree-shake-icons
```

## 4. Server (Apache) for PD

PY's rules are in `docs/DEPLOY_PY_LINUX.md` §5 and `docs/NAVIGATION.md` §5.2 and §6.2. PD needs the same at `/`:

1. `POST /` serves `/index.html` (the payment gateway returns with a POST).
2. Any `GET` that isn't an existing file serves `/index.html` (path URLs). Exclude `/vytldev/` so PY keeps working, and keep `/vytlold/` (login video, §2).
3. `Header set Cache-Control "no-cache"`, so browsers pick up a new deploy at once.
4. `.wasm` served as `application/wasm`.

## 5. Local / dev only (no action for PD)

- `http://localhost:8000/` and `scripts/dev_payment_proxy.py`, `scripts/run_web_payment_test.ps1`: local payment testing.
- The `// for GITHUB` blocks (`https://ausm-infotech.github.io/vardhman_b2b`) in both payment dialogs: an old GitHub Pages test, commented out.
- `// baseUrl: 'https://localhost:8081'` (`lib/api/api.dart:36`): local file server, commented out.
- `kDebugMode` logs (`lib/api/api.dart`): debug builds only.
  - `debugPrint` lines (e.g. `[BULK IMPORT]`, payment logs) still print in release builds.

## 6. Order of work for PD

1. ~~ICICI gateway for PD~~: done, the old ipay2corp gateway (1.1).
2. ~~Switch rows 1-8 on `deploy/prod-sync`~~: done. The PY branches are untouched.
3. ~~`flutter analyze` and `flutter test --concurrency=1`~~: done. All 157 tests pass.
4. Confirm with ICICI that `https://b2b.amefird.in` is an allowed return URL for `WT-1573`.
5. Check section 2.
6. Build with §3, deploy with §4.
7. Smoke test on PD:
   - login with a real OTP
   - place one order of each type
   - invoice PDF download
   - one small invoice payment and one small advance payment, each with its return and status
   - one cancelled payment
