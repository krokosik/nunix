# Google OAuth information pages

Static pages for Krokosik Homelab. No scripts, fonts, or external assets are needed. `hosts/osiris/services/homepage.nix` serves these files with native Nginx on loopback and public Traefik routing, without authentication middleware.

Google Auth Platform branding values:

- App name: `Krokosik Homelab`
- Application home page: `https://homepage.krokosik.com/`
- Privacy policy: `https://homepage.krokosik.com/privacy.html`
- Terms of service: `https://homepage.krokosik.com/terms.html`
- Support/developer contact: `wikkra@gmail.com`
- Authorized domain: `krokosik.com`

Use the same app name on the consent screen and these pages. Verify domain ownership using Google Search Console with an account associated with the Cloud project.

The text assumes Google is used only for sign-in with `openid`, `email`, and `profile`. Before publishing, confirm the source's actual scopes, account linking, information shared with applications, logging, and backup retention match the policy. No Google source or scopes are configured by these files. Update the policy if broader Google API access is added.

Deploy the osiris configuration to publish updates. DNS for `homepage.krokosik.com` must point to the existing public ingress. These pages stay outside the authentication middleware so users and Google can read them before signing in.

Google requirements:

- https://support.google.com/cloud/answer/13807376
- https://support.google.com/cloud/answer/13464321
- https://developers.google.com/identity/protocols/oauth2/policies
