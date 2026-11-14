# Explaining the portfolio engineering

This guide describes the implementation in this repository. The professional projects on the website use Azure DevOps, Docker, AKS, and Terraform. This portfolio has its own, smaller delivery system: GitHub Actions builds and checks a static artifact, Docker tests how that artifact is served, and GitHub Pages hosts the public website.

## The problem I addressed

A portfolio needs more than an initial upload. Content changes can break a resume link or page anchor, blog previews become stale, and a successful file copy does not show that the site can be served. I built a repeatable route from source changes to a checked deployment, with scheduled blog refreshes and an artifact that can be traced to its source commit.

The application stays small: HTML, CSS, JavaScript, and local assets. The engineering is in the validation, packaging, content synchronization, and delivery around those files.

## Confirmed professional achievements

These achievements belong to the roles below. Their attribution to VeriKYB or Financial Account Opening has not been established. They describe professional Azure delivery work; the static portfolio's hosting remains GitHub Pages.

| Role | Confirmed contribution | Practical value |
| --- | --- | --- |
| EXL Services, DevOps Engineer, August 2022–November 2024 | Designed and implemented YAML-based Azure DevOps CI to automate dependency installation, code quality checks, and testing; validated pipeline execution. | Reduced manual code verification and improved workflow consistency. |
| Infosys, DevOps Engineer, November 2024–July 2026 | Wrote Bash scripts to provision Azure Container Registry and Azure Container Apps. Established Git branching and pull request approval workflows. | Improved review and release consistency and deployment readiness. |

### Interview talking points

**EXL Services:** “I designed and implemented a YAML-based CI pipeline in Azure DevOps that installed dependencies, ran code quality checks, and executed tests. I also validated its execution. That moved routine code verification into the pipeline, reducing manual verification and giving the team a more consistent workflow.”

**Infosys:** “I wrote Bash scripts to provision Azure Container Registry and Azure Container Apps. I also worked on Git branching and pull request approval workflows to improve review and release consistency and deployment readiness. The Bash work handled Azure resource provisioning, while the Git workflow made the review path clearer.”

These outcomes are qualitative; no measured time savings, failure-rate improvements, or cost reductions have been provided.

## What each tool actually does

| Tool | Responsibility in this repository | Evidence |
| --- | --- | --- |
| Git and GitHub | Store the source and provide pull requests for review. | Source repository and workflow pull request trigger. |
| GitHub Actions | Run validation, tests, packaging, container smoke checks, and eligible Pages deployments. | `.github/workflows/pages.yml` |
| PowerShell | Check the site, assemble `_site`, generate deployment metadata and checksums, and refresh blog previews from RSS. | `scripts/validate.ps1`, `scripts/build.ps1`, `scripts/sync-blog.ps1` |
| Bash | Start the CI container, wait for its health endpoint with bounded curl retries, check served pages, and collect logs/clean up on exit. | Inline Bash step in `pages.yml` |
| Docker and NGINX | Serve the packaged artifact in a consistent local or CI environment, using an unprivileged NGINX process on port 8080. | `Dockerfile`, `compose.yaml`, `nginx.conf` |
| GitHub Pages | Host the verified static artifact publicly. | The workflow's `deploy` job |

Azure and AKS belong to the professional experience described in the portfolio. They are not the hosting architecture for this website. Docker demonstrates and verifies container delivery here; Pages serves the live site without that container running in production.

## The delivery flow

1. A pull request to `main` runs validation, a JavaScript syntax check, offline RSS tests, the build, and a container smoke test. It does not deploy or fetch fresh blog content during that build.
2. A push to `main`, a manual run on `main`, or the scheduled run follows the same checks and refreshes the blog previews while building the artifact. The schedule is `17 */6 * * *` in UTC, approximately every six hours.
3. `build.ps1` validates the source, recreates the fixed project-local `_site` directory, and copies only the site files and assets. Optional hosting files are copied when present. Documentation, scripts, and repository internals stay outside the site artifact.
4. When requested, `sync-blog.ps1` reads the blog RSS feed and updates only the marked blog area in `_site/index.html`. The source page is not rewritten by the workflow.
5. The generated page is validated again. The build adds `.nojekyll`, `deployment.json` with the source commit and build time, and a SHA-256 manifest named `SHA256SUMS` for the packaged files.
6. Docker builds an image from `_site`. CI starts it locally and checks `/healthz`, `/`, and `/assets/resume.pdf`. A successful file build therefore also has a basic HTTP serving check.
7. After the validation job succeeds, eligible runs upload `_site` and deploy that artifact to GitHub Pages. A failure in validation, feed refresh, build, or the container checks prevents a new deployment; the already published site remains available.

Blog refreshes are build output. There is no bot commit loop and no write access to repository contents for this process.

## Why these choices matter

**Validation before deployment:** The PowerShell validator checks required files, local links, section anchors, unique IDs, basic page metadata, image alt attributes, new-tab link attributes, the resume PDF signature, and the social image format and dimensions. It also checks that CSS assets exist and that reduced-motion styling is present. These are focused automated checks; visual and browser review still serve a separate purpose.

**An isolated artifact:** Only the allowlisted public files are copied to `_site`. Source metadata links a deployed artifact to a commit. Checksums make file changes inspectable; they are not a digital signature or a claim of external attestation.

**Fresh content without visitor-side fetching:** The RSS content is rendered at build time, so article links and text are already in the delivered HTML. With the configured featured post, the page shows the two newest other articles and one featured article. The saved featured metadata keeps that article available when it falls outside the RSS feed's current window. Current RSS details take precedence when the article is still in the feed.

