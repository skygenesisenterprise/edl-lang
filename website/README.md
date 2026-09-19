# EDL website

This directory contains the official static EDL documentation site, built with Astro. It is intentionally a lightweight custom layout: no parser or compiler behavior is reimplemented in the site, and code examples are sourced from the repository.

## Development

```sh
npm install
npm run dev
npm run check
npm run build
npm run preview
```

The site uses static output, sitemap generation, responsive light/dark CSS, and minimal JavaScript (none is required currently). `ASTRO_BASE` can set a future sub-path or deployment base.

## Deployment

`.github/workflows/website.yml` builds pull requests and deploys pushes to `master` through GitHub Pages. The build job runs `npm ci`, `npm run check`, and `npm run build`, then passes the generated `website/dist` artifact to the deployment job. Pull requests are validated but never deployed.

In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. After a push to `master` completes successfully, the site is served at `https://edl-lang.github.io`. The Astro canonical URL and sitemap are already configured for that host.

When `edl-lang.org` is officially ready, update `site` in `astro.config.mjs`, add `website/public/CNAME` containing `edl-lang.org`, configure the custom domain in repository Pages settings, and keep `ASTRO_BASE=/` because the custom domain is hosted at the root. Do not add `CNAME` before the domain is activated.

## Contributing

Keep documentation claims aligned with the implementation. Distinguish available, experimental, and planned features, and prefer links to the repository's authoritative source and releases.
