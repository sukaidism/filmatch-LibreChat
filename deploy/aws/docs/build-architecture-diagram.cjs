/**
 * Generates filmatch-aws-architecture.svg in the AWS Architecture Icons style
 * (AWS Cloud / Region / AZ / VPC / subnet groups, category-coloured service tiles,
 * numbered step badges). Run:  node deploy/aws/docs/build-architecture-diagram.cjs
 * Icons are simplified hand-drawn glyphs in the official category colours.
 */
const fs = require('fs');
const path = require('path');

const W = 1660;
const H = 1150;
const C = {
  compute: '#ED7100',
  storage: '#7AA116',
  database: '#C925D1',
  network: '#8C4FFF',
  security: '#DD344C',
  mgmt: '#E7157B',
  appint: '#E7157B',
  cost: '#7AA116',
  ink: '#232F3E',
  grey: '#7D8998',
};
const out = [];
const add = (s) => out.push(s);
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// ------------------------------------------------------------------ glyphs (56x56 box)
const G = {
  ec2: `<rect x="17" y="17" width="22" height="22" rx="2"/>${[22, 28, 34].map((p) => `<path d="M${p} 11v6M${p} 39v6M11 ${p}h6M39 ${p}h6"/>`).join('')}`,
  container: `<path d="M28 12 42 20v16l-14 8-14-8V20z"/><path d="M14 20l14 8 14-8M28 28v16"/>`,
  lambda: `<text x="28" y="41" text-anchor="middle" font-size="34" font-weight="bold" fill="#fff" stroke="none" font-family="Georgia, serif">λ</text>`,
  s3: `<ellipse cx="28" cy="17" rx="14" ry="5"/><path d="M14 17l3 24c1 3 21 3 22 0l3-24"/><path d="M28 27l12 5"/>`,
  cloudfront: `<circle cx="28" cy="28" r="15"/><ellipse cx="28" cy="28" rx="6" ry="15"/><path d="M13 28h30M16 20h24M16 36h24"/>`,
  key: `<circle cx="20" cy="28" r="7"/><path d="M27 28h17M38 28v6M43 28v5"/><path d="M14 13h28M14 44h28"/>`,
  ecr: `<rect x="13" y="20" width="22" height="22" rx="2"/><path d="M35 26h8v16H21v-0"/><path d="M19 28h10M19 34h10"/><path d="M30 12l6 0 0 6"/>`,
  cloudwatch: `<circle cx="25" cy="27" r="12"/><path d="M34 36l9 9"/><path d="M17 30l5-6 4 4 6-8"/>`,
  logs: `<path d="M16 12h17l8 8v24H16z"/><path d="M33 12v8h8M21 26h15M21 32h15M21 38h10"/>`,
  sns: `<circle cx="28" cy="28" r="5"/><circle cx="14" cy="17" r="3"/><circle cx="42" cy="17" r="3"/><circle cx="14" cy="39" r="3"/><circle cx="42" cy="39" r="3"/><path d="M17 19l7 6M39 19l-7 6M17 37l7-6M39 37l-7-6"/>`,
  eventbridge: `<circle cx="16" cy="28" r="4"/><circle cx="40" cy="16" r="4"/><circle cx="40" cy="40" r="4"/><path d="M20 26l16-8M20 30l16 8"/><path d="M40 20v16"/>`,
  iam: `<rect x="13" y="13" width="30" height="30" rx="4"/><circle cx="28" cy="24" r="5"/><path d="M19 38c2-6 16-6 18 0"/>`,
  cloudtrail: `<path d="M13 40c6-14 10-14 15-6s9 8 15-10"/><circle cx="13" cy="40" r="2.5"/><circle cx="43" cy="24" r="2.5"/><path d="M14 14h12M14 20h8"/>`,
  budgets: `<text x="28" y="39" text-anchor="middle" font-size="28" font-weight="bold" fill="#fff" stroke="none" font-family="Arial">$</text><circle cx="28" cy="28" r="16"/>`,
  backup: `<path d="M28 11l14 5v11c0 9-6 15-14 18-8-3-14-9-14-18V16z"/><path d="M28 21v8l5 3"/>`,
  ebs: `<ellipse cx="28" cy="17" rx="13" ry="5"/><path d="M15 17v22c0 7 26 7 26 0V17"/><path d="M15 28c0 7 26 7 26 0"/>`,
  mongo: `<ellipse cx="28" cy="16" rx="13" ry="5"/><path d="M15 16v24c0 7 26 7 26 0V16"/><path d="M15 24c0 7 26 7 26 0M15 32c0 7 26 7 26 0"/>`,
  eip: `<circle cx="28" cy="28" r="15"/><text x="28" y="33" text-anchor="middle" font-size="13" font-weight="bold" fill="#fff" stroke="none" font-family="Arial">IP</text>`,
  agent: `<path d="M14 36a14 14 0 0 1 28 0"/><path d="M28 36l8-10"/><path d="M14 42h28"/>`,
  ssm: `<circle cx="28" cy="28" r="7"/>${[0, 45, 90, 135, 180, 225, 270, 315]
    .map((a) => {
      const r = (a * Math.PI) / 180;
      return `<path d="M${(28 + 10 * Math.cos(r)).toFixed(1)} ${(28 + 10 * Math.sin(r)).toFixed(1)}L${(28 + 15 * Math.cos(r)).toFixed(1)} ${(28 + 15 * Math.sin(r)).toFixed(1)}"/>`;
    })
    .join('')}`,
};

