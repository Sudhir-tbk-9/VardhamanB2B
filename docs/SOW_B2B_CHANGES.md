# SOW B2B — Changes Made and How to Verify on the UI

Source of tasks: `docs/SOW MAPP and B2B-Priority (1).xlsx`, sheet **B2B**.

**Rules followed**
- No mock, hardcoded or sample data was added.
- Every value comes from an existing JDE endpoint in `docs/ARCHITECTURE_AND_API.md` §6 or from a JDE dataservice call.
- Items without a JDE source were stopped and reported (Sno 7, and the receipt email in Sno 13).
- Committed on branch `fix/py-bugs`. Fixes made after the PY deployment are listed under [PY fixes and improvements](#py-fixes-and-improvements-branch-fixpy-bugs).

**Build status**
- `flutter analyze`: 21 issues, all already there before this work. None comes from the new code.
- `flutter build web`: compiles.
- Nothing has been run against JDE or tested end to end yet. Use the click-through tables below on the test environment.

---

## Status summary

| Sno | Requirement | Status | Where to look in the app |
|---|---|---|---|
| 2 | Excel upload from any source (.xlsx/.xls/.csv), row errors, fix and partial order, price check | Done | ORDERS → Bulk → New Order → **Import Excel** |
| 4 | Multiple Ship-To, re-pricing per Ship-To | Done; JDE config to confirm | ORDERS → Bulk → New Order → **Ship To** dropdown |
| 14 | UOM picked automatically from Article + Shade | Done (Bulk, DTM) | New Order → Article + Shade → **UOM** |
| 5 | Recycled "R" article → "Direct delivery - TC required" | Done; JDE handling to confirm | Bulk New Order → R-article → **checkbox** |
| 13 | Payment: PO field and search, knock-off, SMS | Done except receipt email (no JDE endpoint) | Left rail **Open** / **Paid** |
| 10 | Keep Article/UOM after Add Line, cursor back to Shade | Done (Bulk) | Bulk New Order → **Add Line** |
| 6 | Order status on top, invoice date, Shade/Buyer search, scrollbars | Done | ORDERS → Bulk → click an order |
| 11 | UI colour options | Done (12 themes, each with a pattern and background photo; default Thread Spectrum) | Account menu → **Theme** |
| 7 | Segment popup after login | Done segment-wise; **customer-wise mapping pending** (no JDE source) | Popup after login; segment button in the top bar |
| Extra | Loading indicator for slow JDE calls | Done | Everywhere (top bar + table spinner) |

---

## Before you start (test data needed)

Use a test customer that has:
- at least **2 delivery addresses** in JDE (for Sno 4);
- an article that exists in **several UOMs** for the same shade, and one that exists in only one (Sno 14);
- an article code starting with **R** (Sno 5);
- **open invoices** with PO numbers on their sales orders, and some **paid** invoices (Sno 13);
- some **bulk orders**, ideally with an invoiced line (Sno 6).

For an Excel test sheet: click **Sample Excel** on the Bulk New Order screen and fill in rows in that layout.

Tip: open the browser developer console. It shows the JDE request/response log, which helps with the payload checks (Sno 5, Sno 13).

---

## Quick demo path (about 15 minutes)

1. **Theme** (Sno 11): hover over *Welcome! name* → **Theme** → pick a gradient theme, then switch back.
2. **ORDERS → Bulk**:
   - Status column in the list.
   - Click an order: status panel at the top, and the invoice date (Sno 6).
   - Type a shade in the **Shade** search (Sno 6).
3. **New Order**:
   - **Ship To** dropdown (Sno 4).
   - Article + Shade → UOM fills itself (Sno 14).
   - **Add Line**: only Shade/Qty clear (Sno 10).
   - R-article checkbox (Sno 5).
4. **Import Excel** with a few bad rows: red lines, **Fix**, **Yes** (Sno 2).
5. **Open**:
   - **PO No.** search.
   - **Select by PO No.**
   - **Pay** → table → Proceed.
   - Knock-off table after returning (Sno 13).

---

## Sno 2 — Excel upload, validation, fix and partial order

### What changed
- **Accepted files**: `.xlsx`, `.xls` and `.csv` from any source (MS Excel, WPS, LibreOffice, Google Sheets, web exports).
- **Format detection**: the format is read from the file content, not the extension. So an ".xls" that is really xlsx, an HTML table or tab-separated text is still read. CSV may be comma, semicolon or tab separated, in UTF-8, UTF-16 or ANSI.
- **New readers**:
  - `lib/bulk/spreadsheet_reader.dart`
  - `lib/bulk/xls_reader.dart` (Excel 97-2003)
- **Row cleanup**: blank rows are skipped, `100.0` is read as `100`, and Article/UOM/Shade are upper-cased.
- **Validation per line (unchanged chain)**:
  1. Required fields
  2. Duplicates
  3. Item present in JDE item master `F4101`
  4. **Price** from `ORCH554074_GetUnitPrice`; no price or 0 is an error
- **Import dialog**:
  - Title: *"X of N lines have errors. Proceed with the N-X valid lines?"*
  - A grid of **all** lines: error lines in **red**, valid lines with a green *Valid* tick and the JDE price.
  - An **Errors panel** under the grid lists each error line's reason.
  - **Fix** opens an editor for one line. **Save & validate** re-checks it against F4101 and ORCH554074, and the line turns green only if it passes.
  - **Yes** adds only the valid lines. **No** adds nothing.
- **Other fixes**:
  - SPE articles accepted (`SRP1 IN (IND, SPE)`).
  - Unique line numbers on import.
  - Duplicate-submit guard; a retry reuses the same JDE order number.
  - Buttons no longer stay stuck on a spinner.
  - Login after OTP waits properly and shows "Connection error! Please try again." on failure.
  - Expired session (JDE 444): the token is refreshed and the call retried.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | Left rail **ORDERS → Bulk** → **New Order** | New Bulk Order screen opens |
| 2 | Click **Import Excel** | File picker lets you choose `.xlsx`, `.xls` or `.csv` |
| 3 | Pick a sheet with good rows plus: one empty Qty, one duplicated item, one unknown shade, one item with no JDE price | Loading bar runs; then the import dialog opens |
| 4 | Read the dialog | Title *"X of N lines have errors. Proceed with the N-X valid lines?"*. Bad lines red in the grid. Errors panel lists e.g. *Missing Quantity*, *Duplicate item number*, *Item not found in JDE item master*, *Price not available in JDE* |
| 5 | Click **Fix** on the empty-Qty line → type a quantity → **Save & validate** | Editor closes, line turns green, title counts update |
| 6 | Click **Fix** on the unknown-shade line → enter a wrong shade again → **Save & validate** | Editor stays open and shows the new error |
| 7 | Click **Yes** | Only valid lines appear in the order grid; toast *"N of Y lines uploaded"* |
| 8 | Import again → click **No** | Nothing is added |
| 9 | Save the same sheet as **.xls** (Excel 97-2003), and again as **.csv**; also save one from **WPS**; import each | Same lines and same errors as the .xlsx |
| 10 | Import a row with an **SPE**-category article | Accepted if the item exists in F4101 |
| 11 | Fill a line, click **Submit Order → Submit** several times quickly | Only one order is created in JDE |

### Limits
- Password-protected `.xls` files cannot be read; the user sees a "could not read" message.
- On a submit retry, the PO attachment is uploaded again.

---

## Sno 4 — Multiple Ship-To

### What changed
- **Ship To** dropdown in the header of all 4 New Order screens (`lib/common/ship_to_selector.dart`).
- **Options**:
  - the Sold-To address (`ORCH550116`)
  - the delivery addresses from `ORCH550101K_GetDeliveryAddress`

  It defaults to the last choice, or to the Sold-To.
- **Bulk re-pricing**: changing the Ship-To re-prices every line in the order, and the line being typed, through `ORCH554074_GetUnitPrice` with the chosen `Ship_To`. Before this, pricing always used the Sold-To.
- **Submit**: `ShipTo` (all 4 order types) and pricing both use `UserController.shipToNumber`.
- The Submit confirmation shows the chosen Ship-To number, name and address.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | **ORDERS → Bulk → New Order** | **Ship To:** dropdown next to the title shows the current address |
| 2 | Add 2–3 lines | Unit Price column filled |
| 3 | Open **Ship To** and pick another address | Toast *"N lines re-priced for Ship-To X"*; Unit Price column refreshes. If JDE has no price at that ship-to, the toast lists those lines and their price is blank |
| 4 | Click **Submit Order** | Confirmation shows **Ship To** box with number, name and address |
| 5 | Submit, then check in JDE | Order's Ship-To (F4211 SHAN) = chosen address number |
| 6 | Customer with only one address | Dropdown shown but disabled |

### JDE configuration — to confirm with the JDE team
The responses can't answer this: submit only checks HTTP 200 (staging write), the price response doesn't echo the ship-to, and ORCH550101K returns no branch plant per address. Please confirm:
1. Every delivery address is in `F03012` for the order company and linked to the Sold-To.
2. Staging-to-sales-order processing keeps the `ShipTo` instead of the Sold-To default.
3. Whether other regions need a different branch plant or billing type. Today the order goes to the Sold-To's plant.

Also found, not changed: pricing sends the **logged-in user** as `Address_Number`, while submit sends the **selected customer** as `SoldTo`. When a salesperson orders for a customer, prices may therefore differ.

---

## Sno 14 — UOM picked automatically from Article + Shade

### What changed
- **Source**: `Api.fetchUomsForShade`, a live JDE `F4101` query: SEG1 = article, SEG3 = shade, SRP1 IND/SPE. The result is limited to the article's UOMs in the item catalog (`ORCH55_GetItemCatalogInfo`).
- **Sources not used**:
  - `fetchItemMaster`: it covers domestic items only (`SRP1=DOM`) and falls back to sample data.
  - The catalog alone: it has no shades.
- **Shade field**: usable as soon as Article is set. Shade lists cover all of the article's UOMs.
- **Bulk and DTM**:
  - **One UOM**: filled in and **read-only**.
  - **Several UOMs**: the UOM dropdown opens with **only** those.
  - **None**: *"UOM not found for article X and shade Y"*; the field stays editable.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | **ORDERS → Bulk → New Order** (or **DTM**) | — |
| 2 | Pick an **Article**, leave **UOM** empty | Shade field becomes usable |
| 3 | Pick a **Shade** that exists in one UOM only | UOM fills in and is greyed out (read-only); Ticket/Brand/Tex/Substrate fill; Bulk shows Unit Price |
| 4 | Pick a different shade | UOM is worked out again for that shade |
| 5 | Pick a shade that exists in two UOMs | Orange message lists the UOMs; UOM dropdown opens with only those; pick one and the Shade stays |
| 6 | Pick a shade with no catalog UOM | Red message *UOM not found…*; UOM editable |
| 7 | Clear the Shade | UOM becomes editable again |

Lab Dip and Sampling: a single UOM is still filled in automatically, but not locked.

---

## Sno 5 — Recycled "R" article: Direct delivery - TC required

### What changed
- **Rule (as given)**: an article code starting with **R** is recycled.
- **Checkbox**: Bulk New Order shows **"Direct delivery - TC required"** under Unit Price, **only** for R articles.
- **Ticked line**:
  - stored in DraftTable with billing type `Plant`, sent as **`BillingType: "D"`**; the same mapping Lab Dip/Sampling use
  - remark and `ColorRemark` get **"TC Required"**
- **Unticked line**: a normal order, using the existing Sold-To rule (`getBillingType`, F00092 BT/D).
- **Remark column**: in the New Order grid, and in **Order Details** (JDE `Description2`, as DTM already shows).

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | **ORDERS → Bulk → New Order**, pick an article starting with **R** | Checkbox *Direct delivery - TC required* appears under Unit Price |
| 2 | Pick a non-R article | Checkbox disappears |
| 3 | Back to the R article, tick the box, complete the line, **Add Line** | Grid **Remark** column shows *TC Required* |
| 4 | Add another R line **without** ticking | Remark empty (normal order) |
| 5 | Click the TC line in the grid | Form reloads with the box **ticked**; untick → **Update** → Remark clears |
| 6 | Submit with the browser console open | `ORCH55CreateStagingData` payload: TC line has `"BillingType":"D"` and `ColorRemark` containing `TC Required` |
| 7 | **Bulk** list → click the submitted order | **Remark** column in Order Details |

### To confirm with the JDE team
- Whether JDE copies `ColorRemark` into the line's `Description2`. If the Remark column in step 7 is blank, ask where it is stored.
- Whether `BillingType D` alone triggers direct delivery and the TC.
- Excel import has no TC column, so imported lines are always normal.

---

## Sno 13 — Payment section

### What changed
- **PO number**:
  - **PO No.** column in the Open and Paid tables (from `ORCH5542001.CustomerPO` via the invoice's sales order).
  - Separate **Invoice No.** and **PO No.** search fields on Open and Paid.
- **Select by PO No.**: a field in the payment section (right panel of Open) that selects every payable open invoice of a PO.
- **Pay confirmation**: shown as a **table**, with columns #, Invoice No., Invoice Date, PO No., Due Date, Status, Open Amount, Discount and Amount to Pay, and a **Total** row. Then **Proceed**.
- **Payment calls**: unchanged.
  1. `ORCH55_CreateInvoicePaymentEntry`, with a line per invoice
  2. `ORCH55_InvoicePaymentReqUpdate`
  3. the ICICI gateway
- **Knock-off per invoice**: after a payment, with nothing selected, the right panel shows **"Last payment P… · knock-off from JDE"**.
  - Columns: Invoice, PO, Paid, Knocked off, Open in JDE, JDE Receipt, Status.
  - Values come from JDE: `ORCH5503B11A` open amounts, `F550313Z` processing, and the `F03B14` receipt number and date.
- **SMS**: `ORCH55_SendSMSNotification_B2B` with the receipt number when the payment entry is created (invoice and advance payments), if the customer allows SMS.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | Left rail **Open** | Overdue / Due / Payment Processing tabs; tables have a **PO No.** column |
| 2 | Type part of an invoice number in **Invoice No.** | List filters by invoice |
| 3 | Clear it, type a PO in **PO No.** | List filters by PO; both fields together narrow further |
| 4 | Click **Paid** in the left rail | Same **Invoice No.** / **PO No.** search; table shows Receipt No./Date and PO No. |
| 5 | Back to **Open**. In the right panel, type a PO in **Select by PO No.** → press Enter (or **Select**) | Toast *"N invoices of PO X selected"*; they appear in the selection list. Unknown PO → red toast |
| 6 | Click **Pay** | Dialog with amount and a **table** of the selected invoices: #, Invoice No., Invoice Date, PO No., Due Date, Status (coloured), Open Amount, Discount, Amount to Pay, **Total** row |
| 7 | Click **Proceed** | Redirect to the payment gateway; customer's mobile gets the SMS |
| 8 | Come back to the app → **Open**, nothing selected | Right panel shows **Last payment P…** knock-off table |
| 9 | Click **Refresh** in that table (after JDE posts the receipt) | Status moves to *Knocked off* with the JDE receipt number and date |
| 10 | Click **Dismiss** | Knock-off table is cleared |

### Not done / to fix before production
- **Consolidated receipt email: stopped.** There is no email in the payment path and no receipt-email orchestrator in the API doc. Needed: a JDE orchestrator that emails one receipt per receipt or batch number.
- **SMS**:
  - It is sent before the gateway result is known, because the browser leaves the app.
  - Its text is the order-entry template, set in JDE; please confirm or supply a payment template.
- **Payment calls return no knock-off data** (HTTP 200 only), so knock-off is read back from ORCH5503B11A and F03B14.
- **Knock-off table**: kept in the browser, so it only shows on the device the payment was made from.
- **Found, not changed (payment amounts)**:
  - `invoice_review_dialog.dart` sends a fixed `"txn-amount": "99.00"` to the UAT gateway.
  - `advance_payment_dialog.dart` sends the selected-invoices total instead of the advance amount.

---

## Sno 10 — Keep Article/UOM while punching orders

### What changed (Bulk)
- **After Add Line**: only **Shade and Quantity** are cleared. The **Shade dropdown opens** with the cursor in it.
- **Kept until the Article changes**:
  - Article, UOM, Ticket, Brand, Tex, Substrate
  - Style No., the TC tick, merchandiser, buyer, light sources, PO and requested date
- **UOM lock**: a UOM that was locked from the shade (Sno 14) stays locked and is worked out again for the next shade.
- **Changing Article**:
  - UOM, Ticket, Brand, Tex, Substrate and price reset.
  - The UOM lookup runs again for the shade already entered. If the new article lacks that shade, it is cleared with a message.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | **ORDERS → Bulk → New Order**, fill a full line, **Add Line** | Line added to grid |
| 2 | Look at the form | Only **Shade** and **Quantity** are empty; Article, UOM, Ticket, Brand, Tex, Substrate, Style No. still filled; **Shade list is open** with the cursor in it |
| 3 | Type the next shade + quantity → **Add Line** | Second line added with the same Article/UOM |
| 4 | Enter a shade, then change **Article** | UOM/Ticket/Brand/Tex/Substrate reset; UOM looked up again for the shade (filled, choice offered, or *"Shade X is not available for article Y"*) |

---

## Sno 6 — Order status, invoice date, search, scrollbars

### What changed
- **Order list (Bulk)**: new **Status** column; drafts show *Draft*.
- **Status panel**: Bulk **Order Details** has a fixed panel at the top (`lib/common/order_status_panel.dart`).
  - Order no., JDE no., date, PO, merchandiser and amount.
  - Chips for Status, Hold, Ordered, Shipped, Back-ordered, Cancelled and line counts per status.
  - All from the already-fetched `ORCH5542001` / `ORCH5542002`.
- **Detail table realigned**: `# · Article · UOM · Shade · Status · Qty · Shipped · Prices · Invoice · Remark · Ticket · Brand · Tex · Substrate`.
- **Invoice date** next to the invoice number, e.g. `12345 RI (05/10/2026)`, from `ORCH5542002` "Date Invoiced". `F03B14.DMTJ` is the receipt (payment) date, so it wasn't used.
- **Shade and Buyer search** in all 4 order lists: shade from the line's Item, buyer from End Use plus the F00092 buyer names.
- **Scrollbars always visible**: set in the theme and on every `DataTable2`.

### Load cost of Shade/Buyer search
- **First search**: one `ORCH5542002` call **per order in the date range** (5 in parallel), plus one F00092 call. For example, 200 orders = 200 calls.
- **After that**: results are cached and shared by Bulk/DTM/Lab Dip/Sampling, so there are no new calls until **Refresh** or a customer change. Narrow the date range first to reduce the first load.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | **ORDERS → Bulk** | Order list has a **Status** column |
| 2 | Click an order | Top of the right side: **status panel** with order data and coloured chips; it never scrolls |
| 3 | Look at the detail table | **Status** right after **Shade**; Ticket/Brand/Tex/Substrate at the far right |
| 4 | Find an invoiced line | Invoice column shows `number type (dd/MM/yyyy)` |
| 5 | Below the order list, type a shade in **Shade** | Top loading bar runs the first time; list shows only orders containing that shade |
| 6 | Type a buyer name in **Buyer** | List filters by buyer; repeated searches are instant |
| 7 | Click the reset (↺) button | Shade and Buyer fields clear |
| 8 | Look at any table/list, without hovering | Scrollbars are always visible |

### Limits
- `order_summary_view.dart` has no status data (its F47011 source has no status field). Only its scrollbars changed.
- The status panel is on Bulk only; Lab Dip details have no Invoice column.

---

## Sno 11 — UI colour options (theme switcher)

### What changed
- **Themes**: 12 themes in `lib/app/theme_variants.dart`, each defining primary, accent, surface, success, warning and error colours, plus a fabric pattern.
  - **Thread Spectrum** (default)
  - Vardhman Red (the original look)
  - Indigo Navy, Ocean Teal, Royal Purple, Charcoal Gold, Forest Green
  - Sunset Blaze, Ocean Aurora, Royal Twilight, Silk Weave, Midnight Stars
  - Gradients apply to primary buttons, the left nav rail and the top bar.
- **Background photos**: each theme has its own thread or fabric photo behind the nav rail, the top bar, the theme preview and the segment dialog.
  - The photos are in `assets/themes/` (free Pexels photos); Thread Spectrum uses `assets/home_background.jpg`.
  - Over a photo the dark gradient is about 60% opaque, so the photo shows through.
- **Table headers and the filter reset button** follow the theme too (`lib/common/table_header.dart`).
- **Switcher**: a dialog of preview tiles (`lib/app/theme_switcher.dart`).
- **Saved choice**: kept in SharedPreferences (`themeVariant`) per device and browser.
- **Whole app follows the theme**: `VardhmanColors` now reads from the selected theme. `const` was removed from about 60 expressions that used it; no other code changed.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | Click the account menu next to **Welcome! …** (top right) | Profile menu: *(Order Summary)*, **Status Report**, **Theme**, **Logout** |
| 2 | Click **Theme** | Dialog with **9 preview tiles**; current one ticked; gradient tiles show a gradient icon |
| 3 | Click **Indigo Navy** | Whole app recolours immediately: nav rail, top bar, buttons, headers, tables, loader |
| 4 | Click **Sunset Blaze** | Buttons, nav rail and top bar show gradients |
| 5 | Reload the browser page | Chosen theme is still applied |
| 6 | Pick **Vardhman Red** | Original look returns |

---

## Sno 7 — Segment selection after login — segment-wise done, customer-wise pending

SOW text: *"prevent cross-segmental order placement, with proper customer-wise and segment-wise mapping. After login a Segment selection popup, and order placement as per the selected segment only."*

### What changed (segment-wise)
- **Popup after login**: a segment dialog opens right after login (`lib/segment/segment_dialog.dart`). It cannot be closed until a segment is picked:
  - Industry (IND)
  - Domestic (DOM)
  - Speciality (SPE)
  - Industry & Speciality
  - All Segments
- **Ordering limited to the segment**: the pick filters articles by JDE category (F4101.SRP1) in:
  - the article dropdowns of all order screens;
  - the shade and UOM lookups;
  - the Bulk Excel upload, which rejects rows of another segment.
- **Cross-segment lock**: while the customer has unsubmitted draft lines, other segments cannot be picked, and an alert lists the orders in progress. So one order never mixes articles of two segments.
- **Kept per session**: the pick survives a page refresh (sessionStorage) and is cleared on logout. The top bar shows the segment and reopens the dialog.
- **Logs**: `[SEGMENT]` in the browser console.

### Still pending (customer-wise)
Every customer can pick any of the five segments, because no JDE source gives a customer's segments:

| Source checked | What the app reads | Segment? |
|---|---|---|
| `ORCH5541001_GetUserData` | User, name, role, contact flags, company, `UserCategory`, discount | **No.** `UserCategory` is a single, unused value, not documented as a segment |
| `F00092` Supplemental Data | LDF, SAF, BY, MR, BT, QTX collections | **No** segment collection |
| `F0101` Address Book | `AN8`, `ALPH` | **No** |
| `F03012` Customer Master | `AN8`, `CO`, `CUSTS`, `AC02` (salesperson) | **No** |
| `ORCH55_GetItemCatalogInfo` | item `Category`, `SubSegment` | Item side only, not the customer's segments |

**Needed from the JDE team**:
1. The customer→segment field: an F03012/F0101 category code, or confirmation that `UserCategory` is the segment, plus its values. Alternatively, an F00092 collection listing the segments per Sold-To.
2. Which item field a segment maps to: catalog `Category`, `SubSegment`, or another.

---

## Extra — Loading indicator for JDE calls

### What changed
- **Top bar**: a thin animated bar runs along the top of the app whenever **any** JDE call is running (`lib/api/api_activity.dart`).
- **Table overlay**: a frosted panel with a branded spinner and "Fetching from JDE…" covers each table while it loads (`lib/common/vardhman_loader.dart`). Covered tables:
  - order lists and order details (all 4 types)
  - Open and Paid invoices
  - Order Summary
- Calls are not faster; the loader only makes the wait visible.

### Click-through test

| # | Where / what to click | Expected result |
|---|---|---|
| 1 | Log in | Top bar animates while orders and invoices load |
| 2 | **ORDERS → Bulk** → refresh (↺ icon) | Order list covered by the spinner panel until JDE answers |
| 3 | Click an order | Order Details shows the spinner while lines load |
| 4 | **Open** / **Paid** right after login or customer switch | "Fetching invoices from JDE…" panel |

---

## PY fixes and improvements (branch `fix/py-bugs`)

Changes made after the PY deployment, newest first. Each row names the problem, the fix and how to check it.

### Order lists

| Problem | Fix | Where | How to check |
|---|---|---|---|
| A new order did not appear until ⟳ was pressed or the user logged in again | After a successful submit the order lists reload. They reload again every 10 s, up to 4 reloads, until JDE returns the order (matched on its B2B number, e.g. `B2BB30041`). Covers Bulk, DTM, Sampling, Labdip and rematch orders. | `OrdersController.refreshUntilListed`; called from `order_review_controller.dart`, `labdip_controller.dart`, `sampling_controller.dart` | Place an order and stay on the list: it appears without ⟳. Console: `[ORDERS] B2BB… listed after reload N` |
| Order 26111668 was in the `GetOrderStatus` response but on no list, not even under Today | JDE returned it with `OrTy` `SO`; the lists only took `SW`. Bulk and DTM now take `SW` and `SO`, split on the DTM flag. | `bulk_controller.dart`, `dtm_controller.dart` `isListOrder` | 26111668 / B2BB30041 shows under Bulk |
| A new order with an empty field (`null`) was skipped without a trace | Order rows are read leniently; a row is skipped only for an unusable order number or date, and then logged | `Api.fetchOrders` | Console `[ORDERS] fetchOrders skipped …` if it happens |
| Order Details sometimes stayed empty after clicking an order | Three causes fixed. (1) One detail line with an empty (`null`) field threw and dropped all the order's lines; lines are now read leniently. (2) Every list reload, including the ones after placing an order, closed the open order, and a reload during loading threw the loaded lines away; the open order now stays open while the list holds it, matched by order number, type and company. (3) Bulk and Sampling hid lines without a JDE work order, so a just-placed order showed none; they now show the lines until work orders exist, and Bulk compares the B2B number trimmed. | `Api.fetchOrderDetails`; `order_list_filters.dart` `isSameOrder`; `primaryOrderDetailLines` in `bulk_controller.dart`, `sampling_controller.dart`; the four `*_order_details_view.dart` | Click orders in each list, press ⟳ with one open: the pane stays filled. Console: `[ORDERS] fetchOrderDetails <order> <type>: X of Y lines`. An order JDE returns no lines for says **"No lines from JDE for this order yet"** |
| With the portal left open past midnight, the To date stayed on the opening day and hid the new day's orders | A To date left on today follows the clock on every reload; a picked date is kept | `order_list_filters.dart` `_keepToDateOnToday` | Covered by `test/welcome_and_to_date_test.dart` |
| Bulk Order Details had status and quantity chips that did not filter anything | Status / Ordered / Shipped / Cancelled chips removed. The **Lines** chips (All N, In Progress N, Dispatched N, …) filter the line table, one at a time, keyboard accessible, back to All when another order opens. | `lib/common/order_status_panel.dart`, `bulk_controller.dart` | Open a Bulk order and click the line chips |

How the lists load and when the API is called is described in `docs/ARCHITECTURE_AND_API.md` §3.5.

### Header, themes and look

| Change | Where | How to check |
|---|---|---|
| Header greets **Welcome! RISHIK (105911)**: login ID with the customer number in brackets, instead of the JDE user name alone | `home_scaffold.dart` `welcomeText` | Top right after login |
| Each theme has its own background photo; the bar over it is lighter so the photo shows | `assets/themes/`, `theme_variants.dart` `ThemeBackdrop` | Account menu → Theme, switch themes |
| Thread Spectrum is the default theme | `ThemeVariants.defaultVariant` | New browser / cleared site data |
| Table headers and the filter reset button follow the theme (they were grey) | `lib/common/table_header.dart`, `order_filters_panel.dart` | Any list, after switching themes |

### Payment and SMS

| Change | Where |
|---|---|
| Payment status request sends `ReceiptNumber` as the string `txn-id=<receipt>\|` | `api.dart`, payment status call |
| Order SMS stays on the `ORCH55_SendSMSNotification_B2B` orchestration. A direct Airtel IQ call, as in the mobile app, was tried and reverted: Airtel blocks it from the browser (CORS) and it exposes the credentials. The orchestration team is to make the orchestration send the SMS. | `Api.sendOrderEntrySMS` |

### Segment (Sno 7)

| Change | Where |
|---|---|
| Segment popup after login, ordering limited to the picked segment | `lib/segment/` |
| DOM articles included in All Segments | `segment_controller.dart` |
| Segment locked while the customer has unsubmitted lines | `segment_dialog.dart` |

### Browser console errors

| Error | Fix | Where |
|---|---|---|
| "Refused to set unsafe header" on every request | `Connection` and `Accept-Encoding` removed from the request headers; browsers set these themselves | `api.dart` `_dio` |
| Crash (red error and a TypeError) when the window was resized with a dropdown open | An open dropdown popup closes when the window size changes | `lib/common/close_popup_on_resize.dart` |

### Still open
1. **JDE team**: why was order 26111668 created as `SO` and not `SW`? Check that its Order Details shows its lines.
2. **Orchestration team**: SMS on order placement through `ORCH55_SendSMSNotification_B2B`.
3. **Customer-to-segment mapping** (Sno 7): needed from Vardhman to limit each customer to their segments.

---

## Files changed

**New**
- `lib/bulk/spreadsheet_reader.dart`: .xlsx/.xls/.csv reader with content sniffing
- `lib/bulk/xls_reader.dart`: Excel 97-2003 reader
- `lib/bulk/excel_import_dialog.dart`: import grid, errors panel, Fix, Yes/No
- `lib/common/ship_to_selector.dart`: Ship-To dropdown
- `lib/common/order_status_panel.dart`: order status panel
- `lib/common/vardhman_loader.dart`: spinner, table overlay, top activity bar
- `lib/api/api_activity.dart`: running-call counter
- `lib/open/payment_knock_off_view.dart`: Select by PO field, knock-off table
- `lib/app/theme_variants.dart`: 12 themes with patterns and background photos, `ThemeController`
- `lib/app/theme_switcher.dart`: theme dialog with preview tiles
- `docs/SOW_B2B_CHANGES.md`: this file

**Modified**
- **API and data**:
  - `lib/api/api.dart`: 444 retry, IND+SPE, `fetchUomsForShade`, `fetchOrders(fromDate)`, activity counter, TC `BillingType`
  - `lib/bulk/excel_line.dart`
- **Order entry**:
  - `lib/bulk/bulk_entry_controller.dart`: import, Ship-To re-pricing, UOM lock, TC flag, keep fields after Add Line, article reset
  - `lib/dtm/dtm_entry_controller.dart`, `lib/labdip/labdip_entry_controller.dart`, `lib/sampling/sampling_entry_controller.dart`: submit guard, UOM auto-select, Shade focus
  - `lib/*/create_*_order_view.dart` (4): Ship-To, Shade/UOM fields, TC checkbox and Remark column (Bulk), Ship-To on the Submit dialog
- **Order lists and details**:
  - `lib/bulk/bulk_controller.dart`, `lib/dtm/dtm_controller.dart`, `lib/labdip/labdip_controller.dart`, `lib/sampling/sampling_controller.dart`: Shade/Buyer search, loading flags, line status counts
  - `lib/orders/orders_controller.dart`: detail cache, `findOrdersByLine`, loading flag
  - `lib/*/*_orders_view.dart` (4): Shade/Buyer search, loader, Status column (Bulk)
  - `lib/*/*_order_details_view.dart` (4): column order, invoice date, loader, status panel and Remark (Bulk)
- **Ship-To and review**:
  - `lib/orders/order_review_controller.dart`: shared `ShipTo`, `shipToDisplay`
  - `lib/user/user_controller.dart`: `shipToNumber`
- **Invoices and payment**:
  - `lib/invoices/invoices_controller.dart`: PO map and search, select by PO, payment record, knock-off, loading flag
  - `lib/open/open_view.dart`, `lib/paid/paid_view.dart`: loader
  - `lib/open/open_invoices_view.dart`, `lib/paid/paid_invoices_view.dart`: Invoice No. + PO No. search
  - `lib/open/open_invoices_list.dart`, `lib/paid/paid_invoices_list.dart`: PO No. column
  - `lib/open/invoice_review_view.dart`: Select by PO, knock-off panel
  - `lib/open/invoice_review_dialog.dart`: payment table, payment record, SMS
  - `lib/open/advance_payment_dialog.dart`: SMS
- **Home and summary**:
  - `lib/home/order_summary_controller.dart`, `lib/home/order_summary_view.dart`: loader, scrollbars
  - `lib/home/home_scaffold.dart`: Theme button, gradient top bar
  - `lib/home/nav_rail.dart`: gradient nav rail
- **Shared widgets**:
  - `lib/common/catalog_search_field.dart`: `dropdownKey`
  - `lib/common/primary_button.dart`, `lib/common/secondary_button.dart`: no stuck spinner, double-click guard, gradient fill
- **App setup and theming**:
  - `lib/login/login_controller.dart`: awaited and guarded login
  - `lib/app/app.dart`, `lib/main.dart`: theme from `ThemeController`, activity bar, scrollbars
  - `lib/constants.dart`: `VardhmanColors` follows the selected theme
  - `const` removed where it wrapped `VardhmanColors` in about 60 places across views and dialogs
- `pubspec.yaml`: `archive` and `xml` added as direct dependencies, at the versions already locked (3.6.1 / 6.6.1)

---

## Open points for the team
1. **Hardcoded OTP**: `generateAndSendOtp` in `lib/api/api.dart` (line ~237) uses a fixed OTP `'1234'`. It was added outside this work. It is a security risk and must be reverted before release.
2. **Sample data**: `lib/sample_data.dart` is still imported by `api.dart` and used by the uncalled `fetchItemMaster`. Remove it to meet the no-sample-data rule.
3. **Payment amounts** (Sno 13): fixed `txn-amount "99.00"` in the invoice payment, and the wrong amount in advance payment. Fix before production.
4. **JDE confirmations needed**:
   - Ship-To processing (Sno 4)
   - `BillingType D` and remark for TC lines (Sno 5)
   - SMS template wording (Sno 13)
   - receipt-email orchestrator (Sno 13)
   - segment source (Sno 7)
5. **Not tested end to end**: run the click-through tables above on the test environment.
