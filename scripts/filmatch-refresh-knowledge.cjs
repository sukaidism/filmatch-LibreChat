const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const dir = path.resolve(process.argv[2] || path.join(root, 'filmatch-document'));
// On AWS the live config sits in a mounted directory (see deploy/aws/scripts/deploy.sh).
const configPath = path.resolve(
  process.env.FILMATCH_CONFIG_PATH || path.join(root, 'librechat.filmatch.yaml'),
);
const files = {
  '01-menu.md': 'Menu',
  '02-ingredients-and-allergens.md': 'Ingredients and Allergen Information',
  '03-customisation.md': 'Customisation Guide',
  '04-cafe-information.md': 'Cafe Information',
  '05-policies.md': 'Service Policies',
};

// Fail before touching the active config if any approved document is missing or empty.
const sections = Object.entries(files).map(([file, title]) => {
  let body = fs.readFileSync(path.join(dir, file), 'utf8').trim();
  if (!body) throw new Error(`Empty knowledge document: ${file}`);
  for (const [name, label] of Object.entries(files)) body = body.split(name).join(label);
  return `SOURCE: ${title}\n${body}\nEND SOURCE: ${title}`;
});
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const spec = config.modelSpecs.list.find((s) => s.name === 'ask-filmatch-assistant');
if (!spec) throw new Error('Ask Filmatch model specification not found');
const prefix = spec.preset.promptPrefix;
const index = prefix.indexOf('\nSOURCE: Menu\n');
if (index < 0 || !prefix.includes('END SOURCE: Service Policies')) {
  throw new Error('Expected knowledge section markers are missing');
}
const menuImage = path.join(root, 'client', 'public', 'assets', 'filmatch-menu.png');
const menuImageRule =
  'PUBLIC MENU IMAGE: When asked to see, show, view, or receive the full menu or an image/photo of the menu (including Filipino requests), provide the customer-facing printed menu inline using exactly this Markdown image: ![Filmatch menu](/assets/filmatch-menu.png). This public asset is approved for sharing; it is not an internal source or citation. Include a short reply in the language of the latest user message, and text details when requested. Never invent another image or attach the menu image to unrelated questions.';
const instructions = prefix
  .slice(0, index)
  .trimEnd()
  .split('\n')
  .filter((line) => !line.startsWith('PUBLIC MENU IMAGE:'))
  .join('\n');
let menuAvailable = false;
if (fs.existsSync(menuImage)) {
  const bytes = fs.readFileSync(menuImage);
  const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length < 24 || !bytes.subarray(0, 8).equals(pngSignature)) {
    throw new Error('The public menu image must be a valid PNG file.');
  }
  menuAvailable = true;
}
spec.preset.promptPrefix = `${instructions}${menuAvailable ? `\n${menuImageRule}` : ''}\n\n${sections.join('\n\n')}`;
const { configSchema } = require('librechat-data-provider');
configSchema.parse(config);
const pending = `${configPath}.${process.pid}.tmp`;
try {
  fs.writeFileSync(pending, JSON.stringify(config, null, 2) + '\n', { flag: 'wx' });
  fs.renameSync(pending, configPath);
} finally {
  if (fs.existsSync(pending)) fs.unlinkSync(pending);
}
console.log(
  `Refreshed ${sections.length} approved Filmatch knowledge documents. Restart the backend and start a new chat.`,
);
