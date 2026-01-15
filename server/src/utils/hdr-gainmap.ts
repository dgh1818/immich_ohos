const ISO_NAMESPACE = 'urn:iso:std:iso:ts:21496:-1';
const XMP_NAMESPACE = 'http://ns.adobe.com/xap/1.0/';
const CONTAINER_URI = 'http://ns.google.com/photos/1.0/container/';
const ITEM_URI = 'http://ns.google.com/photos/1.0/container/item/';
const GAINMAP_URI = 'http://ns.adobe.com/hdr-gain-map/1.0/';
const GAINMAP_PREFIX = 'hdrgm';

export type LegacyHdrGainmapType = 'huawei-iso' | 'cuva';

export type LegacyGainmapExtraction = {
  type: LegacyHdrGainmapType;
  sdrImage: Buffer;
  gainmapImage: Buffer;
};

type LegacyGainmapOffsets = {
  type: LegacyHdrGainmapType;
  firstStart: number;
  firstEnd: number;
  secondStart: number;
  secondEnd: number;
  thumbnailStart: number;
  thumbnailEnd: number;
  mainImageStart: number;
  mainImageEnd: number;
};

type GainmapMetadata = {
  hasMetadata: boolean;
  baseRenditionIsHdr: boolean;
  gainMapMin: [number, number, number];
  gainMapMax: [number, number, number];
  gainMapGamma: [number, number, number];
  offsetSdr: [number, number, number];
  offsetHdr: [number, number, number];
  hdrCapacityMin: number;
  hdrCapacityMax: number;
};

type IsoGainmapMetadata = {
  version: string;
  maxContentBoost: number;
  minContentBoost: number;
  gamma: number;
  offsetSdr: number;
  offsetHdr: number;
  hdrCapacityMin: number;
  hdrCapacityMax: number;
  useBaseCg: boolean;
};

type GainmapMetadataFraction = {
  gainMapMinN: [number, number, number];
  gainMapMinD: [number, number, number];
  gainMapMaxN: [number, number, number];
  gainMapMaxD: [number, number, number];
  gainMapGammaN: [number, number, number];
  gainMapGammaD: [number, number, number];
  baseOffsetN: [number, number, number];
  baseOffsetD: [number, number, number];
  alternateOffsetN: [number, number, number];
  alternateOffsetD: [number, number, number];
  baseHdrHeadroomN: number;
  baseHdrHeadroomD: number;
  alternateHdrHeadroomN: number;
  alternateHdrHeadroomD: number;
  backwardDirection: boolean;
  useBaseColorSpace: boolean;
};

type Segment = { marker: number; payload: Buffer };

const APP1 = 0xe1;
const APP2 = 0xe2;
const SOI = 0xd8;
const EOI = 0xd9;

const XMP_NAMESPACE_BYTES = Buffer.from(`${XMP_NAMESPACE}\0`, 'ascii');
const ISO_NAMESPACE_BYTES = Buffer.from(`${ISO_NAMESPACE}\0`, 'ascii');

const DEFAULT_METADATA: IsoGainmapMetadata = {
  version: '1.0',
  maxContentBoost: 10,
  minContentBoost: 1,
  gamma: 1,
  offsetSdr: 1 / 64,
  offsetHdr: 1 / 64,
  hdrCapacityMin: 1,
  hdrCapacityMax: 10,
  useBaseCg: true,
};

const K_MPF_SIG = Buffer.from([0x4d, 0x50, 0x46, 0x00]);
const K_MP_LITTLE_ENDIAN = Buffer.from([0x49, 0x49, 0x2a, 0x00]);
const K_TAG_SERIALIZED_COUNT = 3;
const K_TAG_SIZE = 12;
const K_NUM_PICTURES = 2;
const K_MP_ENTRY_SIZE = 16;

const K_TYPE_UNDEFINED = 0x7;
const K_TYPE_LONG = 0x4;
const K_VERSION_TAG = 0xb000;
const K_VERSION_TYPE = K_TYPE_UNDEFINED;
const K_VERSION_COUNT = 4;
const K_VERSION_EXPECTED = Buffer.from([0x30, 0x31, 0x30, 0x30]);
const K_NUMBER_OF_IMAGES_TAG = 0xb001;
const K_NUMBER_OF_IMAGES_TYPE = K_TYPE_LONG;
const K_NUMBER_OF_IMAGES_COUNT = 1;
const K_MP_ENTRY_TAG = 0xb002;
const K_MP_ENTRY_TYPE = K_TYPE_UNDEFINED;
const K_MP_ENTRY_ATTRIBUTE_FORMAT_JPEG = 0x0000000;
const K_MP_ENTRY_ATTRIBUTE_TYPE_PRIMARY = 0x030000;

const K_IS_MULTI_CHANNEL_MASK = 1 << 7;
const K_USE_BASE_COLOR_SPACE_MASK = 1 << 6;

