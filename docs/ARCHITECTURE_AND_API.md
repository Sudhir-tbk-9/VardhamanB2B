# Vardhman B2B Portal — Project Flow & API Reference

Reverse-engineered from the `vardhman_b2b` Flutter client. Every endpoint, payload key, JDE form code, and table below was read out of the source; line references point at the current working tree.

- **App package:** `vardhman_b2b` (Flutter, Dart SDK `^3.5.4`)
- **State management:** GetX (controllers + `Rx` observables)
- **Local DB:** Drift over SQLite / WASM, database name `vytl`
- **HTTP:** `dio` 5.7 (plus raw `http_parser` for multipart)
- **Platforms:** Android, iOS, Windows, Linux, macOS, Web

---

## Table of contents

1. [Architecture at a glance](#1-architecture-at-a-glance)
2. [Project structure](#2-project-structure)
3. [Runtime flow](#3-runtime-flow)
4. [Network layer](#4-network-layer)
5. [JDE reference data model](#5-jde-reference-data-model)
6. [API catalogue](#6-api-catalogue)
7. [JDE forms & tables reference](#7-jde-forms--tables-reference)
8. [Local database (Drift)](#8-local-database-drift)
9. [SharedPreferences keys](#9-sharedpreferences-keys)
10. [Trigger map: function → API → caller](#10-trigger-map-function--api--caller)
11. [Security findings](#11-security-findings)
12. [Bugs & inconsistencies observed](#12-bugs--inconsistencies-observed)

---

## 1. Architecture at a glance

There is **no server-side application tier**. The Flutter client is the application. It owns:

- all business logic (pricing, order assembly, validation, formatting),
- a local SQLite database staging draft orders,
- a local password and login state.

It talks directly to four external systems:

| System | Base URL | Transport | Purpose |
|---|---|---|---|
| JDE Orchestration | `https://erp.vardhmanthreads.in/jderest` | HTTPS JSON | 19 `ORCH*` services — reads and writes |
| JDE REST Data Service | `https://erp.vardhmanthreads.in/jderest/v2/dataservice` | HTTPS JSON | Direct table browse on JDE business tables |
| JDE AIS (auth) | same host, `/v2/tokenrequest` | HTTPS JSON | Token issue / logout |
| B2B File Service | `https://b2b.amefird.in:8081` | HTTPS + Basic | Invoice PDF download, directory listing |
| Airtel WhatsApp | `https://iqwhatsapp.airtel.in` | HTTPS + Basic | Order-confirmation template |
| ICICI iPay2Corp | `https://generic.ipay2corp.icici.bank.in` | HTML form POST | Payment redirect (server-built form) |

```
┌───────────────────────────── Buyer device ─────────────────────────────┐
│                                                                        │
│  Flutter UI  ──►  GetX Controllers  ──►  Api (Dio)  ──►  Drift (vytl)  │
│                        │                      │                        │
│                        │                      └► JDE Orchestration       │
│                        │                      └► JDE Data Service       │
│                        │                      └► JDE AIS token          │
│                        │                      └► B2B File Service       │
│                        │                      └► Airtel WhatsApp        │
│                        │                                                 │
│  SharedPreferences (password, zone, selected customer/address)          │
└────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                        (browser form POST) ICICI iPay2Corp
```

The interactive diagram for this is at `docs/architecture/vardhman-b2b.runtime.html`.

---

## 2. Project structure

```
lib/
├── main.dart                 Bootstrap: prefs → Database → LoginController → runApp
├── app/app.dart              GetMaterialApp, theme, LoginView ⇄ HomeScaffold gate
├── constants.dart            Colors, order-type maps, getItemNumber(), order status
├── nav_rail_container.dart   NavRail host
│
├── login/                    login_controller.dart, login_view.dart
├── home/                     home_scaffold.dart, nav_rail.dart, home_controller.dart,
│                             order_summary_controller.dart, order_summary_view.dart
│
├── sampling/                 ┐
├── labdip/                   │  4 order types, each = _controller (list/track),
├── dtm/                      │  _entry_controller (line entry), _view (order list)
├── bulk/                     │  _order_details_view (line detail)
│                             ┘
├── orders/                   order_review_controller.dart (submit + notify),
│                             orders_controller.dart, order_review_controller
├── invoices/                 invoices_controller.dart, paid/pending views
├── open/                     Open/Overdue/Processing/Due invoice views,
│                             invoice_review_dialog.dart, advance_payment_dialog.dart
├── paid/                     paid_invoices_view.dart, paid_invoices_list.dart
│
├── catalog/                  catalog_controller.dart — in-memory item catalog
├── user/                     user_controller.dart — user + customer + addresses
├── common/                   shared widgets (fields, buttons, PDF dialog)
│
├── api/                      api.dart (3247 lines, all network) + freezed DTOs
│                             buyer_info, indent_info, invoice_info, item_catalog_info,
│                             labdip_feedback, labdip_table_row, order_detail_line,
│                             order_header_line, order_summary, sampling_feedback,
│                             sampling_table_row, user_address
└── drift/                    database.dart + 10 table definitions
```

---

## 3. Runtime flow

### 3.1 Bootstrap — `lib/main.dart:9`

```
WidgetsFlutterBinding.ensureInitialized()
VideoPlayerMediaKit.ensureInitialized(windows: true)   // muted looping login B-roll
SharedPreferences.getInstance()  → Get.put(permanent)
Database()                        → Get.put(permanent)   // opens vytl
LoginController()                 → Get.put(permanent)   // kicks off _init()
runApp(App())
```

`LoginController._init()` (`login_controller.dart:66`) plays the background
video from `https://b2b.amefird.in/vytlold/assets/img/B2B.mp4` (volume 0,
looping), then calls `_checkUser()`.

### 3.2 Authentication state machine — `login_controller.dart:23`

`LoginController` drives a 6-state enum. `App` (`app/app.dart:82`) watches
`rxLoginState` and swaps the whole tree between `LoginView` and `HomeScaffold`.

```
                 ┌──────────┐
                 │ unknown  │  (startup)
                 └────┬─────┘
                      │ _checkUser() reads Drift UserDetails
        ┌─────────────┴──────────────┐
        │                            │
   row found?                    no row
        │                            │
        ▼                            ▼
  ┌───────────┐              ┌────────────┐
  │ refresh   │              │ loggedOut  │◄──── forgotPassword()
  │ Token()   │              └─────┬──────┘
  └─────┬─────┘                    │ user enters Sold-To number
        │ password in prefs?        ▼
   ┌────┴────┐                ┌──────────┐
   yes       no               │validateUser│
    │         │                └────┬─────┘
    ▼         └──────────────►  fetchUserData()  (ORCH5541001)
┌──────────┐                        │
│ password │                        │ isMobileUser?
└────┬─────┘                        ├─ false → generateAndSendOtp() → ┌──────┐
     │                              │                                 │  otp │
     │                              └─ true  → toast "not a B2B user" └────┬─┘
     │                                                                   │ validateOtp()
     │                                              ┌────────────────────┘
     │                                              ▼
     │                                        ┌──────────────┐
     │                                        │ setPassword  │  writes prefs
     │                                        └──────┬───────┘
     │                                               │ _logIn()
     │◄──────────────────────────────────────────────┘
     ▼
  LoginState.loggedIn  →  HomeScaffold
```

`_logIn()` (`login_controller.dart:254`) resets and re-registers ten controllers
(`UserController` tagged `userController`, `CatalogController`,
`OrderReviewController`, `OrdersController`, `DtmController`,
`SamplingController`, `LabdipController`, `BulkController`,
`InvoicesController`, `HomeController`), then upserts the `UserDetails` row
into Drift with `InsertMode.insertOrReplace`.

### 3.3 Home and navigation

`HomeScaffold` hosts a `NavRail` (`home/nav_rail.dart:97`) with six modules
mapped to `rxNavRailIndex` 0–5:

| Index | Module | Controller | Entry controller |
|---|---|---|---|
| 0 | Sampling | `SamplingController` | `SamplingEntryController` |
| 1 | Labdip | `LabdipController` | `LabdipEntryController` |
| 2 | DTM | `DtmController` | `DtmEntryController` |
| 3 | Bulk | `BulkController` | `BulkEntryController` |
| 4 | Invoices — Open | `InvoicesController` | — |
| 5 | Invoices — Paid | `InvoicesController` | — |

`OrderSummaryController` and the "Status Report" dialog are also reachable from
the home scaffold.

### 3.4 Order placement — the four order types

The four order modules are near-identical parallel implementations. The Bulk
path is the most complete (it adds xlsx import); read `lib/bulk/` as the
reference.

**Stage A — draft shell.** When the user opens an order type,
`*_orders_view.dart` calls `Api.fetchDraftOrderNumber()` to reserve a *draft*
number (`module 55 / object 10`) used only as the `DraftTable.orderNumber`
key. Nothing is written to JDE yet.

**Stage B — line entry.** `BulkEntryController` (`bulk/bulk_entry_controller.dart:19`):

1. In its constructor it kicks off two reference lookups —
   `Api.fetchBuyerInfos()` (`:192`) and
   `Api.fetchMerchandiserNames()` (`:196`) — and opens a reactive query on
   `DraftTable` filtered by `soldTo` + `orderType='BK'` + `orderNumber`
   (`:170`).
2. Article + UOM + brand + substrate + tex + ticket cascade from the
   in-memory `CatalogController.industryItems` via `selectIfOnlyOneOption()`
   (`:370`).
3. `rxArticle` / `rxUom` changes fire `resetShade()` (`:239`) → `Api.fetchShades()`.
4. `rxShade` changes fire `shadeListener()` (`:266`) → `Api.fetchUnitPrice()`.
5. `addBulkOrderLine()` (`:508`) writes one row to `DraftTable` with
   `InsertMode.insertOrReplace`. Duplicate article+shade is rejected.
6. Optional `importExcel()` (`:850`): `file_picker` → `Excel.decodeBytes` →
   per-row `ExcelLine.fromRow` validation → `Api.validateItemNumbers()` to drop
   unknown items → per-line `Api.fetchUnitPrice()` → `DraftTable` insert.
7. `colorRemark` is a pipe-joined string of optional fields
   (`_colorRemark`, `:455`): `secondLightSource|remark|L|requestType|endUse`.

**Stage C — submit.** `BulkEntryController.submitOrder()` (`:779`):

```
firstPoDocLine = first draft line carrying a PO file
orderNumber    = Api.fetchBulkOrderNumber()        // module 47 / object 7

if firstPoDocLine != null:                          // PO document attached
    emails = Api.fetchBulkDtmEmailAddresses()       // F5501002, DL011='PODOC'
    Api.uploadMediaAttachment(poFileBytes)           // multipart /v2/file/upload
    Api.supplementalDataEntry(QTX, QT, ...)          // attach key to order
    Api.supplementalDataWrapper(QTX, QT, ..., emails) // e-mail the document

ok = OrderReviewController.submitBulkOrder(...)      // -> Api.submitBulkOrder()

if ok: delete DraftTable rows for this orderNumber; Get.back()
```

`Api.submitBulkOrder()` (`api.dart:2637`) first resolves billing type via
`getBillingType()` (`:2503`) — if a `BT`/`BT`/`SBA2='D'` supplemental row exists
for the Sold-To, `BillingType` becomes `D`, otherwise `B` — then POSTs the
whole order as one `Detail[]` array to `ORCH55CreateStagingData`.

`OrderReviewController.submitBulkOrder()` (`orders/order_review_controller.dart:224`)
adds the post-submit notifications:

```
if canSendSMS      → Api.sendOrderEntrySMS(...)
if canSendWhatsApp → Api.sendOrderEntryWhatsApp(...)
fetchDraftOrderNumber()      // reserve the next draft shell
```

**Item number construction** — `constants.dart:129`:

```dart
getItemNumber(article, uom, shade) =>
    '${article.padRight(7)}${uom.padRight(5)}$shade'
```

JDE reads this back as three space-separated segments
(`api.dart:3029`), so e.g. article `A100`, UOM `MTR`, shade `RED` becomes
`A100   MTR  RED` and item number `A100   MTRRED`.

### 3.5 Order tracking and feedback

`*_controller.dart` (the list controller) loads history:

- `Api.fetchOrders(soldToNumber)` → `ORCH5542001_GetOrderStatus`, 180-day window.
- `Api.fetchOrderDetails(...)` → `ORCH5542002_GetOrderDetail`.
- `order_review_controller.dart:40` classifies each line into
  `OrderStatus.shipped / cancelled / pending` (`constants.dart:109`).

Lab-dip and sampling add a feedback + rematch loop:

| Step | Sampling | Labdip |
|---|---|---|
| Fetch feedback | `Api.fetchSamplingFeedback` (`:125`) | `Api.fetchLabdipFeedback` (`:142`) |
| Fetch per-line feedback | `Api.fetchIndividualSamplingOrderFeedback` (`:143`) | — |
| Fetch rejection reasons | `Api.fetchSamplingRejectionCount` (`:161`) | `Api.fetchLabdipRejectionCount` (`:163`) |
| Submit feedback | `Api.submitSamplingFeedback` (`:168`) | `Api.submitLabdipFeedback` (`:170`) |
| Rematch order | `Api.submitSamplingRematchOrder` (`:188`) | `Api.submitLabDipRematchOrder` (`:190`) |
| Permanent shades | — | `Api.fetchLabdipTableRows` (`:114`) → `F5630111` |

Both feedback writes and both rematch writes go to the same two endpoints as a
fresh order — `ORCH5500092_SupplementalDataEntry` and
`ORCH55CreateStagingData` — differing only in payload. Rematch packs the
permanent shades into `ColorRemark` as
`{orderNumber}-{shade}-{reason}` and reconstructs `RelatedOrder` as
`{order}|{orderType}|{company}|{lineNumber}|{shipToAttention}`.

### 3.6 Invoices and payment

`InvoicesController` (`invoices/invoices_controller.dart`):

```
Api.fetchInvoices(customerNumber, company)          -> ORCH5503B11A_GetInvoices
    └─ internally calls Api.fetchInvoiceReceiptDetailsMap(customerNumber)  // F03B14
Api.fetchInvoicesInProcessing(soldToNumber)         -> F550313Z (EDSP NOT IN {P,E})
```

`fetchInvoices` splits the response into three buckets:

| Bucket | Response key | `isOpen` | `status` |
|---|---|---|---|
| Open | `OpenInvoices` | `true` | `processing` |
| Paid | `PaidInvoice` | `false` | `processing` |
| Hold | `HoldInvoice` | `true` | `onHold` |

**Payment initiation** — `open/invoice_review_dialog.dart:58` (Proceed) and
`open/advance_payment_dialog.dart:71`:

```
batchNumber  = Api.fetchPaymentBatchNumber()        // module 03B / object 05
receiptNumber = "P$batchNumber"

Api.createInvoicePaymentEntry(paymentDetails[])     -> ORCH55_CreateInvoicePaymentEntry
    one entry per selected invoice; Payment_Amount is discountAmount when the
    invoice is in discounted state, else openAmount

if selectedDiscountedAmount == 0:                   // nothing to collect
    Api.updateInvoicePaymentRequest(sp: 'I')        -> ORCH55_InvoicePaymentReqUpdate
else:                                               // real money movement
    Api.updateInvoicePaymentRequest(sp: 'I')
    plainText = "txn-id=…|txn-datetime=…|txn-amount=…|txn-for=payment|
                 wallet-payment-mode=2|return-url=…|cancel-url=…|"
    Api.encryptInputString(plainText)                -> ORCH55_ICICIEncryptProd
    build <form method=POST action=icici gp2c-api/ws/payment>
      hidden walletClientCode = 'WT-1573'
      hidden walletRequestMessage = <encryptedString>
    form.submit()   // browser navigates away
```

The amount is chosen in `InvoiceInfo` and the discounted/open branch is
decided by `invoicesController.selectedDiscountedAmount == 0`
(`invoice_review_dialog.dart:102`).

**Invoice PDF** — `open/open_invoices_list.dart:162,183` and
`paid/paid_invoices_list.dart:127` call `downloadInvoiceWeb` (web bytes) or
`downloadInvoice` (native file), both of which GET
`/download/CAMSInvoicing/{invoiceNumber}_{invoiceType}.pdf` and cache it under
`<appDocuments>/Invoices/`. The PDF is then shown with `pdfrx`.

### 3.7 Salesperson order summary

`OrderSummaryController.orderSummaryDateListener()`
(`home/order_summary_controller.dart:33`) is a 3-call chain, re-run on either
date change (default window: last 7 days):

```
Api.fetchSalsemanCode(soldToNumber)                 // F03012 (GET) x2
   -> salesperson's AC02, then all customers with that AC02
Api.fetchCustomersName(salsemanCustomerList)         // F0101
Api.fetchOrderCustomersByDate(list, nameMap, from, through)   // F47011
```

### 3.8 Status report

`home/home_scaffold.dart:178` → `Api.fetchReportEmailAddress(userId)`
(browse `F01151`, `ETP='E'`, `RCK7=1`, `IDLN=0`, `AN8=userId`) to prefill a
validated email field, then `home_scaffold.dart:232` →
`Api.submitStatusReport(email, fromDate, soldToNumber)` →
`ORCH55_EmailOrderDetailsWrapper`.

---

## 4. Network layer

Two independent `Dio` instances, both declared as `static final` fields of
`Api` (`api.dart:30` and `:50`).

### 4.1 `_dio` — JDE host

```dart
baseUrl: 'https://erp.vardhmanthreads.in/jderest'
// commented alternates: 'https://erptest.vardhmanthreads.in/jderest'
headers: { 'Content-Type': 'application/json',
           'Connection': 'keep-alive',
           'Accept-Encoding': 'gzip, deflate, br',
           'Accept': '*/*' }
sendTimeout / connectTimeout / receiveTimeout: 180s each
validateStatus: (status) => true          // never throws on HTTP error status
receiveDataWhenStatusError: true
```

`validateStatus: (s) => true` means **every** function must branch on
`statusCode` itself, and non-2xx bodies are still parsed. Several functions do
not, and will return empty lists instead of surfacing the error.

### 4.2 Interceptors — `api.dart:73`

A single `InterceptorsWrapper` on `_dio` logs every request and response:

- `onRequest` — method, full path, **all headers**, and `requestOptions.data`
  (the full JSON body, including Sold-To, prices, addresses).
- `onResponse` — status code and the **entire** `response.data` body.

There is a `statusCode == 444` branch intended to log the user out
(`api.dart:98`), but the entire body is commented out, so a 444 does nothing.
Every function treats 444 as a normal non-200 and returns empty.

### 4.3 Session headers

Set in `Api.fetchToken()` (`api.dart:120`) on the shared `_dio` instance:

| Header | Value |
|---|---|
| `JDE-AIS-Auth` | `response.data['userInfo']['token']` |
| `JDE-AIS-Auth-Device` | `"{deviceInfo}_{userId}"` |

`Api.logout()` (`:148`) removes both and POSTs `/v2/tokenrequest/logout`.

Because `_dio` is a static singleton, these headers are process-wide — a
customer switch does not rotate the token.

### 4.4 `_fileDio` — B2B file host

```dart
baseUrl: 'https://b2b.amefird.in:8081'
headers: { 'Authorization': 'Basic dnl0bDpPQUlJSkRvaWpmQCM=' }   // api.dart:34
// commented alternate base: 'https://localhost:8081'
```

### 4.5 Ad-hoc clients

| Client | Where | Auth |
|---|---|---|
| Airtel WhatsApp | `api.dart:242` | `Authorization: Basic TVNfVkFSREhNOlZhcmRobUAyMCMj` (`:244`) |
| ICICI form POST | `invoice_review_dialog.dart:143` | built as a DOM `<form>`, submitted by the browser |

### 4.6 Documented environment switching

`api.dart:53` carries a `TODO` for `erpdev` / `erptest` / `erp`. Payment
switching uses inline `// for PD` / `// for PY` / `// for GITHUB` comments at
`api.dart:2862` and `invoice_review_dialog.dart:127-134,148-172`. There is no
build-time flag; switching is a source edit.

---

## 5. JDE reference data model

The client speaks to JD Edwards through **four** distinct service families.
The `ORCH*` layer is a Vardhman-authored orchestration façade over JDE
business logic; the Data Service layer bypasses it and browses tables directly.

### 5.1 Orchestration services (`/orchestrator/*`)

Named `ORCH55*` because they wrap the `55` (VYTL / B2B) application. These
return curated, named-field JSON and are the preferred path for anything with
business logic.

### 5.2 REST Data Service (`/v2/dataservice`)

Two call styles against the same data store:

**POST — BROWSE.** Body describes a query; response is a rowset.

```jsonc
// request
{
  "maxPageSize": "No Max",         // optional; omitted on some calls
  "targetName": "F4101",           // JDE form / application form ID
  "targetType": "table",
  "dataServiceType": "BROWSE",
  "returnControlIDs": "F4101.LITM|F4101.URCD",   // pipe-separated fields
  "query": {
    "autoFind": true,
    "condition": [                 // implicit AND
      { "controlId": "F4101.SEG1",
        "operator": "EQUAL",       // EQUAL | NOT_EQUAL | LIST | STR_START_WITH
                                     // STR_NOT_BLANK | GREATER_EQUAL | LESS_EQUAL
        "value": [ { "specialValueId": "LITERAL", "content": "..." } ] }
    ]
  }
}
```

**Response envelope:**

```jsonc
{ "fs_DATABROWSE_F4101": { "data": { "gridData": { "rowset": [
    { "F4101_LITM": "A100   MTRRED", "F4101_URCD": "Y" }
] } } } }
```

The envelope key is `fs_DATABROWSE_{targetName}`; each field is
`{targetName}_{CONTROLID}`. **Both names must be derived from `targetName`** —
this is the single most common source of breakage in this file.

**GET — field/filter query** (used twice only):

```
/v2/dataservice/table/F03012?$field=F03012.AN8&$field=F03012.CO&$field=F03012.CUSTS
  &$filter=F03012.AN8%20EQ%20{soldTo}&$filter=F03012.CO%20EQ%2010901
```

`$field` and `$filter` are repeatable; `%20` is an encoded space.

### 5.3 Business Function Service (`/v2/bsfnservice`)

Only ever called as `X0010GetNextNumber`, the JDE "next number" generator.
`inParams[0].value` is the **module**, `inParams[1].value` the **object**.

| Call | Module | Object | Allocates |
|---|---|---|---|
| `fetchLabdipOrderNumber` | `47` | `9` | Lab-dip order |
| `fetchSamplingOrderNumber` | `47` | `6` | Sampling order |
| `fetchDtmOrderNumber` | `47` | `8` | DTM order |
| `fetchBulkOrderNumber` | `47` | `7` | Bulk order |
| `fetchDraftOrderNumber` | `55` | `10` | Draft shell number |
| `fetchPaymentBatchNumber` | `03B` | `05` | Payment batch |

Response: `{ "result": { "output": [ { "value": <int> } ] } }`

### 5.4 AIS media / file upload (`/v2/file/upload`)

`multipart/form-data` with two parts:

| Part | Type | Content |
|---|---|---|
| `file` | binary | attachment bytes |
| `moAdd` | `application/json` | `{ moStructure, moKey:[…], formName, version, file:{ fileName } }` |

Fixed across all four order types: `moStructure: 'GT00092'`,
`version: 'VYTL0016'`, `formName: 'P00092_W00092D'`, and
`moKey: 'QTX|QT|||$orderNumber|$soldTo|1001|'`.

### 5.5 `F00092` — Supplemental Data, used as a key/value extension table

This is the app's most-used table and deserves special attention. JDE
Supplemental Data lets an app store arbitrary typed records against any
numeric/alpha key. Vardhman partitions them with two discriminators:

| Field | Meaning |
|---|---|
| `SDB` | Supplemental Database Code — which logical collection |
| `TYDT` | Type Data — the record type within it |
| `KY` | Alpha key 1 (e.g. Sold-To, billing-type code) |
| `SBN1` | Numeric key 1 (e.g. order number) |
| `SBA1`, `SBA2` | Alpha keys 2/3 |
| `RMK`, `RMK2`, `RMK3` | Remark 1/2/3 — the payload |
| `UKID` | Unique key id |

Collections in use:

| `SDB` | `TYDT` | Stores | Read by |
|---|---|---|---|
| `LDF` | `LD` | Lab-dip feedback: `SBA1` A/N, `SBA2` line, `RMK` reason | `fetchLabdipFeedback` |
| `SAF` | `SA` | Sampling feedback, same shape | `fetchSamplingFeedback` |
| `BY` | `BY` | Buyer dictionary: `KY` code, `RMK` light source 1, `RMK2` light source 2, `RMK3` display name | `fetchBuyerInfos` |
| `MR` | `MR` | Merchandiser names for a Sold-To (`SBN1`) | `fetchMerchandiserNames` |
| `BT` | `BT` | Billing-type flag: `SBA2='D'`, `KY`=Sold-To → ship-from-plant | `getBillingType` |
| `QTX` | `QT` | PO-document attachment pointer | `supplementalDataEntry` |
| `LDF` | `LD` / `SAF` | `RMK2` also carries the B2B order reference for rejections | `fetchLabdipRejectionCount` |

---

## 6. API catalogue

`R` = response. Base URLs as in §4 unless stated. All `_dio` calls are
`POST` unless marked `GET`.

### 6.1 Authentication

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchToken` `:120` | `/v2/tokenrequest` | `username`, `password`, `deviceName` | `{ userInfo: { token } }` — sets `JDE-AIS-Auth`, `JDE-AIS-Auth-Device` |
| `logout` `:148` | `/v2/tokenrequest/logout` | `{}` | removes both auth headers |
| `generateAndSendOtp` `:169` | `/orchestrator/ORCH55_SendOTPB2BPortal` | `OTP`, `Mobilenumber` | ignored; **returns the OTP to the caller** |

### 6.2 User, customer, address

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchUserData` `:418` | `ORCH5541001_GetUserData` | `{ User }` | `Get_User_Data[0]`: `User`, `UserName`, `UserRole`, `MobileOrPortalFlag`, `MobileNumber`, `SendSMSYN`, `WhatAppNumber`, `SendWAPYN`, `EmailAddresses`, `Company Code`, `Company`, `UserCategory`, `DiscountPercent` |
| `fetchBillingAddress` `:705` | `ORCH550116_Get_SoldTo_Address` | `{ "Address Number Input" }` | two keys: `Get_SoldTo_Address[0]` (Alpha Name, Address Line 1-4, City, Postal Code, State, State Code, Country, Country Code) **and** `ORCH550005_GetUDC_Repeating[0].ORCH550005_GetUDC` (`AC01`, `Branch Plant`) |
| `fetchDeliveryAddresses` `:754` | `ORCH550101K_GetDeliveryAddress` | `SoldToAddress`, `Company` | `DeliveryAddress[]` with `DeliveryAddressNumber` |
| `isCustomerActive` `:2741` | `GET /v2/dataservice/table/F03012` (`CUSTS`, company `10901`) | query params | `F03012_CUSTS != '1'` |
| `fetchSalsemanCode` `:3067` | `GET .../table/F03012` ×2 (`AC02`) | query params | salesperson's customers |
| `fetchCustomersName` `:3107` | `/v2/dataservice` `F0101` | `F47011.AN8 LIST …` | `F0101_AN8` → `F0101_ALPH` |

`fetchBillingAddress` has a side effect: it persists `AC01` to
`SharedPreferences['rxZoneAC01']` (`:721`), which then scopes every email lookup.

### 6.3 Catalog and item reference

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchItemCatalogInfo` `:1440` | `ORCH55_GetItemCatalogInfo` | `{}` | `GetItemCatalogInfo[]`: Article, UOM, Category(+Desc), SubSegment(+Desc), Brand(+Desc), Substrate(+Desc), `Value_1..Value_5` → length, ticket, tex, variant, count |
| `fetchShades` `:287` | `/v2/dataservice` `F4101` | SEG1=article, SEG2=uom, SEG3 `STR_START_WITH`, SRP1=`IND`, PRP1 LIST [Z,M], STKT `NOT_EQUAL O` | `F4101_SEG3[]` |
| `fetchUnitPrice` `:378` | `ORCH554074_GetUnitPrice` | `Address_Number`, `Ship_To`, `Item_Number`, `Business_Unit`, `Price_Effective`, `P4074_Version:'VYTL2001'` | `GetUnitPrice[]`; **client sums only `Adj Name ∈ {SBP, DISC1, DISC2, CDIS}`** |
| `validateItemNumbers` `:1263` | `/v2/dataservice` `F4101` | `LITM LIST`, SRP1=`IND`, PRP1 LIST, STKT | `F4101_LITM[]` — valid subset |
| `fetchItemMaster` `:2952` | `/v2/dataservice` `F4101` | SRP1=`DOM`, PRP1 LIST, STKT, SEG1-3 `STR_NOT_BLANK`, UPMJ `GREATER_EQUAL` | `F4101_LITM, URCD, DSC1, UPMJ` → splits item into article/uom/shade |
| `fetchUoMDescriptions` `:2898` | `/v2/dataservice` `F0005` | SY=`55`, RT=`K2` | `F0005_KY` → `F0005_DL01` |
| `fetchBuyerInfos` `:1779` | `/v2/dataservice` `F00092` | TYDT=`BY`, SDB=`BY` | `KY`, `RMK`, `RMK2`, `RMK3` |
| `fetchMerchandiserNames` `:1835` | `/v2/dataservice` `F00092` | TYDT=`MR`, SDB=`MR`, SBN1=soldTo | `F00092_RMK[]` |
| `getBillingType` `:2503` | `/v2/dataservice` `F00092` | SDB=`BT`, TYDT=`BT`, SBA2=`D`, KY=soldTo | `F00092_UKID[]` (non-empty ⇒ ship from plant) |
| `fetchItemQuantity` `:2711` | `JDE_ORCH_Customersearch_ItemAvailability` | `Branch_Plant`, `2nd Item Number 1` | `ServiceRequest2.fs_P41202_W41202A…rowset[0].z_QAVAL_47.internalValue` |

### 6.4 Number allocation

`/v2/bsfnservice` — see §5.3 for the six module/object pairs. Functions:
`fetchLabdipOrderNumber` `:1596`, `fetchSamplingOrderNumber` `:1623`,
`fetchDtmOrderNumber` `:1650`, `fetchBulkOrderNumber` `:1677`,
`fetchDraftOrderNumber` `:1704`, `fetchPaymentBatchNumber` `:1731`.

### 6.5 Order writes — `ORCH55CreateStagingData`

Six functions share this single endpoint, distinguished by `DocumentType`:

| Function | `DocumentType` | Extra payload fields |
|---|---|---|
| `submitLabdipOrder` `:2172` | `LD` | `Quantity` hard-coded `1`; `BillingType` from the line |
| `submitSamplingOrder` `:2237` | `SA` | `Quantity` hard-coded `1`; `BillingType` from the line |
| `submitLabDipRematchOrder` `:2353` | `LD` | `ItemNumber` from the order line; `ColorRemark` = `order-permanentShades-reason`; `RelatedOrder` 5-segment |
| `submitSamplingRematchOrder` `:2424` | `SA` | as above, single `permanentShade` |
| `submitDtmOrder` `:2562` | `DT` | real `Quantity`; `RequestDate` |
| `submitBulkOrder` `:2637` | `BK` | real `Quantity`; `RequestDate` |

Common envelope:

```jsonc
{ "Detail": [ {
    "BatchNumber":  "B2BB<orderNumber>",
    "Company":     "<companyCode>",
    "SoldTo":      "<soldTo>",
    "ShipTo":      "<shipTo>",
    "BranchPlant": "<branchPlant>",
    "ItemNumber":  "<article7><uom5><shade>",
    "Quantity":    1,
    "OrderTakenBy":"<userRole>",
    "LineNumber":  <index+1+1000>,      // staging lines start at 1001
    "DocumentType":"BK",
    "SourceFlag":  "B",
    "MerchandiserName": "<merch>|<orderNumber>[-<poNumber>]",
    "LightSourceRemark": "<lightSource1>",
    "ColorRemark":  "<pipe-joined>",
    "BillingType":  "B" | "D",
    "EndUse":       "<buyerCode>" | "OTH",
    "RelatedOrder": "| | | |<colorName>[-OTH-<buyer>]",
    "RequestDate":  "MM/dd/yyyy"          // DT/BK only
} ] }
```

`EndUse` becomes `OTH` whenever `buyerCode` is empty. For `BK`/`DT`,
`MerchandiserName` carries the PO number and `RelatedOrder` carries the colour
name. For `LD`/`SA` the PO number and colour are dropped from those fields.

### 6.6 Order reads

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchOrders` `:1136` | `ORCH5542001_GetOrderStatus` | `SoldTo`, `FromOrderDate`, `ToOrderDate` (now-180d → now) | `GetOrderStatus[]`: OrderNumber, OrTy, OrderCo, OrderDate, OrderReference, HoldCode, ShipTo, QuantityOrdered/Shipped/Canceled/BackOrder, OrderStatus, OrderAmount, DTMOrderYN, InderntOrderYN, CustomerPO, MerchandiserName |
| `fetchOrderDetails` `:1190` | `ORCH5542002_GetOrderDetail` | `Order Number`, `OrderType`, `OrderCompany` | `OrderDetail[]`: Company, Order, Type, Line Number, Date Shipped, Date Invoiced, Item, Item Description, Description2, Next/Last Status(+Desc), Quantity Ordered/Shipped/Canceled/Backordered, Invoice(+Type/+Company), WorkOrder, Catalog Name, WOStatus, OrderLineReference, WorkOrderType, End Use, Unit/Extended Price, Print Message, ShipToAttention |
| `fetchLabdipTableRows` `:1332` | `/v2/dataservice` `F5630111` | `DOCO LIST` work orders | `F5630111_WCP3` permanent shade, `REFERENC`, `DOCO` |
| `fetchSamplingTableRows` `:1386` | `/v2/dataservice` `F5630111` | identical | identical shape |
| `fetchOrderCustomersByDate` `:3154` | `/v2/dataservice` `F47011` | EDDT range, EDCT LIST [LD,DT,BK], AN8 LIST | `F47011_AN8, EDBT (portal order), DOCO (JDE order), EDCT, EDDT, PNID` |

### 6.7 Feedback and supplemental data

| Dart function | Endpoint | Key fields | Meaning |
|---|---|---|---|
| `fetchLabdipFeedback` `:799` | `/v2/dataservice` `F00092` | SDB=`LDF`, TYDT=`LD`, SBN1 LIST | `SBA1` A/N, `SBA2` line, `RMK` reason |
| `fetchSamplingFeedback` `:865` | `F00092` | SDB=`SAF`, TYDT=`SA`, SBN1 LIST | same |
| `fetchIndividualSamplingOrderFeedback` `:931` | `F00092` | + `SBA2 LIST` | per-line variant |
| `fetchLabdipRejectionCount` `:1007` | `F00092` | + `RMK2 EQUAL b2bOrderReference` | `RMK2` rejection reasons |
| `fetchSamplingRejectionCount` `:1070` | `F00092` | SDB=`SAF`, TYDT=`SA`, `RMK2 EQUAL` | same |
| `submitLabdipFeedback` `:2303` | `ORCH5500092_SupplementalDataEntry` | SDB code `LDF`, action `A`, `mnNumericKey1`=order, `szAlphaKey1`=A/N, `szAlphaKey2`=line, `szDataType`=`LD`, `szRemark1`=reason, `szRemark2`=b2bOrderReference | 200 |
| `submitSamplingFeedback` `:2328` | same | code `SAF`, type `SA` | 200 |
| `supplementalDataEntry` `:1485` | same | `szSupplementalDatabaseCode`, `cActionCode:'1'`, `mnNumericKey1`, `szAlphaKey1`, `szDataType`, `jdEndingEffectiveDate`, `szRemark1`, `mnNumericKey2`, `jdEffectiveDate`, `szRemark2` | 200 |
| `supplementalDataWrapper` `:1519` | `ORCH55_SupplementalDataWrapper` | `SDB Code 1`, `Ty Dt 1`, `LineNo`, `OrderNo`, `Customer`, `EmailAddress`, `filetype` | 200 |

### 6.8 Email routing

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchLabdipEmailAddresses` `:458` | `/v2/dataservice` `F5501002` | FLAG=`P`, DL011=`LAB`, A100=`BRANCH`, AA10=`rxZoneAC01` | `F5501002_EMAL` joined by `,` |
| `fetchSamplingEmailAddresses` `:519` | `F5501002` | **identical filter** | identical |
| `fetchBulkDtmEmailAddresses` `:580` | `F5501002` | FLAG=`P`, DL011=`PODOC`, A100=`BRANCH`, AA10=zone | `F5501002_EMAL` |
| `fetchReportEmailAddress` `:641` | `/v2/dataservice` `F01151` | ETP=`E`, RCK7=`1`, IDLN=`0`, AN8=userId | `F01151_EMAL` |

`fetchLabdipEmailAddresses` and `fetchSamplingEmailAddresses` are
**byte-for-byte identical** in filter (`api.dart:472` vs `:533`); the
`sampling` one has no effect.

### 6.9 Invoices and payment

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `fetchInvoices` `:2001` | `ORCH5503B11A_GetInvoices` | `CustomerNumber`, `Company` | `OpenInvoices[]`, `PaidInvoice[]`, `HoldInvoice[]` |
| `fetchInvoiceReceiptDetailsMap` `:1949` | `/v2/dataservice` `F03B14` | `AN8 EQUAL` | `F03B14_CKNU`, `DOC`, `DMTJ` (yyyymmdd) → map invoice→receipt |
| `fetchInvoicesInProcessing` `:1892` | `/v2/dataservice` `F550313Z` | `AN8 EQUAL`, `EDSP NOT_EQUAL P`, `EDSP NOT_EQUAL E` | `F550313Z_DOC[]` |
| `fetchPaymentBatchNumber` `:1731` | `/v2/bsfnservice` | module `03B` | batch int |
| `createInvoicePaymentEntry` `:1758` | `ORCH55_CreateInvoicePaymentEntry` | `{ InvoicePayment: [ { Batch_Number, Company, Source_Mobile_Portal:'P', Customer_Number, Invoice_Number, Invoice_Type, Invoice_Company, Receipt_Number, Payment_Amount, Payment_Reference, Payment_Remark, Bank_Account, Payment_Date } ] }` | 200 |
| `updateInvoicePaymentRequest` `:2138` | `ORCH55_InvoicePaymentReqUpdate` | `Batch_Number`, `Receipt_Number`, `Company`, `Customer_Number`, `S_P`, `Payment_Reference`, `Payment_Remark`, `Source_Mobile_Portal:'M'` | 200 |
| `encryptInputString` `:2859` | `ORCH55_ICICIEncryptProd` | `{ plainText }` | `{ encryptedText }` |
| `getPaymentStatus` `:2879` | `ORCH55_GetPaymentWrapper` | `{ ReceiptNumber: "txn-id=$receiptNumber|" }` | `{ decryptedText }` |

`getPaymentStatus` is defined but **not called anywhere** in the app.

### 6.10 Notifications

| Dart function | Endpoint | Payload | Response |
|---|---|---|---|
| `sendOrderEntrySMS` `:222` | `ORCH55_SendSMSNotification` | `OrderNumber`, `Mobilenumber` | ignored |
| `sendOrderEntryWhatsApp` `:237` | Airtel `…/whatsapp-manager/v1/template/send` | `templateId:'01jj1c8ddqvjdd5v9hp63d850p'`, `to`, `from:'9313503051'`, `message.headerVars=[orderNumber]`, `message.variables=[orderNumber]` | logged only |

A direct Airtel Bulk SMS integration is present but **fully commented out**
(`api.dart:191-220`).

### 6.11 File service — `https://b2b.amefird.in:8081`

| Dart function | Method | Path | Response |
|---|---|---|---|
| `listFiles` `:2762` | GET | `/list/{directoryName}` | `{ files: [...] }` |
| `_downloadFile` `:2781` | GET | `/download/CAMSInvoicing/{fileName}` | bytes → cached to `<appDocuments>/Invoices/` |
| `_downloadFileWeb` `:2819` | GET | same | bytes in memory |
| `uploadMediaAttachment` `:1549` | POST | `/v2/file/upload` (on `_dio`, not `_fileDio`) | JSON |

`listFiles` is not referenced by any caller. `_downloadFile` short-circuits and
returns the local copy if it already exists, so PDFs never refresh.

---

## 7. JDE forms & tables reference

| Code | JDE object | Fields used | Role here |
|---|---|---|---|
| `F0005` | UOM Conversion Setup | `KY`, `DL01`, `SY`, `RT` | UOM → description |
| `F00092` | Supplemental Data | `SDB`, `TYDT`, `KY`, `UKID`, `SBN1`, `SBA1`, `SBA2`, `RMK`, `RMK2`, `RMK3` | App key/value store: buyers, merchandisers, feedback, billing type, PO pointers |
| `F0101` | Customer Master | `AN8`, `ALPH` | Customer number → name |
| `F01151` | Report/email setup | `ETP`, `RCK7`, `IDLN`, `AN8`, `EMAL` | Status-report recipient |
| `F03012` | Customer Master by Ship-To | `AN8`, `CO`, `AC02`, `CUSTS` | Company `10901`; salesperson rollup, active check |
| `F03B14` | Sales Invoice / Receipt | `CKNU`, `DOC`, `DMTJ`, `AN8` | Receipt number + date per invoice |
| `F4101` | Item Master (Business Unit) | `LITM`, `SEG1` article, `SEG2` UOM, `SEG3` shade, `SRP1`, `PRP1`, `STKT`, `URCD`, `DSC1`, `UPMJ` | Item validation, shades, item master |
| `F47011` | Sales Order Master | `AN8`, `EDBT`, `DOCO`, `EDCT`, `EDDT`, `PNID` | Portal↔JDE order reconciliation |
| `F5501002` | Email distribution setup | `EMAL`, `FLAG`, `DL011`, `A100`, `AA10` | Lab / PODOC recipient lists, zone-scoped |
| `F550313Z` | Sales invoice (processing) | `DOC`, `AN8`, `EDSP` | In-processing invoices |
| `F5630111` | Lab-dip / sampling work order | `WCP3`, `REFERENC`, `DOCO` | Permanent shade per work order |
| `P41202/W41202A` | Item availability | `z_QAVAL_47` | On-hand quantity by branch plant |

### Document type codes

| Code | Meaning | Display (`constants.dart:103`) |
|---|---|---|
| `LD` | Lab Dip Order | Lab Dip Order |
| `SA` | Sampling Order | (sampling) |
| `DT` | DTM Order | DTM Order |
| `BK` | Bulk Order | Bulk Order |

### Notable field codes

| Code | Meaning |
|---|---|
| `AN8` | Customer (Sold-To) number |
| `CO` | Company |
| `AC02` | Salesperson code |
| `CUSTS` | Customer status |
| `LITM` | Item number |
| `SEG1/2/3` | Item segments — article, UOM, shade |
| `SRP1` | Item type; `IND` = industrial, `DOM` = domestic |
| `PRP1` | Procurement type; `Z`/`M` accepted |
| `STKT` | Stock type; `O` (obsolete) excluded |
| `URCD` | User-defined shade-card flag |
| `UPMJ` | Date last updated (`yyyymmdd`) |
| `DCT`/`EDCT` | Document type |
| `EDSP` | Payment status; `P`/`E` excluded from in-processing |
| `EMAL` | Email address |
| `CKNU` | Check / receipt number |
| `DMTJ` | Document date (`yyyymmdd`) |

---

## 8. Local database (Drift)

Database `vytl`, `schemaVersion: 1` (`drift/database.dart:23`). Only **six** of
the ten table classes are registered in `@DriftDatabase`:

```dart
@DriftDatabase(tables: [UserDetails, BillingDetails, DeliveryDetails,
                        ItemMaster, CartTable, DraftTable])
```

`catalog_items.dart`, `invoice_details.dart`, `order_details.dart`, and
`related_customers.dart` define tables that are **never registered and never
queried** — dead schema. `CartTable` and `ItemMaster` are registered but have
no writer in the app; `ItemMaster` is only ever produced by the unused
`fetchItemMaster()`.

### Registered tables

| Table | Primary key | Columns | Actual use |
|---|---|---|---|
| `UserDetails` | `soldToNumber` | 13 | Written at login (`insertOrReplace`), read by `_checkUser()` |
| `DraftTable` | `id` autoinc | 32 | **The working store** for all four order types |
| `BillingDetails` | `soldToNumber` unique | 9 | unused |
| `DeliveryDetails` | `soldToNumber` unique | 9 | unused |
| `ItemMaster` | `itemNumber` | 8 | unused |
| `CartTable` | `soldTo, article, uom, shade` | 5 | unused |

### `DraftTable` columns

`soldTo`, `orderType`, `orderNumber`, `merchandiser`, `lineNumber`, `shade`,
`buyer`, `buyerCode`, `firstLightSource`, `secondLightSource`, `substrate`,
`tex`, `ticket`, `brand`, `article`, `requestType`, `colorName`, `lab`,
`remark`, `billingType`, `uom`, `endUse`, `quantity`, `colorRemark`,
`lastUpdated`, `qtxFileBytes` (blob), `qtxFileName`, `requestedDate`,
`poNumber`, `poFileName`, `poFileBytes` (blob), `unitPrice`.

Two blob columns hold **raw PO document bytes in the local database** —
`poFileBytes` and `qtxFileBytes`. On a shared or backed-up device that is
unencrypted document storage.

Reads are reactive: `BulkEntryController` (`:170`) and its three siblings
`.watch()` their draft rows, so a `DraftTable` insert/update/delete repaints
the line table immediately.

---

## 9. SharedPreferences keys

| Key | Type | Written by | Contents |
|---|---|---|---|
| `password` | `String` | `login_controller.dart:247` | the user password, **plaintext** |
| `rxZoneAC01` | `String` | `api.dart:721` | zone/cost-centre `AC01` from the billing address; scopes all `F5501002` lookups |
| `selectedCustomer_{soldToNumber}` | `String` | `user_controller.dart:102` | currently selected customer |
| `lastSelectedAddress_{soldToNumber}` | `String` (JSON) | `user_controller.dart:62` | selected delivery address, matched by full JSON equality on next login |

---

## 10. Trigger map: function → API → caller

Reverse index of every network call site. `view` = triggered from a widget
build/`initState`; `ctrl` = from a controller method.

### Bootstrap / auth

| API | Caller | Line |
|---|---|---|
| `Api.logout` | `LoginController.refreshToken` | `login_controller.dart:134` |
| `Api.fetchToken` | `LoginController.refreshToken` | `login_controller.dart:140` |
| `Api.fetchUserData` | `LoginController.validateUser` | `login_controller.dart:160` |
| `Api.generateAndSendOtp` | `LoginController.validateUser` | `login_controller.dart:164` |

### Shared startup (fires on every login via `_logIn`)

| API | Caller | Line |
|---|---|---|
| `fetchDraftOrderNumber` | `OrderReviewController()` ctor | `order_review_controller.dart:31` |
| `fetchUoMDescriptions` | `OrderReviewController()` ctor | `order_review_controller.dart:21` |
| `fetchItemCatalogInfo` | `CatalogController.refreshItems` | `catalog_controller.dart:30` |
| `fetchBillingAddress` | `UserController.refreshDeliveryAddresses` | `user_controller.dart:34` |
| `fetchDeliveryAddresses` | `UserController.refreshDeliveryAddresses` | `user_controller.dart:36` |
| `fetchUserData` | `UserController.selectCustomer` | `user_controller.dart:82` |

### Order entry — per type

Each of `bulk`, `labdip`, `sampling`, `dtm` has its own `*_entry_controller`:

| API | Bulk | Labdip | Sampling | DTM |
|---|---|---|---|---|
| `fetchBuyerInfos` | `:192` | `:189` | `:189` | `:187` |
| `fetchMerchandiserNames` | `:196` | `:193` | `:193` | `:191` |
| `fetchShades` | `:249` | `:258` | `:258` | `:244` |
| `fetchUnitPrice` | `:274`, `:946` | — | — | — |
| `validateItemNumbers` | `:897` | — | — | — |
| `fetch*OrderNumber` | `:783` | `:896` | `:896` | `:767` |
| `fetch*EmailAddresses` | `:786` | `:919` | `:919` | `:770` |
| `uploadMediaAttachment` | `:787` | `:904` | `:904` | `:771` |
| `supplementalDataEntry` | `:797` | `:921` | `:921` | `:781` |
| `supplementalDataWrapper` | `:807` | `:931` | `:931` | `:791` |

All four live in the controller **constructor** except the price/shade lookups
and the submit-path calls. Bulk is the only type that resolves unit price and
validates xlsx item numbers.

### Order submit and notify — `order_review_controller.dart`

| API | Line | Precondition |
|---|---|---|
| `submitLabdipOrder` | `:53` | — |
| `sendOrderEntrySMS` | `:80` | `canSendSMS` |
| `sendOrderEntryWhatsApp` | `:87` | `canSendWhatsApp` |
| `submitSamplingOrder` | `:114` | — |
| `sendOrderEntrySMS` | `:141` | `canSendSMS` |
| `sendOrderEntryWhatsApp` | `:148` | `canSendWhatsApp` |
| `submitDtmOrder` | `:175` | — |
| `sendOrderEntrySMS` | `:199` | `canSendSMS` |
| `sendOrderEntryWhatsApp` | `:206` | `canSendWhatsApp` |
| `submitBulkOrder` | `:231` | — |
| `sendOrderEntrySMS` | `:256` | `canSendSMS` |
| `sendOrderEntryWhatsApp` | `:263` | `canSendWhatsApp` |

### Order tracking

| API | Caller | Line |
|---|---|---|
| `fetchOrders` | `OrdersController` | `orders_controller.dart:37` |
| `fetchOrderDetails` | `BulkController` / `DtmController` / `LabdipController` / `SamplingController` | `bulk_controller.dart:115`, `dtm_controller.dart:115`, `labdip_controller.dart:129`, `sampling_controller.dart:112` |
| `fetchLabdipTableRows` | `LabdipController` | `labdip_controller.dart:114` |
| `fetchLabdipFeedback` | `LabdipController` | `labdip_controller.dart:142` |
| `fetchLabdipRejectionCount` | `LabdipController` | `labdip_controller.dart:163` |
| `submitLabdipFeedback` | `LabdipController` | `labdip_controller.dart:170` |
| `submitLabDipRematchOrder` | `LabdipController` | `labdip_controller.dart:190` |
| `fetchSamplingFeedback` | `SamplingController` | `sampling_controller.dart:125` |
| `fetchIndividualSamplingOrderFeedback` | `SamplingController` | `sampling_controller.dart:143` |
| `fetchSamplingRejectionCount` | `SamplingController` | `sampling_controller.dart:161` |
| `submitSamplingFeedback` | `SamplingController` | `sampling_controller.dart:168` |
| `submitSamplingRematchOrder` | `SamplingController` | `sampling_controller.dart:188` |
| `fetchDraftOrderNumber` | `sampling_orders_view.dart:48`, `labdip_orders_view.dart:47`, `dtm_orders_view.dart:47`, `bulk_orders_view.dart:47` | — |

### Invoices and payment

| API | Caller | Line |
|---|---|---|
| `fetchInvoices` | `InvoicesController.refreshInvoices` | `invoices_controller.dart:67` |
| `fetchInvoicesInProcessing` | `InvoicesController` | `invoices_controller.dart:74` |
| `fetchPaymentBatchNumber` | `InvoiceReviewDialog` / `AdvancePaymentDialog` | `invoice_review_dialog.dart:67`, `advance_payment_dialog.dart:71` |
| `createInvoicePaymentEntry` | same | `invoice_review_dialog.dart:73`, `advance_payment_dialog.dart:77` |
| `updateInvoicePaymentRequest` | same | `invoice_review_dialog.dart:103,115`, `advance_payment_dialog.dart` |
| `encryptInputString` | same | `invoice_review_dialog.dart:137`, `advance_payment_dialog.dart:108` |
| `downloadInvoiceWeb` | `open_invoices_list.dart` | `:162` |
| `downloadInvoice` | `open_invoices_list.dart`, `paid_invoices_list.dart` | `:183`, `paid_invoices_list.dart:127` |

### Reporting

| API | Caller | Line |
|---|---|---|
| `fetchSalsemanCode` | `OrderSummaryController.fetchSalsemanCode` | `order_summary_controller.dart:24` |
| `fetchCustomersName` | `OrderSummaryController.fetchCustomersName` | `order_summary_controller.dart:30` |
| `fetchOrderCustomersByDate` | `OrderSummaryController.orderSummaryDateListener` | `order_summary_controller.dart:38` |
| `fetchReportEmailAddress` | `home_scaffold.dart` Status Report dialog | `:178` |
| `submitStatusReport` | `home_scaffold.dart` Status Report Submit | `:232` |

### Defined but never called

Verified by grep across `lib/` excluding `api.dart`:

| API | Line | Note |
|---|---|---|
| `getPaymentStatus` | `:2879` | no payment-status polling exists |
| `listFiles` | `:2762` | file-service directory listing unused |
| `fetchItemQuantity` | `:2711` | item availability lookup unused |
| `isCustomerActive` | `:2741` | no Sold-To validity check at login |
| `fetchItemMaster` | `:2952` | populates the unread `ItemMaster` table |
| `fetchSamplingTableRows` | `:1386` | lab-dip equivalent (`F5630111`) **is** used, so the permanent-shade path exists only for lab dip |

Note `getBillingType` (`:2503`) has no external caller but is invoked
internally by `submitDtmOrder` (`:2574`) and `submitBulkOrder` (`:2649`).

---

## 11. Security findings

Ordered by severity.

1. **OTP is not a server challenge.** `generateAndSendOtp` (`:169`) generates
   the OTP locally with `math.Random().nextInt(9999)`, sends it to
   `ORCH55_SendOTPB2BPortal`, **and returns it to the caller**.
   `LoginController.validateOtp` (`:215`) then compares the typed value against
   that client-held string. Anyone with the app binary can read the OTP, and a
   four-digit code exhausts in 10⁴ attempts. The commented `// _otp = "1234";`
   at `:173` is still in the file.

2. **Service credentials are compiled into the binary.**
   - `JDEMAPP` / `AppSecure#2` — `api.dart:127-128`
   - `Authorization: Basic dnl0bDpPQUlJSkRvaWpmQCM=` — `api.dart:34`
   - `Authorization: Basic TVNfVkFSREhNOlZhcmRobUAyMCMj` — `api.dart:244`

3. **The user password is stored in plaintext.** `setPassword` (`:247`) writes
   `SharedPreferences['password']`, and `_checkUser` (`:102`) reads it back on
   every launch to auto-fill the password prompt.

4. **Full request and response bodies are logged.** The interceptor at
   `api.dart:73-118` writes `requestOptions.data` and the entire
   `response.data` for every call — Sold-To numbers, prices, delivery
   addresses, invoice amounts, and the `Authorization` headers themselves —
   through `dart:developer log`.

5. **Session expiry is a no-op.** The `statusCode == 444` handler
   (`api.dart:98-113`) is entirely commented out. A 444 returns empty lists and
   empty drafts from every read function, and the UI presents it as "no data"
   rather than "session expired".

6. **No server-side authorization.** Because all validation is client-side
   (`validateInputs()` in the entry controllers, `validateItemNumbers` filtering
   after the fact), a modified client can submit any `Quantity`, `SoldTo`, or
   `ItemNumber`. `DocumentType` and `SourceFlag: 'B'` are client-supplied.

7. **PDF cache never invalidates.** `_downloadFile` (`:2795`) returns an
   existing local file without re-fetching, so a corrected or re-issued invoice
   PDF is never seen again on that device.

8. **Binary documents at rest unencrypted.** `DraftTable.poFileBytes` and
   `qtxFileBytes` hold PO documents in the Drift database; on web these land in
   IndexedDB, on mobile in the app sandbox — neither encrypted by the app.

9. **Dart source ships commented environment toggles** for base URLs, payment
   gateways, WhatsApp credentials, and `// for GITHUB` payment return URLs
   (`api.dart:2862`, `invoice_review_dialog.dart:127-134`). Any build of this
   source carries the production and UAT credentials and endpoints.

---

## 12. Bugs & inconsistencies observed

1. **`fetchLabdipEmailAddresses` and `fetchSamplingEmailAddresses` are
   identical** (`api.dart:472` vs `:533`) — same `DL011: 'LAB'`. Lab-dip and
   sampling documents both go to the lab list.

2. **`fetchInvoices` response keys are not uniform.** Open and Hold rows use
   `Customer` and `InvoiceDiscountAvailable`; Paid rows use `CustomerNumber` and
   `InvoiceDiscountAmount` (`:2029` vs `:2065`). Any future addition that reads
   `Customer` from a paid row will get `null`.

3. **Order numbers are consumed on failure.** `submitOrder` allocates via
   `fetchBulkOrderNumber()` **before** the staging POST. If the POST fails the
   number is burned and the draft is retained, so retrying allocates another.

4. **Price is a client-side sum.** `fetchUnitPrice` (`:403`) totals only
   `SBP`, `DISC1`, `DISC2`, `CDIS` adjustments and discards every other row the
   pricing engine returns. The displayed unit price can differ from the ERP's.

5. **Dead schema.** Four Drift tables are never registered; two registered
   tables are never written. `fetchItemMaster` populates `ItemMaster`, which
   nothing reads.

6. **Duplicated entry controllers.** The four `*_entry_controller.dart` files
   are near-copies (~1000 lines each). Bulk has diverged with xlsx import and
   unit pricing; the other three have no pricing at all, so their lines submit
   with `unitPrice: null`.

7. **`_dio` is a static singleton with mutable headers.** Switching customer
   via `UserController.selectCustomer` does not re-issue the token, and a
   concurrent logout clears the auth headers for in-flight requests.

8. **Error handling is silent.** Almost every function `catch`es, logs, and
   returns an empty list or `null`. With `validateStatus: (s) => true` a 500
   body is parsed the same as a 200, and `fetchUoMDescriptions` (`:2943`) will
   **throw** on a non-200 because `responseData` stays `null` and the
   dereference is outside the `try`.

9. **Lab-dip and sampling always submit `Quantity: 1`** (`:2198`, `:2263`) —
   correct by design for swatches, but it means `quantity` in `DraftTable` is
   ignored for those two types.

10. **Environment switching is a source edit.** There is no `--dart-define` or
    flavor; moving between `erptest`/`erp` and PD/PY payments requires editing
    tracked files.
