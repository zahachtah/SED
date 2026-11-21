# Publishing the Companion on GitHub Pages

The publication entry point is the repository-root `index.html`, built from
`webapp/`. It is entirely static and can also be opened directly from disk.
There is no backend, tracking, build-time secret, or runtime CDN dependency.

The project-site address is **[zahachtah.github.io/SED](https://zahachtah.github.io/SED/)**.

## Enable the Site

After the prepared files are committed and pushed:

1. In GitHub repository **Settings > Pages**, choose **GitHub Actions** as the
   build and deployment source.
2. Run the **Publish companion** workflow from the Actions tab.
3. Open the deployment URL once the workflow completes.

The repository's default branch is `master`. The workflow publishes changes
to the companion pages, their source, or the
deployment workflow when they reach `master`. It can also be run manually
(`workflow_dispatch`). It rebuilds and tests the page and deploys only the
the companion HTML only. The manuscript and supplementary material are pending
approval and are not deployed. Drafts, source code, and internal
archives are not copied into the site. Repository visibility is not changed.

The build job needs `contents: read` and `pages: read` so Configure Pages can
inspect the site. The deploy job separately receives `pages: write` and
`id-token: write`. If a previous run failed at Configure Pages, push the
corrected workflow before retrying; making the repository public does not
rerun a failed deployment automatically.

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
Recheck the site after deployment. Manuscript and supplementary-material
availability should read "pending approval", without download links.
