# Prakhar Shukla · DevOps portfolio

A custom, responsive portfolio built with HTML, CSS, and JavaScript. The deployment-control-room design includes an interactive pipeline demonstration, project details, career history, and a downloadable resume. Content comes from the supplied resume. The pipeline animation is an illustration; it does not report live infrastructure status.

## Blog updates

GitHub Actions reads `https://www.prakharshukla.org/blog-feed.xml` and renders the two newest articles, followed by your featured article, into the deployed portfolio. Publish a post on the blog as usual; the portfolio refreshes approximately every six hours. You can update sooner through **Actions → Validate and deploy portfolio → Run workflow → main**. Pushes to `main` also refresh the previews.

The third slot is pinned to **“Your Eyes Are Off Slant”**. Change `config/blog-featured.json` to feature a different article. The saved title, publication timestamp, category, and excerpt keep the featured article available even after it falls outside the RSS feed's recent-post window. A featured article also present in the feed is shown once, in the featured slot.

The schedule runs at 00:17, 06:17, 12:17, and 18:17 UTC (05:47, 11:47, 17:47, and 23:47 IST). GitHub may delay scheduled runs. Schedules run from the default branch and can be disabled after 60 days without repository activity in a public repository; re-enable the workflow in Actions if that happens.

Article titles, links, excerpts, and dates come from the public feed. Reading times are estimated only when the feed includes full article text; publication dates use India time. The refresh changes the deployment artifact, without creating commits in this repository. `blog-sync.json` in the published output records the feed refresh details.

Normal local builds use the saved article previews and work offline. To refresh a local build explicitly on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1 -RefreshBlog
```

Open `_site/index.html` to view that refreshed build. Pull requests use the offline previews and feed fixtures. If the live feed cannot be read or contains no valid posts, deployment stops and the previously published site stays available. This also means a temporary feed outage can delay a normal deployment to `main`.



