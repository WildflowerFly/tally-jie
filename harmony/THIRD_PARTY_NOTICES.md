# Third-party assets

## Michroma account-card typeface

- Designer: Vernon Adams. Source: https://github.com/google/fonts/tree/main/ofl/michroma
- License: SIL Open Font License 1.1; bundled at `entry/src/main/resources/rawfile/michroma-OFL.txt`.
- Original, unmodified font: `entry/src/main/resources/rawfile/Michroma-Regular.ttf` (64,344 bytes).
- Used locally for the wide, low-profile account-card amounts and English labels; no runtime download.

## Account symbols

### Payment-provider marks from iconfont

- Collection: [第三方分享/支付](https://www.iconfont.cn/collections/detail?cid=17055&type=sms), collection ID `17055`.
- Contributor shown by iconfont: [不吃饅頭吃饅頭](https://www.iconfont.cn/user/detail?uid=48442), user ID `48442`.
- Retrieved from `https://www.iconfont.cn/api/collection/detail.json?id=17055` on 2026-11-18, at the user's request. The WeChat Pay path is identical to the SVG supplied by the user.
- Original path geometry, viewBox and per-path colors are retained. Web-only classes/styles and editor metadata are omitted. Assets are bundled locally, with no runtime download.
- The collection does not declare a copyright/license (`copyright` and `license` are both `null` in its metadata). These marks are **not** represented as app-authored or covered by the project's code license; brand/trademark rights remain with their respective owners. Check the contributor's/site's terms and any necessary brand permissions before redistribution.
- Used solely to identify the account provider selected by the user; no affiliation or endorsement is implied.

| Resource | Collection icon | Icon ID |
| --- | --- | --- |
| `account_wechat.svg` | 微信支付 | `9306311` |
| `account_alipay.svg` | 支付宝 | `9306312` |
| `account_unionpay.svg` | 银联 | `9306315` |
| `account_quickpass.svg` | 云闪付 | `9306316` |

### Bank marks from iconfont

- Collection: [银行LOGO合集](https://www.iconfont.cn/collections/detail?cid=23316) by 小白大志. The bundled SVGs omit the white rounded-square backing path. The mark geometry, viewBox and brand colors are retained on deposit cards. Record-entry chips tint the same marks to match their selection state. No runtime download.
- No explicit license is listed by the collection. Bank marks identify accounts, not an affiliation. Confirm redistribution permissions before publishing.

| Resource | Bank | Icon ID |
| --- | --- | --- |
| `account_icbc.svg` | 中国工商银行 | `15132946` |
| `account_abc.svg` | 中国农业银行 | `15133167` |
| `account_boc.svg` | 中国银行 | `15133316` |
| `account_ccb.svg` | 中国建设银行 | `15133351` |
| `account_bocom.svg` | 交通银行 | `15134408` |
| `account_psbc.svg` | 中国邮政储蓄银行 | `15123586` |
| `account_cmb.svg` | 招商银行 | `15135205` |
| `account_citic.svg` | 中信银行 | `15134462` |
| `account_pab.svg` | 平安银行 | `15148804` |

## Lucide record-page icons

- Project: [Lucide](https://lucide.dev/)
- Source: https://github.com/lucide-icons/lucide/tree/0.468.0/icons
- Version: `0.468.0`
- License: ISC; the original notice is included in `entry/src/main/resources/rawfile/lucide-license.txt` and packaged with the app.
- Usage: `entry/src/main/resources/base/media/record_*.svg`. Original SVG geometry, 24 × 24 viewBox, round caps/joins and 2-unit stroke are retained; `currentColor` is replaced with `#666666` for native SVG rendering. Selected-state tint uses an alpha-preserving image color filter, not SVG fill replacement.
- These assets are bundled locally; there is no runtime network or icon-library dependency.

| Resource suffix (`record_…`) | Lucide icon |
| --- | --- |
| food | utensils |
| travel | bus |
| home | house |
| water | droplet |
| snack | cookie |
| shopping | shopping-bag |
| daily | package |
| phone | smartphone |
| entertainment | gamepad-2 |
| study | book-open |
| health | heart-pulse |
| trip | plane |
| pet | paw-print |
| gift | gift |
| clothing | shirt |
| beauty | sparkles |
| sport | dumbbell |
| digital | laptop |
| social | users |
| salary | briefcase-business |
| bonus | award |
| parttime | laptop-minimal |
| investment | chart-no-axes-combined |
| interest | percent |
| dividend | chart-pie |
| reimburse | receipt-text |
| refund | rotate-ccw |
| receive | hand-coins |
| cashgift | hand-heart |
| category | circle-ellipsis |
| account | wallet-cards |