function icon(x, y, color, glyph, lines, opts = {}) {
  add(
    `<g transform="translate(${x},${y})"><rect width="56" height="56" rx="4" fill="${color}"/>` +
      `<g fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${G[glyph]}</g></g>`,
  );
  label(x + 28, y + 72, lines, opts);
}
function label(cx, y, lines, { bold = 0, size = 12.5 } = {}) {
  lines.forEach((t, i) =>
    add(
      `<text x="${cx}" y="${y + i * 15}" text-anchor="middle" font-size="${i === 0 && !bold ? size : 11}" fill="${i === 0 ? C.ink : '#545B64'}"${i === 0 ? ' font-weight="bold"' : ''}>${esc(t)}</text>`,
    ),
  );
}
// AWS group with tag square in the top-left corner.
function group(
  x,
  y,
  w,
  h,
  { color, title, dash = false, fill = 'none', tag = null, tagGlyph = null, textColor },
) {
  add(
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" stroke="${color}" stroke-width="1.6"${dash ? ' stroke-dasharray="6 4"' : ''}/>`,
  );
  let tx = x + 10;
  if (tag) {
    add(`<rect x="${x}" y="${y}" width="30" height="30" fill="${tag}"/>`);
    if (tagGlyph)
      add(
        `<g transform="translate(${x + 3},${y + 3}) scale(0.43)" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">${G[tagGlyph] || tagGlyph}</g>`,
      );
    tx = x + 38;
  }
  add(
    `<text x="${tx}" y="${y + 20}" font-size="13" fill="${textColor || color}" font-weight="bold">${esc(title)}</text>`,
  );
}
function generic(x, y, w, h, lines, glyph) {
  add(
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="6" fill="#F2F3F3" stroke="${C.grey}" stroke-width="1.4"/>`,
  );
  if (glyph)
    add(
      `<g transform="translate(${x + w / 2 - 20},${y + 10}) scale(0.72)" fill="none" stroke="${C.ink}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">${glyph}</g>`,
    );
  lines.forEach((t, i) =>
    add(
      `<text x="${x + w / 2}" y="${y + (glyph ? 70 : 24) + i * 15}" text-anchor="middle" font-size="${i ? 11 : 12.5}" fill="${i ? '#545B64' : C.ink}"${i ? '' : ' font-weight="bold"'}>${esc(t)}</text>`,
    ),
  );
}
const arrow = (d, ops = false, both = false) =>
  add(
    `<path d="${d}" fill="none" stroke="${ops ? C.grey : C.ink}" stroke-width="${ops ? 1.6 : 2.2}"${ops ? ' stroke-dasharray="6 4"' : ''} marker-end="url(#${ops ? 'ag' : 'a'})"${both ? ` marker-start="url(#${ops ? 'ag' : 'a'})"` : ''}/>`,
  );
const badge = (cx, cy, n) =>
  add(
    `<circle cx="${cx}" cy="${cy}" r="13" fill="${C.ink}"/><text x="${cx}" y="${cy + 5}" text-anchor="middle" font-size="13" font-weight="bold" fill="#fff">${n}</text>`,
  );
const note = (x, y, t, anchor = 'start') =>
  add(
    `<text x="${x}" y="${y}" font-size="11" fill="#545B64" font-style="italic" text-anchor="${anchor}">${esc(t)}</text>`,
  );

// ------------------------------------------------------------------ canvas
add(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="'Amazon Ember', Arial, Helvetica, sans-serif">`,
);
add('<title>Filmatch on AWS - infrastructure design</title>');
add(
  '<desc>Where every part of Filmatch runs in AWS and how a question travels from the customer to the Gemini model and back.</desc>',
);
add(
  `<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="${C.ink}"/></marker>` +
    `<marker id="ag" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="${C.grey}"/></marker></defs>`,
);
add(`<rect width="${W}" height="${H}" fill="#fff"/>`);

// ------------------------------------------------------------------ external actors
const userGlyph = '<circle cx="28" cy="18" r="9"/><path d="M10 50c2-14 34-14 36 0z"/>';
add(
  `<g transform="translate(52,236)" fill="none" stroke="${C.ink}" stroke-width="2.4">${userGlyph}</g>`,
);
label(80, 312, ['Café customer', 'web browser', '(invented test accounts)']);
add(
  `<g transform="translate(50,790)" fill="none" stroke="${C.ink}" stroke-width="2.4" stroke-linejoin="round"><rect x="4" y="10" width="52" height="36" rx="3"/><path d="M4 12l26 20 26-20"/></g>`,
);
label(80, 860, ['Team inbox', 'alarm + budget e-mails']);
generic(
  1450,
  170,
  190,
  120,
  ['Google Gemini API', 'External AI model', 'gemini-3.5-flash-lite · outside AWS'],
  '<path d="M28 6c2 12 8 18 22 22-14 4-20 10-22 22-2-12-8-18-22-22 14-4 20-10 22-22z"/>',
);
generic(
  1450,
  470,
  190,
  130,
  ['GitHub', 'repo + Actions (CI/CD)', 'OIDC role, no AWS keys', 'build on push to main'],
  '<path d="M20 18L8 28l12 10M36 18l12 10-12 10M31 12l-6 32"/>',
);

// ------------------------------------------------------------------ AWS Cloud
group(160, 20, 1270, 950, {
  color: C.ink,
  title: 'AWS Cloud',
  tag: C.ink,
  tagGlyph:
    '<path d="M10 40c18 10 40 8 52 0M52 36l10 4-4 9"/><text x="36" y="30" font-size="26" fill="#fff" stroke="none" font-family="Arial" font-weight="bold" text-anchor="middle">aws</text>',
  textColor: C.ink,
});

// global services (outside the Region)
icon(212, 218, C.network, 'cloudfront', [
  'Amazon CloudFront',
  'HTTPS (*.cloudfront.net)',
  'caching off for chat',
]);
icon(212, 520, C.security, 'iam', ['AWS IAM', 'user per person + MFA', 'MFA-only admin role']);
icon(212, 690, C.cost, 'budgets', ['AWS Budgets', 'monthly cost alert']);
note(240, 470, 'global services', 'middle');

// Region
group(330, 60, 1080, 890, {
  color: '#00A4A6',
  title: 'Region: ap-southeast-2 (Sydney)',
  dash: true,
  tag: '#00A4A6',
  tagGlyph: '<path d="M14 54V8M14 10h30l-6 9 6 9H14"/>',
});

// VPC / AZ / subnet / SG / instance
group(355, 100, 470, 470, {
  color: C.network,
  title: 'VPC 10.20.0.0/16',
  tag: C.network,
  tagGlyph:
    '<rect x="10" y="22" width="44" height="30" rx="4"/><path d="M20 22v-6a12 12 0 0 1 24 0v6"/>',
});
group(370, 140, 440, 418, { color: '#147EBA', title: 'Availability Zone A', dash: true });
group(385, 172, 410, 372, {
  color: C.storage,
  title: 'Public subnet 10.20.1.0/24',
  fill: '#F2F6E8',
  tag: C.storage,
  tagGlyph:
    '<rect x="14" y="26" width="36" height="26" rx="3"/><path d="M22 26v-6a10 10 0 0 1 20 0v6"/>',
});
group(398, 212, 384, 318, {
  color: C.security,
  title: 'Security group: TCP 80 from CloudFront only, no SSH',
});
group(410, 240, 360, 278, {
  color: C.compute,
  title: 'EC2 t3.small · AL2023 · Docker · IMDSv2',
  tag: C.compute,
  tagGlyph: 'ec2',
});
icon(430, 285, C.compute, 'container', ['filmatch-api', 'LibreChat reskin', '“Ask Filmatch”']);
icon(562, 285, C.database, 'mongo', ['MongoDB 8', 'container, no', 'published port']);
icon(694, 285, C.mgmt, 'agent', ['CloudWatch', 'agent', 'mem / disk']);
icon(562, 420, C.network, 'eip', ['Elastic IP']);
icon(694, 420, C.storage, 'ebs', ['Amazon EBS', 'gp3 30 GiB', 'encrypted']);

// content column
group(850, 100, 240, 470, {
  color: C.grey,
  title: 'Content and deployment',
  dash: true,
  textColor: C.ink,
});
icon(942, 142, C.storage, 's3', [
  'S3 content bucket',
  'knowledge docs, config,',
  'deploy bundle · versioned',
]);
icon(942, 292, C.security, 'key', [
  'SSM Parameter Store',
  'SecureString secrets',
  '(Gemini key, JWT)',
]);
icon(942, 442, C.compute, 'ecr', ['Amazon ECR', 'filmatch-app image']);

// backup column
group(1110, 100, 280, 470, {
  color: C.grey,
  title: 'Backup and operations',
  dash: true,
  textColor: C.ink,
});
icon(1222, 142, C.storage, 's3', ['S3 backup bucket', 'nightly mongodump', 'versioned · 14 days']);
icon(1222, 292, C.storage, 'backup', ['AWS Backup', 'daily EBS snapshot', 'kept 7 days']);
icon(1222, 442, C.mgmt, 'ssm', [
  'AWS Systems Manager',
  'Run Command · Session Mgr',
  'State Manager (nightly)',
]);

// monitoring group
group(355, 640, 560, 250, {
  color: C.grey,
  title: 'Monitoring and alerting',
  dash: true,
  textColor: C.ink,
});
icon(430, 690, C.mgmt, 'logs', ['CloudWatch Logs', '/filmatch/app, /mongodb', '30-day retention']);
icon(602, 690, C.mgmt, 'cloudwatch', [
  'Amazon CloudWatch',
  'metric filters, dashboard',
  '10 alarms',
]);
icon(774, 690, C.appint, 'sns', ['Amazon SNS', 'filmatch-alerts', 'e-mail subscription']);

// automation + audit group
group(940, 640, 450, 250, {
  color: C.grey,
  title: 'Automation and audit',
  dash: true,
  textColor: C.ink,
});
icon(985, 690, C.appint, 'eventbridge', ['Amazon EventBridge', 'every 5 minutes']);
icon(1135, 690, C.compute, 'lambda', ['AWS Lambda', 'health check', 'GET /health']);
icon(1285, 690, C.mgmt, 'cloudtrail', ['AWS CloudTrail', 'multi-region trail', 'log validation']);

// ------------------------------------------------------------------ request path (solid)
arrow('M112 264 H208');
badge(160, 248, 1);
arrow('M268 240 H418 V313 H428');
badge(345, 240, 2);
arrow('M488 313 H558', false, true);
badge(523, 296, 3);
arrow('M470 283 V272 H832 V82 H1545 V166', false, true);
badge(1000, 82, 4);
badge(1300, 82, 5);
arrow('M458 398 V686');
badge(458, 600, 6);

// ------------------------------------------------------------------ deploy / operations (dashed)
arrow('M940 190 H844 V300 H772', true); // S3 content -> instance
arrow('M940 320 H772', true); // Parameter Store -> instance
arrow('M940 480 H772', true); // ECR -> instance
note(856, 276, 'pulled at deploy');
arrow('M752 518 V596 H1400 V170 H1280', true); // instance -> backups
note(880, 611, 'nightly mongodump → S3 backup bucket');
arrow('M1250 548 V576 H736 V520', true); // SSM -> instance
arrow('M1448 540 H1422 V622 H1100 V470 H1002', true); // GitHub -> ECR
arrow('M1448 500 H1280', true); // GitHub -> SSM Run Command
note(1455, 620, 'build → ECR, deploy via SSM');
arrow('M722 394 V405 H650 V686', true); // agent -> CloudWatch
arrow('M488 718 H598', true); // logs -> CloudWatch
arrow('M660 718 H770', true); // CloudWatch -> SNS
arrow('M802 802 V920 H80 V880', true); // SNS -> inbox
arrow('M240 770 V800 H112', true); // Budgets -> inbox
arrow('M1043 718 H1131', true); // EventBridge -> Lambda
arrow('M1163 802 V935 H318 V262 H270', true); // Lambda -> CloudFront health check
note(700, 930, 'health check through the public HTTPS URL → HealthCheckOk metric');

// ------------------------------------------------------------------ legend
add(`<rect x="160" y="990" width="1480" height="145" rx="6" fill="#F8F9FA" stroke="#D5DBE1"/>`);
add(
  `<text x="180" y="1015" font-size="13.5" font-weight="bold" fill="${C.ink}">How a question travels</text>`,
);
const steps = [
  'The customer opens the Filmatch URL; CloudFront terminates HTTPS with its default certificate.',
  'CloudFront forwards to the EC2 instance on port 80; the security group admits only CloudFront origin-facing IPs.',
  'The filmatch-api container loads the conversation from MongoDB on the same instance (Docker network only).',
  'It sends the question plus the Ask Filmatch rules and the five café documents (loaded from S3 at deploy) to Gemini over HTTPS.',
  'Gemini streams the answer back; the API saves it in MongoDB and streams it to the browser through CloudFront.',
  'The API writes one JSON log line per answer → CloudWatch Logs → metric filters → alarms → SNS e-mail to the team.',
];
steps.forEach((s, i) => {
  const col = i < 3 ? 0 : 1;
  const row = i % 3;
  const x = 190 + col * 735;
  const y = 1045 + row * 28;
  badge(x, y - 4, i + 1);
  add(`<text x="${x + 20}" y="${y + 1}" font-size="12" fill="${C.ink}">${esc(s)}</text>`);
});
add(
  `<text x="1630" y="1015" font-size="11" fill="#545B64" text-anchor="end">Solid arrows: request path · dashed arrows: deploy and operations path</text>`,
);
add('</svg>');

const file = path.join(__dirname, 'filmatch-aws-architecture.svg');
fs.writeFileSync(file, out.join('\n') + '\n');
console.log('wrote ' + file);
