const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const iconsDir = path.join(__dirname, '..', 'src-tauri', 'icons');
if (!fs.existsSync(iconsDir)) {
  fs.mkdirSync(iconsDir, { recursive: true });
}

function createPng(width, height) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  const ihdrData = Buffer.alloc(13);
  ihdrData.writeUInt32BE(width, 0);
  ihdrData.writeUInt32BE(height, 4);
  ihdrData[8] = 8; // bit depth
  ihdrData[9] = 6; // color type: RGBA
  ihdrData[10] = 0; // compression
  ihdrData[11] = 0; // filter
  ihdrData[12] = 0; // interlace
  const ihdrChunk = makeChunk('IHDR', ihdrData);

  // Raw image data with scanline filter (0)
  const rowSize = width * 4 + 1;
  const rawData = Buffer.alloc(rowSize * height);
  for (let y = 0; y < height; y++) {
    const rowOffset = y * rowSize;
    rawData[rowOffset] = 0; // filter type None
    for (let x = 0; x < width; x++) {
      const pixelOffset = rowOffset + 1 + x * 4;
      const dx = x - width / 2;
      const dy = y - height / 2;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const isInside = dist <= width * 0.45;

      if (isInside) {
        rawData[pixelOffset] = 0;       // R
        rawData[pixelOffset + 1] = 122; // G
        rawData[pixelOffset + 2] = 255; // B
        rawData[pixelOffset + 3] = 255; // A
      } else {
        rawData[pixelOffset] = 0;
        rawData[pixelOffset + 1] = 0;
        rawData[pixelOffset + 2] = 0;
        rawData[pixelOffset + 3] = 0;
      }
    }
  }

  const compressedData = zlib.deflateSync(rawData);
  const idatChunk = makeChunk('IDAT', compressedData);
  const iendChunk = makeChunk('IEND', Buffer.alloc(0));

  return Buffer.concat([signature, ihdrChunk, idatChunk, iendChunk]);
}

function makeChunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);

  const typeBuffer = Buffer.from(type, 'ascii');
  const crcInput = Buffer.concat([typeBuffer, data]);
  const crc = crc32(crcInput);

  const crcBuffer = Buffer.alloc(4);
  crcBuffer.writeUInt32BE(crc >>> 0, 0);

  return Buffer.concat([length, typeBuffer, data, crcBuffer]);
}

function crc32(buf) {
  let crc = -1;
  for (let i = 0; i < buf.length; i++) {
    crc ^= buf[i];
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return crc ^ -1;
}

// Valid Windows DIB-based or PNG-in-ICO Icon builder
function createBmpIco(width, height) {
  const icoHeader = Buffer.alloc(6);
  icoHeader.writeUInt16LE(0, 0); // reserved
  icoHeader.writeUInt16LE(1, 2); // type 1 = icon
  icoHeader.writeUInt16LE(1, 4); // 1 image

  const bmiHeaderSize = 40;
  const imageBytes = width * height * 4;
  const maskBytes = (width * height) / 8;
  const totalImageSize = bmiHeaderSize + imageBytes + maskBytes;

  const dirEntry = Buffer.alloc(16);
  dirEntry[0] = width;
  dirEntry[1] = height;
  dirEntry[2] = 0; // color palette count
  dirEntry[3] = 0; // reserved
  dirEntry.writeUInt16LE(1, 4);  // color planes
  dirEntry.writeUInt16LE(32, 6); // bpp
  dirEntry.writeUInt32LE(totalImageSize, 8); // image size in bytes
  dirEntry.writeUInt32LE(22, 12); // image offset

  const bmiHeader = Buffer.alloc(bmiHeaderSize);
  bmiHeader.writeUInt32LE(bmiHeaderSize, 0);
  bmiHeader.writeInt32LE(width, 4);
  bmiHeader.writeInt32LE(height * 2, 8); // Double height for XOR + AND masks
  bmiHeader.writeUInt16LE(1, 12);  // planes
  bmiHeader.writeUInt16LE(32, 14); // bpp
  bmiHeader.writeUInt32LE(0, 16);  // compression = BI_RGB
  bmiHeader.writeUInt32LE(imageBytes + maskBytes, 20);

  // BGRA image data (bottom-up)
  const pixelData = Buffer.alloc(imageBytes);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 4;
      const dx = x - width / 2;
      const dy = (height - 1 - y) - height / 2;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist <= width * 0.45) {
        pixelData[idx] = 255;     // B
        pixelData[idx + 1] = 122; // G
        pixelData[idx + 2] = 0;   // R
        pixelData[idx + 3] = 255; // A
      } else {
        pixelData[idx] = 0;
        pixelData[idx + 1] = 0;
        pixelData[idx + 2] = 0;
        pixelData[idx + 3] = 0;
      }
    }
  }

  // 1-bit AND mask (all transparent pixels are 1, opaque 0)
  const andMask = Buffer.alloc(maskBytes, 0);

  return Buffer.concat([icoHeader, dirEntry, bmiHeader, pixelData, andMask]);
}

const png32 = createPng(32, 32);
const png128 = createPng(128, 128);
const png256 = createPng(256, 256);
const png512 = createPng(512, 512);
const ico = createBmpIco(32, 32);

fs.writeFileSync(path.join(iconsDir, '32x32.png'), png32);
fs.writeFileSync(path.join(iconsDir, '128x128.png'), png128);
fs.writeFileSync(path.join(iconsDir, '128x128@2x.png'), png256);
fs.writeFileSync(path.join(iconsDir, 'icon.png'), png512);
fs.writeFileSync(path.join(iconsDir, 'icon.ico'), ico);
fs.writeFileSync(path.join(iconsDir, 'icon.icns'), png512);

console.log('✅ Proper Windows DIB ICO generated!');
