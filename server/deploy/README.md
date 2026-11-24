# Setting up the guestbook server

The guestbook server runs on `bondi`, the shared droplet, at `guestbook.siena.codes` on local port 9297. `.github/workflows/server.yml` deploys it on every push to `main` that touches `server/`, and skips the deploy while the `DEPLOY_HOST` repository variable is unset.

## Once, before the first deploy

1. Add an A record for `guestbook.siena.codes` at Porkbun, pointing at the droplet's IP.
2. On the droplet, as a user with sudo, check that nothing listens on 9297. If something does, pick a free port and change it in `guestbook.service` and `guestbook.caddy`.

   ```sh
   sudo ss -ltnp | grep 9297
   ```

3. Create the app folder and let `deploy` restart the service without a password.

   ```sh
   sudo install -d -o deploy -g deploy /srv/guestbook
   echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart guestbook' | sudo tee /etc/sudoers.d/guestbook
   sudo chmod 440 /etc/sudoers.d/guestbook
   sudo visudo -c
   ```

4. In this repository, set the `DEPLOY_KEY` secret and the `DEPLOY_HOST` and `DEPLOY_KNOWN_HOSTS` variables. They can be the same values the other projects on the droplet use.
5. Run the `server` workflow by hand. Its first run copies the files and fails at the restart, because the unit is not installed yet.
6. Install the unit and the Caddy site, then run the workflow again.

   ```sh
   sudo install -m 644 /srv/guestbook/server/deploy/guestbook.service /etc/systemd/system/guestbook.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now guestbook
   sudo install -m 644 /srv/guestbook/server/deploy/guestbook.caddy /etc/caddy/sites/guestbook.caddy
   sudo caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

## When the unit or the Caddy site changes

The deploy copies both files but can't install them, so its checks fail until the installed copies match. Run the `install` lines from step 6 again, then `daemon-reload` and a restart for the unit, or `reload caddy` for the site.

## Reading entries

Entries are stored in `/var/lib/guestbook/guestbook.sqlite3` and no route serves them. From a clone of this repository:

```sh
ADMIN_SUDO_USER=<your droplet login> ruby script/guestbook.rb list
ADMIN_SUDO_USER=<your droplet login> ruby script/guestbook.rb delete 3 4
```

## Limits

Each address can send 3 entries a day. The server takes 200 entries a day from everyone and holds 5,000 in all. Past either, it answers 429 until a day passes or entries are deleted. The numbers are `PER_DAY` in `server/address_cap.rb`, and `PER_DAY` and `MAX_ROWS` in `server/entries.rb`.
