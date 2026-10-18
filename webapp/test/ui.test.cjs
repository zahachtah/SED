const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

(async () => {
    const browser = await chromium.launch({ headless: true });
    const root = path.resolve(__dirname, "../.."), outputs = path.join(root, "tmp/companion");
    await fs.mkdir(outputs, { recursive: true });
    const page = await browser.newPage({ viewport: { width: 1512, height: 982 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(60000);
    const errors = []; page.on("pageerror", error => errors.push(error.message));
    const wait = async () => {
        await page.waitForFunction(() => window.__SED?.result && document.getElementById("statusButton").dataset.state !== "running");
    };
    try {
        await page.goto(pathToFileURL(path.join(root, "index.html")).href);
        await wait();
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        assert.equal(await page.locator("#scanButton").isVisible(), false);
        await page.screenshot({ path: path.join(outputs, "desktop-light.png") });
        await page.selectOption("#policy", "rights"); await wait();
        await page.locator("#quota").evaluate(node => {
            node.value = "0.25";
            node.dispatchEvent(new Event("input", { bubbles: true }));
        });
        await wait();
        const before = await page.evaluate(() => window.__SED.result.policy);
        assert.ok(Math.abs(before.quotaResidual) < 3e-5);
        await page.check("#historical"); await wait();
        const after = await page.evaluate(() => window.__SED.result.policy);
        assert.ok(Math.abs(before.y - after.y) < 3e-4);
        assert.ok(Math.abs(before.inequality - after.inequality) > 1e-4);
        await page.screenshot({ path: path.join(outputs, "companion-preview.png") });
        await page.click("#scanButton"); await wait();
        assert.equal(await page.locator("#quota").isVisible(), false);
        assert.equal(await page.evaluate(() => window.__SED.result.scan.length), 20);
        await page.click("#instrumentButton"); await wait();
        await page.click("#causalButton");
        await page.locator('[data-cause="capital"][data-column="1"]').fill("0.3");
        await page.click("#applyCausal"); await wait();
        assert.equal(await page.evaluate(() => window.__SED.params.populationMode), "causal");
        await page.click("#causalButton");
        await page.screenshot({ path: path.join(outputs, "population-builder.png") });
        await page.keyboard.press("Escape");
        await page.click("#themeButton");
        await page.screenshot({ path: path.join(outputs, "desktop-dark.png") });
        await page.setViewportSize({ width: 390, height: 844 });
        await page.screenshot({ path: path.join(outputs, "mobile-dark.png"), fullPage: true });
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        await page.click("#themeButton");
        await page.screenshot({ path: path.join(outputs, "mobile-light.png"), fullPage: true });
        for (const id of ["phaseCanvas", "incomeCanvas"]) {
            const nonblank = await page.locator(`#${id}`).evaluate(canvas => {
                const pixels = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data;
                const colors = new Set();
                for (let i = 0; i < pixels.length; i += 16) colors.add(`${pixels[i]},${pixels[i + 1]},${pixels[i + 2]}`);
                return colors.size > 20;
            });
            assert.ok(nonblank, `${id} must contain rendered plot pixels`);
        }
        assert.deepEqual(errors, []);
        if (process.argv.includes("--update-readme")) {
            const assets = path.join(root, "docs/assets");
            await fs.mkdir(assets, { recursive: true });
            await fs.copyFile(path.join(outputs, "companion-preview.png"), path.join(assets, "companion.png"));
            const readmePath = path.join(root, "README.md");
            const readme = await fs.readFile(readmePath, "utf8");
            const marker = /<!-- companion-screenshot -->(?:\n\[!\[Interactive SED companion[^\n]*\n)?/;
            assert.ok(marker.test(readme), "README preview insertion marker must exist");
            const preview = "<!-- companion-screenshot -->\n[![Interactive SED companion: resource balance, policy controls, and income distributions](docs/assets/companion.png)](https://zahachtah.github.io/SED/)\n";
            await fs.writeFile(readmePath, readme.replace(marker, preview));
            console.log("Updated the linked README preview from the verified browser capture.");
        }
        console.log("Browser interaction, desktop/mobile overflow, and canvas checks passed.");
    } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
