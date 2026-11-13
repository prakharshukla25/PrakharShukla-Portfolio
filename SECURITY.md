# Security

This portfolio is a static site. It has no application server, login, database, or stored visitor submissions. The email action opens the visitor's own email application.

GitHub Actions checks pull requests with read-only repository access. Only the deployment job on `main` receives Pages and OIDC permissions. Actions are pinned to full commit SHAs; Dependabot proposes updates. The published artifact includes only the site files, build metadata, and checksums.

The optional container runs as user `101`, uses port `8080`, and supports a read-only filesystem with a temporary `/tmp` mount. Its NGINX headers apply to container hosting; GitHub Pages controls its own HTTP response headers.

Use GitHub's private vulnerability reporting feature when enabled in the repository. Keep credentials out of the repository. The resume and contact details are intentionally public portfolio content; review them before enabling public hosting.
