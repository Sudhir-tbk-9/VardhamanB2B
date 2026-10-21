# Responsive layout

How the portal adapts from a phone (360 px wide) to a desktop. Desktop layouts
are unchanged; smaller windows rearrange instead of squeezing.

## Breakpoints (`lib/common/breakpoints.dart`)

| Constant | Width | Measured on | Below it |
|---|---|---|---|
| `Breakpoints.compact` | 600 | Window | Nav rail moves into a drawer, dialogs fill the screen, login page scrolls as one column |
| `Breakpoints.split` | 840 | Tab body | List and details show one at a time |
| `Breakpoints.formRow` | 720 | The row itself | Form fields stack (or wrap) instead of sitting side by side |

`context.isCompact` tells whether the window is below `compact`.

## Building blocks (`lib/common/`)

| Widget | Use it for | Narrow behaviour |
|---|---|---|
| `MasterDetailLayout` | A list next to its details (every home tab) | One pane at a time. `showDetail` picks it, the details get a back bar calling `onBack`. Side by side, the list is at least `masterMinWidth` (360) wide. Pane state survives resizing across the breakpoint. |
| `AdaptiveDialog` | Any dialog, in place of `Dialog` | Fills the screen with square corners. Same defaults as `Dialog` otherwise. |
| `AdaptiveRow` | A `Row` of form fields, filters or buttons | Takes the Row's children unchanged. `NarrowLayout.column` stacks them full width; `NarrowLayout.wrap` wraps flexible children at `minChildWidth` and keeps buttons at their size. `Spacer`s and width-only `SizedBox` gaps become `spacing`. |
| `MinWidthScroll` | Tables whose columns are shares of the width | Keeps `minWidth` and scrolls sideways. Wrap the header and the rows together. |

## Where they are used

- **Shell** (`home_scaffold.dart`): drawer + menu button on a phone; the
  account menu opens on tap as well as hover, and its buttons wrap.
- **Orders tabs** (Sampling, Labdip, DTM, Bulk): `MasterDetailLayout`. Picking
  an order opens its details; back clears `rxSelectedOrderHeaderLine`, so the
  same order can be picked again.
- **Open tab**: `MasterDetailLayout` with a `masterBar` button
  ("Review & Pay (n)"), because invoices are multi-select. Filter bar wraps.
  Invoice tables use `MinWidthScroll` (`OpenInvoicesList.minWidth`). The tab
  bar scrolls on a phone.
- **Paid tab**: filter bar wraps, table uses `MinWidthScroll`.
- **Create order dialogs**: the form panel scrolls and is capped at half the
  height, so the lines table keeps room; field groups stack and the action
  buttons wrap. Sampling and Labdip move their buttons below the last field
  group when narrow, so they come after Shade.
- **Login**: fields and buttons wrap; on a phone the header, card and footer
  scroll as one column over the video.
- **Order summary**: the two date fields wrap.

## Tests

- `test/responsive_widgets_test.dart`: the building blocks at phone, tablet
  and desktop widths.
- `test/login_view_layout_test.dart`: every login step at 360 to 1920 wide.
  A layout overflow fails a widget test by itself. Tests draw text in the Ahem
  font (every glyph a full square, about 1.8x wider than real text), so a pass
  at 360 leaves room on real 320-wide phones.
