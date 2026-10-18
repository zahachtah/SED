# Publishing the Companion on GitHub Pages

The publication entry point is the repository-root `index.html`, built from
`webapp/`. It is entirely static and can also be opened directly from disk.
There is no backend, tracking, build-time secret, or runtime CDN dependency.

The intended project-site address is:

https://zahachtah.github.io/SED/

## Enable the Site

After the prepared files are committed and pushed:

1. In GitHub repository **Settings > Pages**, choose **GitHub Actions** as the
   build and deployment source.
2. Run the **Publish companion** workflow from the Actions tab.
3. Open the deployment URL once the workflow completes.

The workflow publishes changes to the companion, its reading PDFs, or the
deployment workflow when they reach `master`. It can also be run manually
(`workflow_dispatch`). It rebuilds and tests the page and deploys only the
HTML, manuscript PDF, and supplement PDF. Drafts, source code, and internal
archives are not copied into the site. Repository visibility is not changed.

GitHub also supports publishing directly from the root of a branch. The
prepared workflow gives finer control over what is deployed. See
[GitHub's custom-workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Update the Page and README Preview

```sh
node webapp/build.mjs
npm ci --prefix webapp
npm exec --prefix webapp -- playwright install chromium
npm run capture --prefix webapp
```

The capture command first runs the interaction and desktop/mobile checks.
Only after they pass does it write the actual desktop policy capture to
`docs/assets/companion.png` and insert the linked image into the README.
Additional light/dark and mobile captures remain in `tmp/companion/`.
Recheck the site after deployment, including its manuscript and supplementary
material links.
