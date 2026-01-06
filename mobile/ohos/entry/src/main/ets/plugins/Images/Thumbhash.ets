// Copyright (c) 2023 Evan Wallace
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
import { collections, lang } from "@kit.ArkTS";

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


export class ThumbHashResult {
  width: number;
  height: number;
  pointer: ArrayBuffer;
  isHdr: boolean;
  stride: number

  constructor(width: number,height: number,pointer: ArrayBuffer,isHdr:boolean,stride:number) {
    this.width = width;
    this.height = height;
    this.pointer = pointer;
    this.isHdr = isHdr;
    this.stride = stride;
  }
}

export function thumbHashToRGBA(hash: Uint8Array): ThumbHashResult {
  // Read the constants (little-endian like your Swift code)
  const h0 = hash[0] >>> 0;
  const h1 = hash[1] >>> 0;
  const h2 = hash[2] >>> 0;
  const h3 = hash[3] >>> 0;
  const h4 = hash[4] >>> 0;

  const header24 = h0 | (h1 << 8) | (h2 << 16);
  const header16 = h3 | (h4 << 8);

  const il_dc = header24 & 63;
  const ip_dc = (header24 >> 6) & 63;
  const iq_dc = (header24 >> 12) & 63;

  let l_dc = il_dc;
  let p_dc = ip_dc;
  let q_dc = iq_dc;

  l_dc = l_dc / 63.0;
  p_dc = p_dc / 31.5 - 1.0;
  q_dc = q_dc / 31.5 - 1.0;

  const il_scale = (header24 >> 18) & 31;
  let l_scale = il_scale / 31.0;

  const hasAlpha = ((header24 >> 23) & 1) !== 0;

  const ip_scale = (header16 >> 3) & 63;
  const iq_scale = (header16 >> 9) & 63;
  let p_scale = ip_scale / 63.0;
  let q_scale = iq_scale / 63.0;

  const isLandscape = ((header16 >> 15) & 1) !== 0;

  const lx16 = Math.max(3, isLandscape ? (hasAlpha ? 5 : 7) : (header16 & 7));
  const ly16 = Math.max(3, isLandscape ? (header16 & 7) : (hasAlpha ? 5 : 7));
  const lx = lx16 | 0;
  const ly = ly16 | 0;

  // alpha base
  let a_dc = 1.0;
  let a_scale = 1.0;
  if (hasAlpha) {
    const ia = hash[5];
    const ia_dc = ia & 15;
    const ia_scale = ia >> 4;
    a_dc = ia_dc / 15.0;
    a_scale = ia_scale / 15.0;
  }

  // Read the varying AC coefficients
  const ac_start = hasAlpha ? 6 : 5;
  let ac_index = 0;

  const decodeChannel = (nx: number, ny: number, scale: number): Float32Array => {
    const ac: number[] = [];
    for (let cy = 0; cy < ny; cy++) {
      let cx = cy > 0 ? 0 : 1;
      while (cx * ny < nx * (ny - cy)) {
        const byte = hash[ac_start + (ac_index >> 1)];
        const shift = ((ac_index & 1) << 2);
        const iac = (byte >> shift) & 15;
        const fac = ((iac / 7.5) - 1.0) * scale;
        ac.push(fac);
        ac_index++;
        cx++;
      }
    }
    return new Float32Array(ac);
  };

  const l_ac = decodeChannel(lx, ly, l_scale);
  const p_ac = decodeChannel(3, 3, p_scale * 1.25);
  const q_ac = decodeChannel(3, 3, q_scale * 1.25);
  const a_ac = hasAlpha ? decodeChannel(5, 5, a_scale) : new Float32Array(0);

  // Decode using DCT into RGB(A)
  const ratio = thumbHashToApproximateAspectRatio(hash);
  const fw = Math.round(ratio > 1 ? 32 : 32 * ratio);
  const fh = Math.round(ratio > 1 ? 32 / ratio : 32);
  const w = fw | 0;
  const h = fh | 0;



  const cx_stop = Math.max(lx, hasAlpha ? 5 : 3);
  const cy_stop = Math.max(ly, hasAlpha ? 5 : 3);

  // pre-allocate coefficient arrays
  const fx = new Float32Array(cx_stop);
  const fy = new Float32Array(cy_stop);
  const buffer = new ArrayBuffer(w * h * 4);
  const out = new Uint8Array(buffer);;


  let outIndex = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let L = l_dc;
      let P = p_dc;
      let Q = q_dc;
      let A = a_dc;

      // Precompute fx for this x and fy for this y
      for (let cx = 0; cx < cx_stop; cx++) {
        const fxx = x;
        fx[cx] = Math.cos(Math.PI / w * (fxx + 0.5) * cx);
      }
      for (let cy = 0; cy < cy_stop; cy++) {
        const fyy = y;
        fy[cy] = Math.cos(Math.PI / h * (fyy + 0.5) * cy);
      }

      // Decode L channel
      let j = 0;
      for (let cy = 0; cy < ly; cy++) {
        let cx = cy > 0 ? 0 : 1;
        const fy2 = fy[cy] * 2.0;
        while (cx * ly < lx * (ly - cy)) {
          L += l_ac[j] * fx[cx] * fy2;
          j++;
          cx++;
        }
      }

      // Decode P and Q (3x3)
      j = 0;
      for (let cy = 0; cy < 3; cy++) {
        let cx = cy > 0 ? 0 : 1;
        const fy2 = fy[cy] * 2.0;
        while (cx < 3 - cy) {
          const f = fx[cx] * fy2;
          P += p_ac[j] * f;
          Q += q_ac[j] * f;
          j++;
          cx++;
        }
      }

      // Decode A if present (5x5)
      if (hasAlpha) {
        j = 0;
        for (let cy = 0; cy < 5; cy++) {
          let cx = cy > 0 ? 0 : 1;
          const fy2 = fy[cy] * 2.0;
          while (cx < 5 - cy) {
            A += a_ac[j] * fx[cx] * fy2;
            j++;
            cx++;
          }
        }
      }

      // Convert to RGB
      let b = L - (2.0 / 3.0) * P;
      let r = (3.0 * L - b + Q) / 2.0;
      let g = r - Q;

      // clamp to [0,255] as original
      const Rc = Math.max(0, 255 * Math.min(1, r));
      const Gc = Math.max(0, 255 * Math.min(1, g));
      const Bc = Math.max(0, 255 * Math.min(1, b));
      const Ac = Math.max(0, 255 * Math.min(1, A));

      out[outIndex++] = (Rc + 0.5) | 0; // rounding
      out[outIndex++] = (Gc + 0.5) | 0;
      out[outIndex++] = (Bc + 0.5) | 0;
      out[outIndex++] = (Ac + 0.5) | 0;
    }
  }

  // let output = new ThumbHashResult({
  //   width: w,
  //   height: h,
  //   pointer: out
  // });

  return new ThumbHashResult(w, h, buffer,false,4 * w);
}

export function thumbHashToApproximateAspectRatio(hash: Uint8Array): number {
  const header = hash[3];
  const hasAlpha = (hash[2] & 0x80) !== 0;
  const isLandscape = (hash[4] & 0x80) !== 0;
  const lx = isLandscape ? (hasAlpha ? 5 : 7) : (header & 7);
  const ly = isLandscape ? (header & 7) : (hasAlpha ? 5 : 7);
  return lx / ly;
}