export function extractLegacyGainmap(
  data: Buffer,
  options: { make?: string | null } = {},
): LegacyGainmapExtraction | null {
  const offsets = findLegacyGainmapOffsets(data, options.make);
  if (!offsets) {
    return null;
  }

  const sdrData = data.slice(offsets.firstStart, offsets.firstEnd + 1);
  const gainmapData = data.slice(offsets.secondStart, offsets.secondEnd + 1);

  const sdrImage = reorderLegacySdr(sdrData, offsets);

  return { type: offsets.type, sdrImage, gainmapImage: gainmapData };
}

export function encodeIsoGainmapJpeg(sdrImage: Buffer, gainmapImage: Buffer, metadataSource?: Buffer): Buffer {
  const metadata = resolveGainmapMetadata(metadataSource ?? sdrImage);
  const xmpSecondary = generateXmpForSecondaryImage(metadata);
  const isoSecondaryPayload = encodeGainmapMetadata(gainmapMetadataFloatToFraction(metadata));

  const secondarySegments: Segment[] = [
    {
      marker: APP1,
      payload: Buffer.concat([XMP_NAMESPACE_BYTES, Buffer.from(xmpSecondary, 'utf8')]),
    },
    {
      marker: APP2,
      payload: Buffer.concat([ISO_NAMESPACE_BYTES, isoSecondaryPayload]),
    },
  ];

  const secondaryImageSize = gainmapImage.length + segmentsLength(secondarySegments);
  const xmpPrimary = generateXmpForPrimaryImage(secondaryImageSize, metadata);

  const primarySegments: Segment[] = [
    {
      marker: APP1,
      payload: Buffer.concat([XMP_NAMESPACE_BYTES, Buffer.from(xmpPrimary, 'utf8')]),
    },
    {
      marker: APP2,
      payload: Buffer.concat([ISO_NAMESPACE_BYTES, Buffer.from([0x00, 0x00, 0x00, 0x00])]),
    },
  ];

  const primaryPrefixLength = 2 + segmentsLength(primarySegments);
  const mpfPayloadLength = 2 + calculateMpfSize();
  const primaryImageSize = primaryPrefixLength + mpfPayloadLength + sdrImage.length;
  const secondaryImageOffset = primaryImageSize - primaryPrefixLength - 8;
  const mpfPayload = generateMpf(primaryImageSize, 0, secondaryImageSize, secondaryImageOffset);

  const outputSegments = [
    Buffer.from([0xff, SOI]),
    ...primarySegments.map(buildSegment),
    buildSegment({ marker: APP2, payload: mpfPayload }),
    sdrImage.subarray(2),
    Buffer.from([0xff, SOI]),
    ...secondarySegments.map(buildSegment),
    gainmapImage.subarray(2),
  ];

  return Buffer.concat(outputSegments);
}

function buildSegment(segment: Segment): Buffer {
  const payloadLength = segment.payload.length;
  const length = payloadLength + 2;
  const buffer = Buffer.allocUnsafe(4 + payloadLength);
  buffer[0] = 0xff;
  buffer[1] = segment.marker;
  buffer[2] = (length >> 8) & 0xff;
  buffer[3] = length & 0xff;
  segment.payload.copy(buffer, 4);
  return buffer;
}

function segmentsLength(segments: Segment[]): number {
  return segments.reduce((total, segment) => total + 4 + segment.payload.length, 0);
}
function findLegacyGainmapOffsets(data: Buffer, make?: string | null): LegacyGainmapOffsets | null {
  const len = data.length;
  if (len < 4) {
    return null;
  }

  let firstStart = -1;
  let thumbnailStart = -1;
  for (let i = 0; i < len - 3; i++) {
    if (data[i] === 0xff && data[i + 1] === SOI && data[i + 2] === 0xff && data[i + 3] === 0xe0) {
      firstStart = i;
      thumbnailStart = i + 2;
      break;
    }
  }

  if (firstStart < 0) {
    return null;
  }

  let thumbnailEnd = -1;
  let mainImageStart = -1;
  for (let i = firstStart + 5; i < len - 1; i++) {
    if (data[i] === 0xff && data[i + 1] === 0xe0) {
      thumbnailEnd = i - 1;
      mainImageStart = i;
      break;
    }
  }

  let type: LegacyHdrGainmapType | null = null;
  let secondStart = -1;
  let firstEnd = -1;
  let mainImageEnd = -1;

  for (let i = firstStart; i < len - 3; i++) {
    if (data[i] === 0xff && data[i + 1] === SOI && data[i + 2] === 0xff && data[i + 3] === 0xe2) {
      mainImageEnd = i - 3;
      firstEnd = i - 1;
      secondStart = i;
      type = 'huawei-iso';
      break;
    }
  }

  if (secondStart === -1) {
    for (let i = firstStart + 1; i < len - 3; i++) {
      if (data[i] === 0xff && data[i + 1] === SOI && data[i + 2] === 0xff && data[i + 3] === 0xe5) {
        secondStart = i;
        break;
      }
    }

    if (secondStart !== -1) {
      mainImageEnd = secondStart - 3;
      firstEnd = secondStart - 1;
      type = 'cuva';
    }
  }

  if (secondStart === -1 || type === null) {
    return null;
  }

  let secondEnd = -1;
  for (let i = secondStart; i < len - 1; i++) {
    if (data[i] === 0xff && data[i + 1] === EOI) {
      secondEnd = i + 1;
      break;
    }
  }

  if (firstEnd < 0 || secondEnd < 0) {
    return null;
  }

  return {
    type,
    firstStart,
    firstEnd,
    secondStart,
    secondEnd,
    thumbnailStart,
    thumbnailEnd,
    mainImageStart,
    mainImageEnd,
  };
}

