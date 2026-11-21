import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const root = new URL("./", import.meta.url);
let html = await readFile(new URL("index.html", root), "utf8");
const css = await readFile(new URL("companion.css", root), "utf8");
html = html.replace('<link rel="stylesheet" href="companion.css">', `<style>\n${css}\n</style>`);
for (const path of ["vendor/lucide.min.js", "model.js", "runner.js", "plots.js", "app.js"]) {
    const source = (await readFile(new URL(path, root), "utf8")).replace(/\/\/# sourceMappingURL=.*$/gm, "");
    html = html.replace(`<script src="${path}"></script>`, () => `<script>\n${source}\n</script>`);
}
html = html.replaceAll("../manuscript/", "manuscript/")
    .replaceAll("../SupplementaryMaterial/", "SupplementaryMaterial/");
const output = new URL("../index.html", root);
if (process.argv.includes("--check")) {
    if (await readFile(output, "utf8") !== html) {
        throw new Error("index.html is out of date. Run node webapp/build.mjs.");
    }
    console.log("index.html matches the companion source.");
} else {
    await writeFile(output, html);
}
if (process.argv.includes("--pages")) {
    const site = new URL("../tmp/pages/", root);
    await rm(site, { recursive: true, force: true });
    await mkdir(site, { recursive: true });
    await writeFile(new URL("index.html", site), html);
    await writeFile(new URL(".nojekyll", site), "");
    console.log(`Staged publication site in ${fileURLToPath(site)}`);
}
console.log(`Built ${fileURLToPath(output)} (${Math.round(Buffer.byteLength(html) / 1024)} KiB, self-contained)`);
