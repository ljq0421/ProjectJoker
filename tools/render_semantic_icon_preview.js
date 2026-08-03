const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const projectRoot = path.resolve(__dirname, "..");
const iconRoot = path.join(
  projectRoot,
  "resources",
  "ui",
  "dream_glass",
  "icons"
);
const outputPath = path.join(
  projectRoot,
  "tmp",
  "semantic-icon-catalog.png"
);
const compactOutputPath = path.join(
  projectRoot,
  "tmp",
  "semantic-icon-catalog-32px.png"
);

const groups = [
  ["EFFECT", "effects"],
  ["TARGET", "targets"],
  ["ENGRAVING", "engravings"],
];

async function render() {
  const entries = [];
  for (const [groupLabel, folder] of groups) {
    const folderPath = path.join(iconRoot, folder);
    const filenames = fs
      .readdirSync(folderPath)
      .filter((name) => name.endsWith(".svg"))
      .sort();
    for (const filename of filenames) {
      entries.push({
        groupLabel,
        label: path.basename(filename, ".svg").replaceAll("_", " "),
        source: path.join(folderPath, filename),
      });
    }
  }

  const columns = 4;
  const cellWidth = 260;
  const cellHeight = 172;
  const headerHeight = 72;
  const rows = Math.ceil(entries.length / columns);
  const width = columns * cellWidth;
  const height = headerHeight + rows * cellHeight;
  const composites = [];

  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const column = index % columns;
    const row = Math.floor(index / columns);
    const left = column * cellWidth;
    const top = headerHeight + row * cellHeight;
    const icon = await sharp(entry.source).resize(96, 96).png().toBuffer();
    composites.push({ input: icon, left: left + 82, top: top + 12 });

    const labelSvg = Buffer.from(
      `<svg width="${cellWidth}" height="52" xmlns="http://www.w3.org/2000/svg">` +
        `<text x="130" y="18" text-anchor="middle" fill="#59E6DB" ` +
        `font-family="Arial, sans-serif" font-size="11" letter-spacing="2">` +
        `${entry.groupLabel}</text>` +
        `<text x="130" y="42" text-anchor="middle" fill="#F4F0FF" ` +
        `font-family="Arial, sans-serif" font-size="15">${entry.label}</text>` +
      `</svg>`
    );
    composites.push({ input: labelSvg, left, top: top + 112 });
  }

  const header = Buffer.from(
    `<svg width="${width}" height="${headerHeight}" xmlns="http://www.w3.org/2000/svg">` +
      `<text x="32" y="34" fill="#F4F0FF" font-family="Arial, sans-serif" ` +
      `font-size="24" font-weight="700">DREAM GLASS / SEMANTIC ICONS</text>` +
      `<text x="32" y="57" fill="#D27BE5" font-family="Arial, sans-serif" ` +
      `font-size="12" letter-spacing="2">DETERMINISTIC SVG · 64 × 64 · NO GENERATED ART</text>` +
    `</svg>`
  );
  composites.push({ input: header, left: 0, top: 0 });

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await sharp({
    create: {
      width,
      height,
      channels: 4,
      background: { r: 6, g: 5, b: 22, alpha: 1 },
    },
  })
    .composite(composites)
    .png()
    .toFile(outputPath);

  const compactColumns = 7;
  const compactCell = 80;
  const compactHeader = 44;
  const compactRows = Math.ceil(entries.length / compactColumns);
  const compactComposites = [];
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const column = index % compactColumns;
    const row = Math.floor(index / compactColumns);
    const icon = await sharp(entry.source).resize(32, 32).png().toBuffer();
    compactComposites.push({
      input: icon,
      left: column * compactCell + 24,
      top: compactHeader + row * compactCell + 24,
    });
  }
  const compactTitle = Buffer.from(
    `<svg width="${compactColumns * compactCell}" height="${compactHeader}" xmlns="http://www.w3.org/2000/svg">` +
      `<text x="18" y="28" fill="#F4F0FF" font-family="Arial, sans-serif" ` +
      `font-size="17" font-weight="700">ACTUAL 32 PX READABILITY CHECK</text>` +
    `</svg>`
  );
  compactComposites.push({ input: compactTitle, left: 0, top: 0 });
  await sharp({
    create: {
      width: compactColumns * compactCell,
      height: compactHeader + compactRows * compactCell,
      channels: 4,
      background: { r: 6, g: 5, b: 22, alpha: 1 },
    },
  })
    .composite(compactComposites)
    .png()
    .toFile(compactOutputPath);

  process.stdout.write(`${outputPath}\n${compactOutputPath}\n`);
}

render().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
