# siena.codes

A Y2K-style web portal for the projects that live on siena.codes subdomains. Plain HTML, CSS, and JS in `site/`, deployed to GitHub Pages by `.github/workflows/pages.yml` on every push to `main`.

## Shared look

The sky, bevels, wordmark, tabs, ticker, LCDs and blinkie come from [y2k-ui](https://github.com/sienaguerrero/y2k-ui), vendored as `site/y2k.css` and `site/y2k.js`. `site/style.css` holds only this site's own layout: the three columns, the directory list, the 88x31 badges, the cursor picker and the lessons page. To pick up a newer library, run the sync from a checkout that sits next to this one (or pass its path), then commit the two files and `y2k-ui.lock`, which records the library commit:

```bash
script/sync-y2k
```

## Adding a site

Add an entry to `SITES` in `site/portal.js` and a line to the What's New ticker in `site/index.html`. Channels, counts, search, and the webring all read from `SITES`.

## Run locally

```bash
python3 -m http.server 4220 --directory site
```

## Guestbook server

`server/` is a small Roda app that takes guestbook entries a visitor chooses to send. It runs at `guestbook.siena.codes` on the shared droplet, not on Pages. It has one write route, `POST /entries`, and no route that reads entries back, so nothing a visitor writes is ever shown to another visitor. `server/deploy/README.md` covers setup, limits and how to read entries.

```bash
BUNDLE_GEMFILE=server/Gemfile bundle exec ruby script/test_server.rb
```

```bash
cd server && SITE_URL=http://localhost:4220 bundle exec puma --bind tcp://127.0.0.1:9297
```

## Going live at the apex

1. Push to `main`, then turn on Pages with Actions as the source:

```bash
gh api -X POST repos/sienaguerrero/siena-codes/pages -f build_type=workflow
```

2. Attach the domain before adding DNS:

```bash
gh api -X PUT repos/sienaguerrero/siena-codes/pages -f cname=siena.codes
```

3. At Porkbun, add four `A` records on the bare domain (`185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`), four `AAAA` records (`2606:50c0:8000::153` through `2606:50c0:8003::153`), and a `www` CNAME to `sienaguerrero.github.io`. Keep the Fastmail MX, SPF, and DKIM records as they are.

4. Once `dig +short siena.codes` shows the GitHub addresses and the deploy is green, check the cert. If it is still null after a few minutes, clear and re-set the cname, then enforce HTTPS once it reads `approved`:

```bash
gh api repos/sienaguerrero/siena-codes/pages --jq .https_certificate.state
```

```bash
gh api -X PUT repos/sienaguerrero/siena-codes/pages -F cname= && gh api -X PUT repos/sienaguerrero/siena-codes/pages -f cname=siena.codes
```

```bash
gh api -X PUT repos/sienaguerrero/siena-codes/pages -F https_enforced=true
```
