# Deploying PY to `/vytldev/` on the client's Linux server

These steps deploy the UAT (PY) web build to `https://b2b.amefird.in/vytldev/`
over the client VPN and SSH. Every change stays inside `/vytldev/`, so the
production app (PD) at the web root is never touched.

Placeholders: `<user>`, `<server-ip>`, `<web-root>` (often `/var/www/html`),
`<owner>` (often `www-data` or `nginx`), `<date>`.

## 0. Before you start

- The PY zip is built and checked locally: `build\vytldev_py_<date>.zip`
  (see [NAVIGATION.md](NAVIGATION.md) §6.1). It must contain `index.html`
  with `<base href="/vytldev/">`, `main.dart.js`, `sqlite3.wasm` and
  `drift_worker.js`.
- Agree a time with the client, and have their contact ready in case PD needs
  checking.

## 1. Connect

1. Connect the client VPN on your machine.
2. Open PowerShell and log in. Windows 10/11 already has `ssh` and `scp`:

```powershell
ssh <user>@<server-ip>
```

## 2. See how things run today (read-only, changes nothing)

Which OS and who you are:

```bash
cat /etc/os-release | head -3
whoami && sudo -v          # confirms you can use sudo
```

Which web server is running:

```bash
systemctl status nginx apache2 httpd 2>/dev/null | grep -E "Loaded|Active"
```

What is listening on which port (80/443 = web server, 8081 = invoice file proxy):

```bash
sudo ss -tlnp | grep -E ":80 |:443 |:8081 "
```

Where the sites are configured, where PD's web root is and whether
`/vytldev/` already has rules:

```bash
sudo grep -rn "vytldev\|root \|DocumentRoot\|server_name\|ServerName" \
  /etc/nginx/ /etc/apache2/ /etc/httpd/ 2>/dev/null
```

nginx only, the full active config in one place:

```bash
sudo nginx -T 2>/dev/null | less
```

Apache only, the loaded modules (look for `rewrite_module`):

```bash
sudo apachectl -M 2>/dev/null | grep rewrite
```

The current PD and PY folders, their owner and permissions:

```bash
ls -la <web-root>
ls -la <web-root>/vytldev
grep -o '<base href="[^"]*">' <web-root>/index.html <web-root>/vytldev/index.html
```

Other services on the box (for example the FTP/HTTPS invoice proxy on 8081),
so you know what not to touch:

```bash
systemctl list-units --type=service --state=running | grep -iE "python|proxy|ftp|node"
```

Free disk space (the build is about 55 MB unzipped):

```bash
df -h <web-root> /tmp
```

Write down three things before going on:

| What | Example |
|---|---|
| Web server | nginx / Apache |
| Web root (`<web-root>`) | `/var/www/html` |
| File owner (`<owner>`) | `www-data` / `nginx` / `apache` |

## 3. Upload the zip

From your **Windows PowerShell**, not the SSH window:

```powershell
scp D:\Vardhamaan\vardhman_b2b\build\vytldev_py_<date>.zip <user>@<server-ip>:/tmp/
```

## 4. Back up the old PY build and put the new one in place

On the server. Replace `<web-root>` and `<owner>` with what you found in step 2.

```bash
cd <web-root>
sudo cp -a vytldev vytldev_backup_$(date +%F)       # backup, for rollback
sudo rm -rf vytldev/*                               # empty ONLY the PY folder
sudo unzip -q /tmp/vytldev_py_<date>.zip -d vytldev
sudo chown -R <owner>:<owner> vytldev
ls vytldev                                          # expect index.html, main.dart.js, sqlite3.wasm, drift_worker.js ...
grep -o '<base href="[^"]*">' vytldev/index.html   # expect /vytldev/
```

If `unzip` is missing: `sudo apt install unzip` (Debian/Ubuntu) or
`sudo yum install unzip` (RHEL/CentOS).

If there is no `vytldev` folder yet, skip the backup and `rm` lines and run
`sudo mkdir vytldev` first.

## 5. Add the server rules (needed for URLs without `#`, and for payments)

The app uses path URLs (`/vytldev/open`), so a refresh asks the server for
`/vytldev/open`. The server must answer every path under `/vytldev/` that is
not a real file with `/vytldev/index.html`. The payment gateway also comes back
with a POST to `/vytldev/`, which must get the app too.

### nginx

Back up the site config first (use the file found in step 2):

```bash
sudo cp -a /etc/nginx/sites-available/<site> /etc/nginx/sites-available/<site>.bak_$(date +%F)
```

Inside the site's `server { }` block, add or adjust:

```nginx
location /vytldev/ {
    try_files $uri $uri/ /vytldev/index.html;   # refresh on /vytldev/open works
    error_page 405 =200 $uri;                   # gateway POST to /vytldev/ gets the app
}
```

Test the config, then reload. A reload does not drop PD's visitors:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Apache

Create `<web-root>/vytldev/.htaccess`:

```apache
RewriteEngine On
RewriteBase /vytldev/
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /vytldev/index.html [L]
```

This needs `mod_rewrite` enabled and `AllowOverride All` for that folder. If
either has to be changed in the Apache config, back up the file first, then:

```bash
sudo apachectl configtest && sudo systemctl reload apache2   # or httpd
```

**Only change the `/vytldev/` part of the config.** Leave PD's root
(`location /` or its Apache settings) alone, and don't touch the FTP/HTTPS
proxy service on port 8081.

## 6. Test

From the server, quick checks:

```bash
curl -sI https://b2b.amefird.in/vytldev/ | head -1                 # 200
curl -sI https://b2b.amefird.in/vytldev/open | head -1             # 200 (not 404)
curl -sI https://b2b.amefird.in/vytldev/main.dart.js | head -1     # 200
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://b2b.amefird.in/vytldev/   # 200 (not 405)
curl -sI https://b2b.amefird.in/ | head -1                         # PD still 200
```

In the browser:

1. Open `https://b2b.amefird.in/vytldev/` and press **Ctrl+F5**.
2. Log in, open the Open tab, and press **F5** on `/vytldev/open`. The app
   should reload, not show a 404.
3. Make a test payment and confirm you come back to `/vytldev/` with the
   result shown.
4. Open `https://b2b.amefird.in/` and confirm PD still works as before.

## 7. If something goes wrong, roll back

```bash
cd <web-root>
sudo rm -rf vytldev && sudo mv vytldev_backup_<date> vytldev
```

If you changed the nginx config, put the backup back and reload:

```bash
sudo cp -a /etc/nginx/sites-available/<site>.bak_<date> /etc/nginx/sites-available/<site>
sudo nginx -t && sudo systemctl reload nginx
```

## 8. Clean up

Once PY is confirmed working:

```bash
rm /tmp/vytldev_py_<date>.zip
```

Keep the latest `vytldev_backup_<date>` folder until the next deployment, then
remove the older ones.
