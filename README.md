# Prakhar Shukla · DevOps portfolio

A custom, responsive portfolio built with HTML, CSS, and JavaScript. The deployment-control-room design includes an interactive pipeline demonstration, project details, career history, and a downloadable resume. Content comes from the supplied resume. The pipeline animation is an illustration; it does not report live infrastructure status.

No Node installation or package manager is needed to edit, preview, validate, or package the site locally. GitHub Actions uses the runner's existing Node runtime for the JavaScript syntax check.

## Preview on Windows

Open PowerShell in this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preview.ps1
```

Visit **http://localhost:8080/**. Stop the server with `Ctrl+C`. To use another port, add `-Port 8081`. You can also open `index.html` directly in a browser.

## Publish on GitHub Pages

The target repository is [prakharshukla25/PrakharShukla-Portfolio](https://github.com/prakharshukla25/PrakharShukla-Portfolio). The site URL after deployment will be **https://prakharshukla25.github.io/PrakharShukla-Portfolio/**.

1. Open that GitHub repository. The initialization commands below assume its remote branch is empty; if it already contains commits, use an existing clone and copy this project's files into it before committing.
2. In the repository, go to **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**, and save if prompted.
3. Upload this project through Git, including the hidden `.github` directory:

```powershell
git init -b main
git add .
git commit -m "Build DevOps portfolio with automated Pages delivery"
git remote add origin https://github.com/prakharshukla25/PrakharShukla-Portfolio.git
git push -u origin main
```

4. Open the **Actions** tab and watch **Validate and deploy portfolio**. The deployment job links to **https://prakharshukla25.github.io/PrakharShukla-Portfolio/** when publishing succeeds.
5. In **Settings → Environments → github-pages**, restrict deployments to the `main` branch. For collaboration, protect `main` and require the **Validate and package** check before merging.

Every push to `main` validates, packages, tests the optional container, and deploys the exact Pages artifact. Pull requests run the same checks without publishing. **Actions → Validate and deploy portfolio → Run workflow** triggers a manual deployment from `main`. A deployment needs the repository's Pages source set to GitHub Actions first. No personal access token or cloud credential is required by this workflow.

Relative asset paths support both root and project Pages URLs. For a custom domain, configure it under **Settings → Pages** and follow [GitHub's custom domain instructions](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site).

## What the delivery pipeline demonstrates

```text
pull request ──► validate ──► syntax check ──► package ──► container smoke test
main push   ──► same checks ──► upload artifact ──► OIDC Pages deployment
```

- Static checks catch missing assets, broken internal anchors, duplicate IDs, invalid resume files, and basic accessibility omissions.
- The build copies an explicit list of site files into `_site/`. Tooling and repository files stay outside the deployment.
- `deployment.json` records the source commit and build time; `SHA256SUMS` records every packaged asset's SHA-256 digest.
- Action dependencies use verified full commit pins. Dependabot opens monthly action and container image updates.
- Only the deploy job receives `pages: write` and `id-token: write`; pull requests have read-only repository permissions. Checkout credentials are not persisted.
- The container smoke test verifies its health endpoint, homepage, and resume with a read-only filesystem, dropped capabilities, and no privilege escalation.

## Validate and build locally

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

On Linux or macOS with PowerShell 7 installed, use `pwsh -File scripts/validate.ps1` and `pwsh -File scripts/build.ps1`. If Node is available, `node --check script.js` checks JavaScript syntax locally too. The generated `_site/` directory is disposable and ignored by Git.

## Optional Docker preview

With Docker Desktop or Docker Engine installed, build the static artifact first, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
docker compose up --build -d
docker compose ps
```

Visit **http://localhost:8080/**. The container runs unprivileged and exposes a health endpoint at `/healthz`. Stop the PowerShell preview first if it uses the same port. Stop the container with `docker compose down`. This container is a portable alternative for local or container hosting; GitHub Pages serves the static artifact directly.

The NGINX base uses an explicit release tag and receives Dependabot updates. For immutable container builds, replace the base tag with a digest from your verified registry before deploying to your own environment.

## Edit your portfolio

| File | Purpose |
| --- | --- |
| `index.html` | Personal details, experience, skills, project summaries, contact links |
| `styles.css` | Colors, typography, responsive layouts, reduced-motion support |
| `script.js` | Navigation, interactive pipeline, project dialogs, contact interaction |
| `assets/resume.pdf` | Downloadable resume; replace with an updated PDF using the same name |
| `assets/favicon.svg` | Browser icon |
| `.github/workflows/pages.yml` | Validation, container checks, and Pages deployment |
| `scripts/` | Dependency-free validation, build, and local preview tools |

Update both the project summaries in `index.html` and their expanded details in `script.js` when changing projects. Replace professional links with your real public profiles whenever needed. Any phone number, email address, or resume included in the site will be visible to visitors.

## Rollback and troubleshooting

To roll back, revert the faulty commit and push the revert to `main`; the workflow redeploys the restored source. In the GitHub interface, use the merged pull request's **Revert** action when available.

- **Deploy fails with a Pages configuration error:** select GitHub Actions as the Pages source, confirm Pages is available for the repository, and rerun the workflow from `main`.
- **Deployment waits for approval:** check the `github-pages` environment's protection rules in repository settings.
- **Missing styles under a project URL:** keep asset URLs relative (for example, `styles.css`, not `/styles.css`).
- **Remote already exists:** use your existing clone or update the existing `origin`; the initialization commands above are for a new local repository.
- **Port 8080 is busy:** stop the other preview process, or run the PowerShell server with `-Port 8081`.

Official references: [Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [publishing source configuration](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), and [unprivileged NGINX](https://github.com/nginx/docker-nginx-unprivileged).
