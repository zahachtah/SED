const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "../..");
const companion = "https://zahachtah.github.io/SED/";

async function filesIn(directory) {
    const files = [];
    for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
        const full = path.join(directory, entry.name);
        if (entry.isDirectory()) files.push(...await filesIn(full));
        else files.push(full);
    }
    return files;
}

(async () => {
    const guides = ["README.md", "AGENTS.md", "manuscript/README.md",
        "SupplementaryMaterial/README.md", "webapp/README.md", "webapp/SCIENCE.md",
        ...(await filesIn(path.join(root, "docs")))
            .filter(file => file.endsWith(".md")).map(file => path.relative(root, file))];
    let checked = 0;
    for (const guide of guides) {
        const markdown = await fs.readFile(path.join(root, guide), "utf8");
        for (const match of markdown.matchAll(/\]\(([^\s)]+)\)/g)) {
            const target = match[1];
            if (/^(?:[a-z][a-z0-9+.-]*:|#)/i.test(target)) continue;
            const relative = decodeURIComponent(target.split("#")[0]);
            await assert.doesNotReject(fs.access(path.resolve(root, path.dirname(guide), relative)),
                `${guide}: missing link target ${target}`);
            checked++;
        }
    }
    const readme = await fs.readFile(path.join(root, "README.md"), "utf8");
    assert.ok(readme.includes(`](${companion})`), "README links directly to the hosted companion");
    assert.ok(readme.includes("docs/assets/companion.png"), "README includes the linked browser preview");

    execFileSync(process.execPath, ["webapp/build.mjs", "--check", "--pages"],
        { cwd: root, stdio: "pipe" });
    const stage = path.join(root, "tmp/pages");
    const expected = [".nojekyll", "index.html"].sort();
    const staged = (await filesIn(stage)).map(file => path.relative(stage, file)).sort();
    assert.deepEqual(staged, expected, "Only the companion is published pending document approval");
    for (const file of expected.filter(file => file !== ".nojekyll")) {
        assert.deepEqual(await fs.readFile(path.join(stage, file)), await fs.readFile(path.join(root, file)),
            `Published ${file} matches the repository copy`);
    }
    const html = await fs.readFile(path.join(stage, "index.html"), "utf8");
    assert.doesNotMatch(html, /<script[^>]+src\s*=/i, "The standalone companion has no external scripts");
    assert.doesNotMatch(html, /<link[^>]+rel=["']stylesheet["']/i, "The stylesheet is embedded");
    assert.ok(html.includes("Manuscript (pending approval)"));
    assert.ok(html.includes("Supplementary material (pending approval)"));
    assert.doesNotMatch(html, /href=["'][^"']*\.pdf(?:[?#][^"']*)?["']/i);
    console.log(`Publication checks passed: ${checked} local documentation links; standalone HTML; exact Pages allowlist.`);
})().catch(error => { console.error(error); process.exitCode = 1; });