function reorderLegacySdr(sdrData: Buffer, offsets: LegacyGainmapOffsets): Buffer {
  const output = Buffer.from(sdrData);
  const thumbStart = offsets.thumbnailStart - offsets.firstStart;
  const thumbEnd = offsets.thumbnailEnd - offsets.firstStart;
  const mainStart = offsets.mainImageStart - offsets.firstStart;
  const mainEnd = offsets.mainImageEnd - offsets.firstStart;
  const jfif = Buffer.from('JFIF\0', 'ascii');

  const secondSoi = sdrData.indexOf(Buffer.from([0xff, 0xd8]), Math.max(2, thumbStart));
  const thumbEoi = sdrData.indexOf(Buffer.from([0xff, 0xd9]), Math.max(2, thumbStart));
  const mainLooksLikeJfif =
    mainStart >= 0 &&
    mainStart + 9 <= sdrData.length &&
    sdrData[mainStart] === 0xff &&
    sdrData[mainStart + 1] === 0xe0 &&
    sdrData.subarray(mainStart + 4, mainStart + 9).equals(jfif);
  const shouldReorder =
    thumbStart >= 0 &&
    mainStart >= 0 &&
    thumbEnd >= thumbStart &&
    mainEnd >= mainStart &&
    mainEnd < sdrData.length &&
    ((secondSoi !== -1 && secondSoi < mainStart) || (thumbEoi !== -1 && thumbEoi < mainStart && mainLooksLikeJfif));

  if (shouldReorder) {
    const mainLen = mainEnd - mainStart + 1;
    sdrData.copy(output, thumbStart, mainStart, mainEnd + 1);
    sdrData.copy(output, thumbStart + mainLen, thumbStart, thumbEnd + 1);
  }

  scrubCuvaMarker(output);

  return output;
}

function scrubCuvaMarker(data: Buffer) {
  const marker = Buffer.from('_cuva', 'ascii');
  let index = 0;
  while (true) {
    const found = data.indexOf(marker, index);
    if (found === -1) {
      break;
    }
    data.fill(0, found, found + marker.length);
    index = found + marker.length;
  }
}

function isHuaweiMake(make?: string | null): boolean {
  if (!make) {
    return false;
  }
  return make.toLowerCase().includes('huawei');
}
function resolveGainmapMetadata(data: Buffer): IsoGainmapMetadata {
  const parsed = parseGainmapMetadata(data);
  if (!parsed.hasMetadata) {
    return DEFAULT_METADATA;
  }

  const maxContentBoost = safePositive(Math.pow(2, parsed.gainMapMax[0]), DEFAULT_METADATA.maxContentBoost);
  const minContentBoost = safePositive(Math.pow(2, parsed.gainMapMin[0]), DEFAULT_METADATA.minContentBoost);
  const hdrCapacityMin = safePositive(Math.pow(2, parsed.hdrCapacityMin), DEFAULT_METADATA.hdrCapacityMin);
  const hdrCapacityMax = safePositive(Math.pow(2, parsed.hdrCapacityMax), DEFAULT_METADATA.hdrCapacityMax);

  const gamma = safePositive(parsed.gainMapGamma[0], DEFAULT_METADATA.gamma);
  const offsetSdr = safeNumber(parsed.offsetSdr[0], DEFAULT_METADATA.offsetSdr);
  const offsetHdr = safeNumber(parsed.offsetHdr[0], DEFAULT_METADATA.offsetHdr);

  const finalMin = minContentBoost > maxContentBoost ? maxContentBoost : minContentBoost;
  const finalMax = minContentBoost > maxContentBoost ? minContentBoost : maxContentBoost;
  const finalHdrMin = hdrCapacityMin > hdrCapacityMax ? hdrCapacityMax : hdrCapacityMin;
  const finalHdrMax = hdrCapacityMin > hdrCapacityMax ? hdrCapacityMin : hdrCapacityMax;

  return {
    version: DEFAULT_METADATA.version,
    maxContentBoost: finalMax,
    minContentBoost: finalMin,
    gamma,
    offsetSdr,
    offsetHdr,
    hdrCapacityMin: finalHdrMin,
    hdrCapacityMax: finalHdrMax,
    useBaseCg: true,
  };
}

