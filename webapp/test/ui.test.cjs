const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

(async () => {
    const browser = await chromium.launch({ headless: true,
        ...(process.env.PLAYWRIGHT_EXECUTABLE_PATH ? {executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH} : {}) });
    const root = path.resolve(__dirname, "../.."), outputs = path.join(root, "tmp/companion");
    await fs.mkdir(outputs, { recursive: true });
    const page = await browser.newPage({ viewport: { width: 1512, height: 982 }, deviceScaleFactor: 1 });
    await page.addInitScript(() => {
        const OriginalWorker = window.Worker;
        window.__workerStarts = 0;
        window.Worker = class extends OriginalWorker {
            constructor(...args) { super(...args); window.__workerStarts++; }
        };
    });
    page.setDefaultTimeout(60000);
    const errors = []; page.on("pageerror", error => errors.push(error.message));
    const wait = async () => {
        await page.waitForFunction(() => window.__SED?.result && document.getElementById("statusButton").dataset.state !== "running");
    };
    try {
        await page.goto(pathToFileURL(path.join(root, "index.html")).href);
        await wait();
        assert.ok((await page.locator("#metrics").innerText()).includes("Resource rent"));
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        assert.equal(await page.locator("#scanButton").isVisible(), false);
        assert.equal(await page.evaluate(() => window.__workerStarts), 1);
        assert.equal((await page.locator("#scanButton").innerText()).trim(), "Scan policy");
        await page.screenshot({ path: path.join(outputs, "desktop-light.png") });
        await page.evaluate(() => { window.incomeToggleResult = window.__SED.result; });
        await page.click('[data-income-view="change"]');
        assert.equal(await page.getAttribute('[data-income-view="change"]', "aria-pressed"), "true");
        assert.equal(await page.evaluate(() => window.__SED.result === window.incomeToggleResult), true);
        assert.equal(await page.locator("#incomeKey").isVisible(), false);
        assert.equal(await page.locator("#incomeChangeKey").isVisible(), true);
        assert.equal(await page.evaluate(() => SEDPlots.incomeRows(window.__SED.result, window.__SED.params).every(a => a.incomeChange === 0)), true);
        await page.click('[data-income-view="levels"]');
        assert.equal(await page.evaluate(() => window.__SED.result === window.incomeToggleResult), true);
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
        assert.equal(await page.evaluate(() => window.__workerStarts), 1, "completed policy changes reuse the initial worker");
        assert.ok(Math.abs(before.y - after.y) < 3e-4);
        assert.ok(Math.abs(before.inequality - after.inequality) > 1e-4);
        await page.screenshot({ path: path.join(outputs, "companion-preview.png") });
        await page.click('[data-income-view="change"]');
        await page.selectOption("#incomeSort", "threshold");
        await page.check("#logIncome");
        await page.locator("#incomeCanvas").hover();
        assert.ok((await page.locator("#incomeTooltip").innerText()).includes("Open-access income"));
        await page.locator("#incomeCanvas").dispatchEvent("pointerleave");
        await page.screenshot({ path: path.join(outputs, "income-change-desktop.png") });
        await page.click("#scanButton"); await wait();
        assert.equal(await page.locator(".income-view-switch").isVisible(), false);
        assert.equal(await page.locator("#incomeChangeKey").isVisible(), false);
        assert.equal(await page.locator("#quota").isVisible(), false);
        assert.equal(await page.evaluate(() => window.__SED.result.scan.length), 20);
        assert.equal(await page.locator(".workspace.is-scanning").count(), 1);
        await page.screenshot({ path: path.join(outputs, "policy-scan-extrema-desktop.png") });
        await page.setViewportSize({ width: 390, height: 844 });
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        await page.screenshot({ path: path.join(outputs, "policy-scan-extrema-mobile.png"), fullPage: true });
        await page.setViewportSize({ width: 1512, height: 982 });
        await page.click("#instrumentButton"); await wait();
        assert.equal(await page.locator(".income-view-switch").isVisible(), true);
        assert.equal(await page.getAttribute('[data-income-view="change"]', "aria-pressed"), "true");
        await page.click('[data-income-view="levels"]');
        await page.uncheck("#logIncome");
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
        await page.click('[data-income-view="change"]');
        await page.screenshot({ path: path.join(outputs, "income-change-mobile.png"), fullPage: true });
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
        await page.click("#themeButton");
        await page.screenshot({ path: path.join(outputs, "income-change-mobile-dark.png"), fullPage: true });
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
