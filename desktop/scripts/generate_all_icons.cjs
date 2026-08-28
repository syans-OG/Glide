const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

// 1. Paths
const rootDir = path.join(__dirname, '..', '..');
const svgPath = path.join(__dirname, '..', 'public', 'logo_official.svg');
const svgContent = fs.readFileSync(svgPath, 'utf8');

const tauriIconsDir = path.join(__dirname, '..', 'src-tauri', 'icons');
const androidResDir = path.join(rootDir, 'mobile', 'android', 'app', 'src', 'main', 'res');
const mobileAssetsDir = path.join(rootDir, 'mobile', 'assets', 'images');

if (!fs.existsSync(tauriIconsDir)) fs.mkdirSync(tauriIconsDir, { recursive: true });
if (!fs.existsSync(mobileAssetsDir)) fs.mkdirSync(mobileAssetsDir, { recursive: true });

// 2. Render SVG to PNG Buffer at specific dimensions
function renderSvg(width, height) {
  const resvg = new Resvg(svgContent, {
    fitTo: {
      mode: 'width',
      value: width,
    },
  });
  const pngData = resvg.render();
  return pngData.asPng();
}

console.log('🚀 Rendering Glide official logo into all app launcher icon sizes...\n');

// 3. Android Mipmap Icons
const androidSizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

for (const [folder, size] of Object.entries(androidSizes)) {
  const targetDir = path.join(androidResDir, folder);
  if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });

  const pngBuffer = renderSvg(size, size);
  const targetPath = path.join(targetDir, 'ic_launcher.png');
  fs.writeFileSync(targetPath, pngBuffer);
  console.log(`✅ Android: ${folder}/ic_launcher.png (${size}x${size})`);
}

// 4. Desktop Tauri Icons
const tauriSizes = {
  '32x32.png': 32,
  '128x128.png': 128,
  '128x128@2x.png': 256,
  'icon.png': 512,
};

for (const [filename, size] of Object.entries(tauriSizes)) {
  const pngBuffer = renderSvg(size, size);
  const targetPath = path.join(tauriIconsDir, filename);
  fs.writeFileSync(targetPath, pngBuffer);
  console.log(`✅ Tauri: icons/${filename} (${size}x${size})`);
}

// 5. Windows ICO Generator (Multi-image ICO container)
function createIco(images) {
  // Header: 6 bytes
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type 1 = icon
  header.writeUInt16LE(images.length, 4); // number of images

  let offset = 6 + images.length * 16;
  const entries = [];
  const buffers = [];

  for (const img of images) {
    const entry = Buffer.alloc(16);
    entry.writeUInt8(img.width >= 256 ? 0 : img.width, 0);
    entry.writeUInt8(img.height >= 256 ? 0 : img.height, 1);
    entry.writeUInt8(0, 2); // palette
    entry.writeUInt8(0, 3); // reserved
    entry.writeUInt16LE(1, 4); // color planes
    entry.writeUInt16LE(32, 6); // bpp
    entry.writeUInt32LE(img.data.length, 8); // byte size
    entry.writeUInt32LE(offset, 12); // offset

    entries.push(entry);
    buffers.push(img.data);
    offset += img.data.length;
  }

  return Buffer.concat([header, ...entries, ...buffers]);
}

const icoImages = [
  { width: 16, height: 16, data: renderSvg(16, 16) },
  { width: 32, height: 32, data: renderSvg(32, 32) },
  { width: 48, height: 48, data: renderSvg(48, 48) },
  { width: 64, height: 64, data: renderSvg(64, 64) },
  { width: 128, height: 128, data: renderSvg(128, 128) },
  { width: 256, height: 256, data: renderSvg(256, 256) },
];

const icoBuffer = createIco(icoImages);
fs.writeFileSync(path.join(tauriIconsDir, 'icon.ico'), icoBuffer);
fs.writeFileSync(path.join(tauriIconsDir, 'icon.icns'), renderSvg(512, 512));
console.log('✅ Tauri: icons/icon.ico (Multi-res Windows Icon)');

// 6. Mobile Assets & High-res App Icons
fs.writeFileSync(path.join(mobileAssetsDir, 'app_icon.png'), renderSvg(512, 512));
fs.writeFileSync(path.join(__dirname, '..', 'public', 'favicon.png'), renderSvg(64, 64));
console.log('✅ Mobile: assets/images/app_icon.png (512x512)');

console.log('\n🎉 ALL ICONS GENERATED SUCCESSFULLY!');
