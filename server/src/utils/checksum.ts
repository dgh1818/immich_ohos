import { createHash } from 'node:crypto';

export const hashSha1 = (value: string | Buffer): Buffer => createHash('sha1').update(value).digest();

export const hashAssetPath = (path: string): Buffer => hashSha1(`path:${path}`);