function safePositive(value: number, fallback: number): number {
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

function safeNumber(value: number, fallback: number): number {
  return Number.isFinite(value) ? value : fallback;
}

function parseGainmapMetadata(data: Buffer): GainmapMetadata {
  const headroom = parseHeadroomValue(data) ?? 4;
  const metadata: GainmapMetadata = {
    hasMetadata: false,
    baseRenditionIsHdr: false,
    gainMapMin: [0, 0, 0],
    gainMapMax: [headroom, headroom, headroom],
    gainMapGamma: [1, 1, 1],
    offsetSdr: [0, 0, 0],
    offsetHdr: [0, 0, 0],
    hdrCapacityMin: 0,
    hdrCapacityMax: headroom,
  };

  let found = false;

  if (tryParseFloatAttributeList(data, `${GAINMAP_PREFIX}:GainMapMin`, metadata.gainMapMin)) found = true;
  else if (tryParseFloatAttributeList(data, 'GainMapMin', metadata.gainMapMin)) found = true;

  if (tryParseFloatAttributeList(data, `${GAINMAP_PREFIX}:GainMapMax`, metadata.gainMapMax)) found = true;
  else if (tryParseFloatAttributeList(data, 'GainMapMax', metadata.gainMapMax)) found = true;

  if (tryParseFloatAttributeList(data, `${GAINMAP_PREFIX}:Gamma`, metadata.gainMapGamma)) found = true;
  else if (tryParseFloatAttributeList(data, 'Gamma', metadata.gainMapGamma)) found = true;

  if (tryParseFloatAttributeList(data, `${GAINMAP_PREFIX}:OffsetSDR`, metadata.offsetSdr)) found = true;
  else if (tryParseFloatAttributeList(data, 'OffsetSDR', metadata.offsetSdr)) found = true;

  if (tryParseFloatAttributeList(data, `${GAINMAP_PREFIX}:OffsetHDR`, metadata.offsetHdr)) found = true;
  else if (tryParseFloatAttributeList(data, 'OffsetHDR', metadata.offsetHdr)) found = true;

  if (tryParseFloatAttributeValue(data, `${GAINMAP_PREFIX}:HDRCapacityMin`, (value) => (metadata.hdrCapacityMin = value)))
    found = true;
  else if (tryParseFloatAttributeValue(data, 'HDRCapacityMin', (value) => (metadata.hdrCapacityMin = value)))
    found = true;

  if (tryParseFloatAttributeValue(data, `${GAINMAP_PREFIX}:HDRCapacityMax`, (value) => (metadata.hdrCapacityMax = value)))
    found = true;
  else if (tryParseFloatAttributeValue(data, 'HDRCapacityMax', (value) => (metadata.hdrCapacityMax = value)))
    found = true;

  if (
    tryParseBoolAttributeValue(data, `${GAINMAP_PREFIX}:BaseRenditionIsHDR`, (value) => (metadata.baseRenditionIsHdr = value))
  ) {
    found = true;
  } else if (tryParseBoolAttributeValue(data, 'BaseRenditionIsHDR', (value) => (metadata.baseRenditionIsHdr = value))) {
    found = true;
  }

  metadata.hasMetadata = found;
  return metadata;
}

function parseHeadroomValue(data: Buffer): number | null {
  const value =
    parseAttributeAsNumber(data, 'HDRGainMapHeadroom') ??
    parseAttributeAsNumber(data, `${GAINMAP_PREFIX}:HDRCapacityMax`) ??
    parseAttributeAsNumber(data, 'HDRCapacityMax');
  if (value !== null && value > 0) {
    return value;
  }
  return null;
}

function parseAttributeAsNumber(data: Buffer, key: string): number | null {
  const value = findAttributeValue(data, key);
  if (!value) {
    return null;
  }
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function tryParseFloatAttributeValue(data: Buffer, key: string, onValue: (value: number) => void): boolean {
  const value = parseAttributeAsNumber(data, key);
  if (value === null) {
    return false;
  }
  onValue(value);
  return true;
}

function tryParseBoolAttributeValue(data: Buffer, key: string, onValue: (value: boolean) => void): boolean {
  const value = findAttributeValue(data, key);
  if (!value) {
    return false;
  }
  if (value.toLowerCase() === 'true') {
    onValue(true);
    return true;
  }
  if (value.toLowerCase() === 'false') {
    onValue(false);
    return true;
  }
  return false;
}

function tryParseFloatAttributeList(data: Buffer, key: string, outValues: [number, number, number]): boolean {
  const value = findAttributeValue(data, key);
  if (!value) {
    return false;
  }
  const parsed = parseFloatList(value);
  if (parsed.length === 0) {
    return false;
  }
  if (parsed.length === 1) {
    outValues[0] = parsed[0];
    outValues[1] = parsed[0];
    outValues[2] = parsed[0];
  } else if (parsed.length === 2) {
    outValues[0] = parsed[0];
    outValues[1] = parsed[1];
    outValues[2] = parsed[1];
  } else {
    outValues[0] = parsed[0];
    outValues[1] = parsed[1];
    outValues[2] = parsed[2];
  }
  return true;
}

function parseFloatList(value: string): number[] {
  const parts = value
    .split(/[\s,]+/u)
    .map((part) => part.trim())
    .filter(Boolean);
  const results: number[] = [];
  for (const part of parts) {
    const parsed = Number.parseFloat(part);
    if (!Number.isFinite(parsed)) {
      continue;
    }
    results.push(parsed);
  }
  return results;
}

function findAttributeValue(data: Buffer, key: string): string | null {
  const keyBytes = Buffer.from(key, 'ascii');
  let offset = 0;
  while (true) {
    const index = data.indexOf(keyBytes, offset);
    if (index === -1) {
      return null;
    }
    let pos = index + keyBytes.length;
    while (pos < data.length && isAsciiSpace(data[pos])) {
      pos++;
    }
    if (pos >= data.length || data[pos] !== 0x3d) {
      offset = index + 1;
      continue;
    }
    pos++;
    while (pos < data.length && isAsciiSpace(data[pos])) {
      pos++;
    }
    if (pos >= data.length || (data[pos] !== 0x22 && data[pos] !== 0x27)) {
      offset = index + 1;
      continue;
    }
    const quote = data[pos];
    pos++;
    const start = pos;
    while (pos < data.length && data[pos] !== quote) {
      pos++;
    }
    if (pos <= start) {
      offset = index + 1;
      continue;
    }
    return data.slice(start, pos).toString('ascii');
  }
}

function isAsciiSpace(value: number): boolean {
  return value === 0x20 || value === 0x09 || value === 0x0d || value === 0x0a;
}
function generateXmpForPrimaryImage(secondaryImageLength: number, metadata: IsoGainmapMetadata): string {
  return [
    '<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.2">',
    '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">',
    `<rdf:Description xmlns:Container="${CONTAINER_URI}" xmlns:Item="${ITEM_URI}" xmlns:${GAINMAP_PREFIX}="${GAINMAP_URI}" ${GAINMAP_PREFIX}:Version="${metadata.version}">`,
    '<Container:Directory>',
    '<rdf:Seq>',
    '<rdf:li rdf:parseType="Resource"><Item:Item Item:Semantic="Primary" Item:Mime="image/jpeg"/></rdf:li>',
    `<rdf:li rdf:parseType="Resource"><Item:Item Item:Semantic="GainMap" Item:Mime="image/jpeg" Item:Length="${secondaryImageLength}"/></rdf:li>`,
    '</rdf:Seq>',
    '</Container:Directory>',
    '</rdf:Description>',
    '</rdf:RDF>',
    '</x:xmpmeta>',
  ].join('');
}

function generateXmpForSecondaryImage(metadata: IsoGainmapMetadata): string {
  const gainMapMin = Math.log2(metadata.minContentBoost);
  const gainMapMax = Math.log2(metadata.maxContentBoost);
  const hdrCapacityMin = Math.log2(metadata.hdrCapacityMin);
  const hdrCapacityMax = Math.log2(metadata.hdrCapacityMax);

  return [
    '<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.2">',
    '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">',
    `<rdf:Description xmlns:${GAINMAP_PREFIX}="${GAINMAP_URI}" ${GAINMAP_PREFIX}:Version="${metadata.version}"`,
    ` ${GAINMAP_PREFIX}:GainMapMin="${gainMapMin}"`,
    ` ${GAINMAP_PREFIX}:GainMapMax="${gainMapMax}"`,
    ` ${GAINMAP_PREFIX}:Gamma="${metadata.gamma}"`,
    ` ${GAINMAP_PREFIX}:OffsetSDR="${metadata.offsetSdr}"`,
    ` ${GAINMAP_PREFIX}:OffsetHDR="${metadata.offsetHdr}"`,
    ` ${GAINMAP_PREFIX}:HDRCapacityMin="${hdrCapacityMin}"`,
    ` ${GAINMAP_PREFIX}:HDRCapacityMax="${hdrCapacityMax}"`,
    ` ${GAINMAP_PREFIX}:BaseRenditionIsHDR="False"/>`,
    '</rdf:RDF>',
    '</x:xmpmeta>',
  ].join('');
}

function gainmapMetadataFloatToFraction(metadata: IsoGainmapMetadata): GainmapMetadataFraction {
  const isSingleChannel = true;
  const fraction: GainmapMetadataFraction = {
    gainMapMinN: [0, 0, 0],
    gainMapMinD: [0, 0, 0],
    gainMapMaxN: [0, 0, 0],
    gainMapMaxD: [0, 0, 0],
    gainMapGammaN: [0, 0, 0],
    gainMapGammaD: [0, 0, 0],
    baseOffsetN: [0, 0, 0],
    baseOffsetD: [0, 0, 0],
    alternateOffsetN: [0, 0, 0],
    alternateOffsetD: [0, 0, 0],
    baseHdrHeadroomN: 0,
    baseHdrHeadroomD: 0,
    alternateHdrHeadroomN: 0,
    alternateHdrHeadroomD: 0,
    backwardDirection: false,
    useBaseColorSpace: metadata.useBaseCg,
  };

  const maxBoost = Math.log2(metadata.maxContentBoost);
  const minBoost = Math.log2(metadata.minContentBoost);
  const hdrCapacityMin = Math.log2(metadata.hdrCapacityMin);
  const hdrCapacityMax = Math.log2(metadata.hdrCapacityMax);

  for (let i = 0; i < (isSingleChannel ? 1 : 3); i++) {
    const maxFraction = floatToSignedFraction(maxBoost);
    fraction.gainMapMaxN[i] = maxFraction.numerator;
    fraction.gainMapMaxD[i] = maxFraction.denominator;

    const minFraction = floatToSignedFraction(minBoost);
    fraction.gainMapMinN[i] = minFraction.numerator;
    fraction.gainMapMinD[i] = minFraction.denominator;

    const gammaFraction = floatToUnsignedFraction(metadata.gamma);
    fraction.gainMapGammaN[i] = gammaFraction.numerator;
    fraction.gainMapGammaD[i] = gammaFraction.denominator;

    const baseOffsetFraction = floatToSignedFraction(metadata.offsetSdr);
    fraction.baseOffsetN[i] = baseOffsetFraction.numerator;
    fraction.baseOffsetD[i] = baseOffsetFraction.denominator;

    const altOffsetFraction = floatToSignedFraction(metadata.offsetHdr);
    fraction.alternateOffsetN[i] = altOffsetFraction.numerator;
    fraction.alternateOffsetD[i] = altOffsetFraction.denominator;
  }

  if (isSingleChannel) {
    for (let i = 1; i < 3; i++) {
      fraction.gainMapMaxN[i] = fraction.gainMapMaxN[0];
      fraction.gainMapMaxD[i] = fraction.gainMapMaxD[0];
      fraction.gainMapMinN[i] = fraction.gainMapMinN[0];
      fraction.gainMapMinD[i] = fraction.gainMapMinD[0];
      fraction.gainMapGammaN[i] = fraction.gainMapGammaN[0];
      fraction.gainMapGammaD[i] = fraction.gainMapGammaD[0];
      fraction.baseOffsetN[i] = fraction.baseOffsetN[0];
      fraction.baseOffsetD[i] = fraction.baseOffsetD[0];
      fraction.alternateOffsetN[i] = fraction.alternateOffsetN[0];
      fraction.alternateOffsetD[i] = fraction.alternateOffsetD[0];
    }
  }

  const baseHdr = floatToUnsignedFraction(hdrCapacityMin);
  fraction.baseHdrHeadroomN = baseHdr.numerator;
  fraction.baseHdrHeadroomD = baseHdr.denominator;

  const altHdr = floatToUnsignedFraction(hdrCapacityMax);
  fraction.alternateHdrHeadroomN = altHdr.numerator;
  fraction.alternateHdrHeadroomD = altHdr.denominator;

  return fraction;
}

function floatToSignedFraction(value: number): { numerator: number; denominator: number } {
  const unsigned = floatToUnsignedFractionImpl(Math.abs(value), 0x7fffffff);
  return { numerator: value < 0 ? -unsigned.numerator : unsigned.numerator, denominator: unsigned.denominator };
}

function floatToUnsignedFraction(value: number): { numerator: number; denominator: number } {
  return floatToUnsignedFractionImpl(value, 0xffffffff);
}

function floatToUnsignedFractionImpl(value: number, maxNumerator: number): { numerator: number; denominator: number } {
  if (!Number.isFinite(value) || value < 0 || value > maxNumerator) {
    return { numerator: 0, denominator: 1 };
  }

  const maxD = value <= 1 ? 0xffffffff : Math.floor(maxNumerator / value);
  let denominator = 1;
  let previousD = 0;
  let currentV = value - Math.floor(value);
  const maxIter = 39;

  for (let iter = 0; iter < maxIter; iter++) {
    const numeratorDouble = denominator * value;
    if (numeratorDouble > maxNumerator) {
      break;
    }
    const numeratorRounded = Math.round(numeratorDouble);
    if (Math.abs(numeratorDouble - numeratorRounded) === 0) {
      return { numerator: numeratorRounded, denominator };
    }
    currentV = 1 / currentV;
    const newD = previousD + Math.floor(currentV) * denominator;
    if (newD > maxD) {
      return { numerator: numeratorRounded, denominator };
    }
    previousD = denominator;
    if (newD > 0xffffffff) {
      break;
    }
    denominator = newD;
    currentV -= Math.floor(currentV);
  }

  return { numerator: Math.round(denominator * value), denominator };
}

function encodeGainmapMetadata(metadata: GainmapMetadataFraction): Buffer {
  const data: number[] = [];

  streamWriteU16(data, 0);
  streamWriteU16(data, 0);

  let flags = 0;
  const channelCount = isAllChannelsIdentical(metadata) ? 1 : 3;
  if (channelCount === 3) {
    flags |= K_IS_MULTI_CHANNEL_MASK;
  }
  if (metadata.useBaseColorSpace) {
    flags |= K_USE_BASE_COLOR_SPACE_MASK;
  }
  if (metadata.backwardDirection) {
    flags |= 4;
  }

  const denom = metadata.baseHdrHeadroomD;
  let useCommonDenominator =
    metadata.baseHdrHeadroomD === denom && metadata.alternateHdrHeadroomD === denom;
  for (let c = 0; c < channelCount; c++) {
    if (
      metadata.gainMapMinD[c] !== denom ||
      metadata.gainMapMaxD[c] !== denom ||
      metadata.gainMapGammaD[c] !== denom ||
      metadata.baseOffsetD[c] !== denom ||
      metadata.alternateOffsetD[c] !== denom
    ) {
      useCommonDenominator = false;
      break;
    }
  }
  if (useCommonDenominator) {
    flags |= 8;
  }

  streamWriteU8(data, flags);

  if (useCommonDenominator) {
    streamWriteU32(data, denom);
    streamWriteU32(data, metadata.baseHdrHeadroomN);
    streamWriteU32(data, metadata.alternateHdrHeadroomN);
    for (let c = 0; c < channelCount; c++) {
      streamWriteS32(data, metadata.gainMapMinN[c]);
      streamWriteS32(data, metadata.gainMapMaxN[c]);
      streamWriteU32(data, metadata.gainMapGammaN[c]);
      streamWriteS32(data, metadata.baseOffsetN[c]);
      streamWriteS32(data, metadata.alternateOffsetN[c]);
    }
  } else {
    streamWriteU32(data, metadata.baseHdrHeadroomN);
    streamWriteU32(data, metadata.baseHdrHeadroomD);
    streamWriteU32(data, metadata.alternateHdrHeadroomN);
    streamWriteU32(data, metadata.alternateHdrHeadroomD);
    for (let c = 0; c < channelCount; c++) {
      streamWriteS32(data, metadata.gainMapMinN[c]);
      streamWriteU32(data, metadata.gainMapMinD[c]);
      streamWriteS32(data, metadata.gainMapMaxN[c]);
      streamWriteU32(data, metadata.gainMapMaxD[c]);
      streamWriteU32(data, metadata.gainMapGammaN[c]);
      streamWriteU32(data, metadata.gainMapGammaD[c]);
      streamWriteS32(data, metadata.baseOffsetN[c]);
      streamWriteU32(data, metadata.baseOffsetD[c]);
      streamWriteS32(data, metadata.alternateOffsetN[c]);
      streamWriteU32(data, metadata.alternateOffsetD[c]);
    }
  }

  return Buffer.from(data);
}

function streamWriteU8(target: number[], value: number) {
  target.push(value & 0xff);
}

function streamWriteU16(target: number[], value: number) {
  target.push((value >> 8) & 0xff, value & 0xff);
}

function streamWriteU32(target: number[], value: number) {
  target.push((value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff);
}

function streamWriteS32(target: number[], value: number) {
  target.push((value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff);
}

function isAllChannelsIdentical(metadata: GainmapMetadataFraction): boolean {
  return (
    metadata.gainMapMinN[0] === metadata.gainMapMinN[1] &&
    metadata.gainMapMinN[0] === metadata.gainMapMinN[2] &&
    metadata.gainMapMinD[0] === metadata.gainMapMinD[1] &&
    metadata.gainMapMinD[0] === metadata.gainMapMinD[2] &&
    metadata.gainMapMaxN[0] === metadata.gainMapMaxN[1] &&
    metadata.gainMapMaxN[0] === metadata.gainMapMaxN[2] &&
    metadata.gainMapMaxD[0] === metadata.gainMapMaxD[1] &&
    metadata.gainMapMaxD[0] === metadata.gainMapMaxD[2] &&
    metadata.gainMapGammaN[0] === metadata.gainMapGammaN[1] &&
    metadata.gainMapGammaN[0] === metadata.gainMapGammaN[2] &&
    metadata.gainMapGammaD[0] === metadata.gainMapGammaD[1] &&
    metadata.gainMapGammaD[0] === metadata.gainMapGammaD[2] &&
    metadata.baseOffsetN[0] === metadata.baseOffsetN[1] &&
    metadata.baseOffsetN[0] === metadata.baseOffsetN[2] &&
    metadata.baseOffsetD[0] === metadata.baseOffsetD[1] &&
    metadata.baseOffsetD[0] === metadata.baseOffsetD[2] &&
    metadata.alternateOffsetN[0] === metadata.alternateOffsetN[1] &&
    metadata.alternateOffsetN[0] === metadata.alternateOffsetN[2] &&
    metadata.alternateOffsetD[0] === metadata.alternateOffsetD[1] &&
    metadata.alternateOffsetD[0] === metadata.alternateOffsetD[2]
  );
}

function calculateMpfSize(): number {
  return (
    K_MPF_SIG.length +
    K_MP_LITTLE_ENDIAN.length +
    4 +
    2 +
    K_TAG_SERIALIZED_COUNT * K_TAG_SIZE +
    4 +
    K_NUM_PICTURES * K_MP_ENTRY_SIZE
  );
}

function generateMpf(
  primaryImageSize: number,
  primaryImageOffset: number,
  secondaryImageSize: number,
  secondaryImageOffset: number,
): Buffer {
  const size = calculateMpfSize();
  const buffer = Buffer.alloc(size);
  let offset = 0;

  K_MPF_SIG.copy(buffer, offset);
  offset += K_MPF_SIG.length;
  K_MP_LITTLE_ENDIAN.copy(buffer, offset);
  offset += K_MP_LITTLE_ENDIAN.length;

  const indexIfdOffset = K_MP_LITTLE_ENDIAN.length + K_MPF_SIG.length;
  buffer.writeUInt32LE(indexIfdOffset, offset);
  offset += 4;

  buffer.writeUInt16LE(K_TAG_SERIALIZED_COUNT, offset);
  offset += 2;

  buffer.writeUInt16LE(K_VERSION_TAG, offset);
  offset += 2;
  buffer.writeUInt16LE(K_VERSION_TYPE, offset);
  offset += 2;
  buffer.writeUInt32LE(K_VERSION_COUNT, offset);
  offset += 4;
  K_VERSION_EXPECTED.copy(buffer, offset);
  offset += K_VERSION_EXPECTED.length;

  buffer.writeUInt16LE(K_NUMBER_OF_IMAGES_TAG, offset);
  offset += 2;
  buffer.writeUInt16LE(K_NUMBER_OF_IMAGES_TYPE, offset);
  offset += 2;
  buffer.writeUInt32LE(K_NUMBER_OF_IMAGES_COUNT, offset);
  offset += 4;
  buffer.writeUInt32LE(K_NUM_PICTURES, offset);
  offset += 4;

  buffer.writeUInt16LE(K_MP_ENTRY_TAG, offset);
  offset += 2;
  buffer.writeUInt16LE(K_MP_ENTRY_TYPE, offset);
  offset += 2;
  buffer.writeUInt32LE(K_MP_ENTRY_SIZE * K_NUM_PICTURES, offset);
  offset += 4;

  const mpEntryOffset = offset - K_MPF_SIG.length + 4 + 4;
  buffer.writeUInt32LE(mpEntryOffset, offset);
  offset += 4;

  buffer.writeUInt32LE(0, offset);
  offset += 4;

  buffer.writeUInt32LE(K_MP_ENTRY_ATTRIBUTE_FORMAT_JPEG | K_MP_ENTRY_ATTRIBUTE_TYPE_PRIMARY, offset);
  offset += 4;
  buffer.writeUInt32LE(primaryImageSize, offset);
  offset += 4;
  buffer.writeUInt32LE(primaryImageOffset, offset);
  offset += 4;
  buffer.writeUInt16LE(0, offset);
  offset += 2;
  buffer.writeUInt16LE(0, offset);
  offset += 2;

  buffer.writeUInt32LE(K_MP_ENTRY_ATTRIBUTE_FORMAT_JPEG, offset);
  offset += 4;
  buffer.writeUInt32LE(secondaryImageSize, offset);
  offset += 4;
  buffer.writeUInt32LE(secondaryImageOffset, offset);
  offset += 4;
  buffer.writeUInt16LE(0, offset);
  offset += 2;
  buffer.writeUInt16LE(0, offset);
  offset += 2;

  return buffer;
}
