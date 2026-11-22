# Deploying PD to the site root on the client's Linux server

These steps deploy the production (PD) web build to `https://b2b.amefird.in/`
so it runs the same way PY runs at `/vytldev/`:
- path URLs and F5 work
- the user comes back from the payment gateway (or any external link) still
  logged in, on the tab they left from
- a new deploy is picked up without stale icons

Same server and placeholders as [DEPLOY_PY_LINUX.md](DEPLOY_PY_LINUX.md):
`<user>`, `<server-ip>`, `<web-root>` (often `/var/www/html`), `<owner>`
(often `www-data`), `<date>`.

**The rule for this deploy: the site root also holds other folders.**
- `vytldev/` (PY)
- `vytlold/` (the old app; the login video `vytlold/assets/img/B2B.mp4` is
  loaded by PD)
- maybe others

Never empty the web root. Only the PD app's own files are replaced.

## 0. Before you start

- **The PD zip is built and checked locally:**
  - zip: `build\b2b_pd_<date>.zip`, from `scripts\build_web_pd.ps1` on branch
    `deploy/prod-sync`
  - `index.html` has `<base href="/">`
  - the zip contains `main.dart.js`, `sqlite3.wasm` and `drift_worker.js`
- **Section 1 of [PD_ENVIRONMENT_CHECKLIST.md](PD_ENVIRONMENT_CHECKLIST.md) is
  in the build:** JDE `erp`, real OTP, ipay2corp gateway, `WT-1573`.
- **ICICI allows `https://b2b.amefird.in` as the return URL for `WT-1573`.**
- **Agree a time with the client.** Users at `/` are cut over at once.

## 1. Connect and look first (read-only)

```powershell
ssh <user>@<server-ip>
```

Find out how PY is served today. PD must get the **same rules at `/`**:

```bash
systemctl status apache2 nginx 2>/dev/null | grep -E "Loaded|Active"
sudo grep -rn "vytldev\|DocumentRoot\|AllowOverride\|Header set Cache-Control\|application/wasm\|Rewrite" \
  /etc/apache2/ 2>/dev/null
cat <web-root>/vytldev/.htaccess
ls -la <web-root>
grep -o '<base href="[^"]*">' <web-root>/index.html <web-root>/vytldev/index.html
cat <web-root>/.htaccess 2>/dev/null
```

Write down:
- every rule PY has: the SPA fallback, POST to the app, `Cache-Control`, the
  `wasm` type
- where each rule lives: `.htaccess` or the vhost
- what is in the web root today

## 2. Upload

From Windows PowerShell:

```powershell
scp D:\Vardhamaan\vardhman_b2b\build\b2b_pd_<date>.zip <user>@<server-ip>:/tmp/
```

## 3. Back up the current PD, then put the new one in place

On the server:

```bash
cd <web-root>

# Back up the whole root except the big app folders that are not PD.
sudo mkdir -p /var/backups/b2b_pd_<date>
sudo tar --exclude=./vytldev --exclude=./vytlold -czf \
  /var/backups/b2b_pd_<date>/root.tgz -C <web-root> .

# Remove only the files a Flutter web build owns. vytldev/, vytlold/ and
# anything else are left alone.
sudo rm -rf assets canvaskit icons main.dart.js main.dart.wasm main.dart.mjs \
  flutter.js flutter_bootstrap.js flutter_service_worker.js index.html \
  manifest.json favicon.png version.json sqlite3.wasm drift_worker.js \
  .last_build_id

sudo unzip -oq /tmp/b2b_pd_<date>.zip -d <web-root>
sudo chown -R <owner>:<owner> <web-root>/assets <web-root>/canvaskit <web-root>/icons
sudo chown <owner>:<owner> <web-root>/*.* 2>/dev/null
grep -o '<base href="[^"]*">' index.html          # expect <base href="/">
ls vytldev/index.html vytlold/assets/img/B2B.mp4  # both still there
```

If the old PD at the root is not a Flutter build, delete only the files from
step 1's listing that belong to it. Ask if unsure.

## 4. Server rules at `/`: the same as PY's

Create or extend `<web-root>/.htaccess`. Keep any lines already there that are
not about the app.

```apache
# PD Flutter app at the site root, same rules as /vytldev/.
RewriteEngine On
RewriteBase /

# vytldev/ (PY) and vytlold/ (old app, login video) keep their own handling.
RewriteRule ^(vytldev|vytlold)(/|$) - [L]

# The payment gateway comes back with a POST to /: give it the app.
RewriteCond %{REQUEST_METHOD} POST
RewriteRule ^$ /index.html [L]

# Path URLs (/open, /bulk ...): any GET that is not a real file or folder
# gets the app, so F5 works.
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]

# A new deploy is picked up at once; no stale icon font or main.dart.js.
<IfModule mod_headers.c>
  Header set Cache-Control "no-cache"
</IfModule>

AddType application/wasm .wasm
```

**If PY's POST rule from step 1 is different and already works, use PY's form
for `/` instead of the POST rule above.**
- The other rules above should match PY's too.
- Check that POST to a static `index.html` is answered with 200, not 405
  (step 5). If it is 405, copy exactly what PY does for `POST /vytldev/`.

`mod_rewrite` and `mod_headers` must be enabled, with `AllowOverride All` for
`<web-root>`. If the Apache config has to change, back it up first, then:

```bash
sudo apachectl configtest && sudo systemctl reload apache2
```

Don't touch the port 8081 file-server site.

## 5. Test

```bash
curl -sI https://b2b.amefird.in/ | head -1                          # 200
curl -sI https://b2b.amefird.in/open | head -1                      # 200 (not 404)
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://b2b.amefird.in/   # 200 (not 405)
curl -sI https://b2b.amefird.in/main.dart.js | grep -i cache-control # no-cache
curl -sI https://b2b.amefird.in/sqlite3.wasm | grep -i content-type  # application/wasm
curl -sI https://b2b.amefird.in/vytldev/ | head -1                  # PY still 200
curl -sI https://b2b.amefird.in/vytlold/assets/img/B2B.mp4 | head -1 # 200
```

In the browser, the same smoke test as PY:

1. Open `https://b2b.amefird.in/` and press **Ctrl+F5**. Check the icons
   (New Order badge, Filters).
2. **Log in:** the OTP arrives by SMS (not `1234`).
3. **Refresh:** on `/open`, press **F5**. You stay logged in, on Open.
4. **One order of each type, and one invoice PDF download.**
5. **One small invoice payment:** you come back to `/` still logged in, on
   Open, and the payment status shows.
6. **One small advance payment:** the same.
7. **Cancel one payment on the gateway:** you come back logged in, and the
   status shows it was not paid.
8. **PY still works:** open `https://b2b.amefird.in/vytldev/`.

## 6. Roll back

```bash
cd <web-root>
sudo rm -rf assets canvaskit icons main.dart.* flutter*.js index.html \
  manifest.json favicon.png version.json sqlite3.wasm drift_worker.js
sudo tar -xzf /var/backups/b2b_pd_<date>/root.tgz -C <web-root>
```

If the `.htaccess` or Apache config was changed, restore its backup and run
`sudo apachectl configtest && sudo systemctl reload apache2`.

## 7. Clean up

```bash
rm /tmp/b2b_pd_<date>.zip
```

Keep `/var/backups/b2b_pd_<date>` until the next PD deploy.