**Bounded, checked feed processing:** The script restricts article links to the expected HTTPS blog host and post paths, canonicalizes links before deduplication, sorts publication times, strips imported markup, and HTML-escapes displayed text. It rejects malformed or empty feeds and invalid featured configuration. Parsing and rendering finish before temporary output replaces the HTML, and the failure tests verify preservation of existing HTML and metadata for rejected input. A failed feed refresh stops the build from reaching deployment.

**A constrained container:** NGINX runs as user `101:101` on port 8080. Compose and CI use a read-only filesystem, a small temporary `/tmp`, dropped Linux capabilities, and `no-new-privileges`. Local binding is to `127.0.0.1`. `.dockerignore` limits the image build context to the Dockerfile, NGINX configuration, and `_site`.

**Scoped deployment permissions:** Workflow permissions default to `contents: read`, and checkout does not persist repository credentials. The deployment job alone receives `pages: write` and `id-token: write` for the Pages deployment/OIDC flow. Actions are pinned to commit SHAs. The workflow does not store an Azure credential or a repository-write token for deployment.

## Troubleshooting examples visible in the code

These are concrete failure modes handled by the current implementation. Describe them as engineering decisions unless you also have a personal incident history to discuss.

| Failure mode | Implemented response | What it demonstrates |
| --- | --- | --- |
| An HTTP request reaches the container before NGINX is ready and gets a connection reset or refusal. | The first CI `/healthz` request uses `curl --retry 10 --retry-all-errors` with time limits. An exit trap prints container logs and removes the container. | Check service readiness and retain diagnostic output instead of assuming startup is immediate. |
| Windows PowerShell and newer PowerShell deserialize a JSON timestamp into different runtime types. | `Assert-PublishedInstant` normalizes strings and date values and compares UTC ticks. Tests include equivalent offset timestamps. | Test the actual publication instant across local Windows and Linux CI runtimes. |
| A featured article disappears from the RSS feed's limited window. | `config/blog-featured.json` supplies saved title, date, category, and excerpt when the feed lacks that article. | Keep editorial intent stable while recent posts continue to refresh. |
| Invalid RSS or unsafe article links arrive during a refresh. | The script rejects invalid input, and fixture tests verify the original files remain unchanged for failure cases. | Make content ingestion fail visibly before deployment. |

## What impact can be shown

The evidence is observable behavior: pull requests get automated feedback, broken local references fail validation, blog updates render during the build, CI checks that the resume is served over HTTP, and the published artifact records its source commit. The workflow removes the need to manually edit the latest article cards after each post. A failed candidate cannot advance to the deployment job.

There are no recorded before/after deployment-time, cost, uptime, or failure-rate measurements in this repository. Explain the implemented controls and demonstrate their behavior when discussing impact.

## A 60-second interview explanation

> I built my portfolio as a small DevOps delivery project. The site is static HTML, CSS, and JavaScript, and GitHub Pages hosts it. GitHub Actions checks every pull request, then eligible main-branch runs package and deploy the site. I used PowerShell to validate links and assets, build an isolated artifact, and refresh the blog section from RSS. That refresh shows the latest articles plus a configured featured post, with validation and offline tests around malformed feeds and dates. Docker runs the same artifact in unprivileged NGINX for local preview and CI smoke tests. A short Bash step waits for the container and checks the homepage and resume. Only a successful validation job can reach deployment, and deployment metadata records the source commit. The result is a portfolio whose update process I can inspect, test, and explain.

## The same explanation in simple Hinglish

**Website kya hai?** HTML, CSS aur JavaScript se bani static portfolio website hai. Live hosting GitHub Pages par hai.

**GitHub Actions ka role?** Ye automated coordinator hai. PR ya main branch ke change par checks chalata hai. Sab checks pass hone ke baad main branch ka artifact deploy hota hai. Scheduled run blog cards ko bhi refresh karta hai.

**PowerShell ka role?** Actual kaam scripts karti hain: links aur files check karna, deploy wali `_site` folder banana, RSS se articles lena, aur build ki source details aur checksums likhna. Actions in scripts ko sahi order mein chalata hai.

**Docker kyun use kiya?** Packaged website ko NGINX ke saath ek consistent environment mein serve karke check karne ke liye. Local preview aur CI mein homepage aur resume open hote hain ya nahi, ye verify hota hai. Live website GitHub Pages serve karta hai.

**Bash ka role?** CI ke Linux runner par Docker container start karna, ready hone tak limited retries karna, HTTP checks chalana, aur end mein logs dikhakar cleanup karna.

**Isme mera engineering contribution kya hai?** Maine sirf page publish nahi kiya; change se deployment tak repeatable process banaya. Galat link ya invalid feed par naya deployment rukta hai, blog cards automatically update hote hain, aur artifact se pata lagta hai ki kaunsa commit build hua tha.

## Demonstrate it locally

Run these from the repository root in PowerShell:

```powershell
./scripts/validate.ps1
./tests/test-blog-sync.ps1
./scripts/build.ps1
```

To exercise feed rendering without a network request, use the local RSS fixture:

```powershell
./scripts/build.ps1 -RefreshBlog -BlogFeedPath ./tests/fixtures/blog-feed.xml
```

With Node available, run `node --check script.js`. With Docker available, run `docker compose up --build` after building `_site`, then open `http://127.0.0.1:8080/` and check the resume link. The on-page pipeline animation is a labelled UI simulation; the real delivery implementation is the workflow in `.github/workflows/pages.yml`.
