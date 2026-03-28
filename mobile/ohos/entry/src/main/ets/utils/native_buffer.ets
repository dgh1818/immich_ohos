import nativeBuffer from 'libnative_buffer.so';

export const INITIAL_BUFFER_SIZE = 32 * 1024;

export interface NativeBufferModule {
  allocate(size: number): number;
  free(ptr: number): void;
  realloc(ptr: number, size: number): number;
  copy(buffer: ArrayBuffer, dest: number, offset: number, length: number): number;
}

const module = nativeBuffer as NativeBufferModule;

export class NativeByteBuffer {
  pointer: number;
  capacity: number;
  offset: number = 0;

  constructor(initialCapacity: number) {
    this.capacity = initialCapacity;
    this.pointer = module.allocate(initialCapacity);
    if (this.pointer === 0) {
      throw new Error(`native byte buffer allocation failed (capacity=${initialCapacity})`);
    }
  }

  ensureHeadroom(requiredBytes: number): void {
    if (requiredBytes <= 0) {
      return;
    }

    const requiredCapacity = this.offset + requiredBytes;
    if (requiredCapacity <= this.capacity) {
      return;
    }

    let nextCapacity = this.capacity;
    while (nextCapacity < requiredCapacity) {
      nextCapacity *= 2;
    }

    const pointer = module.realloc(this.pointer, nextCapacity);
    if (pointer === 0) {
      throw new Error(`native byte buffer reallocation failed (capacity=${nextCapacity})`);
    }
    this.pointer = pointer;
    this.capacity = nextCapacity;
  }

  append(buffer: ArrayBuffer, label: string): void {
    const length = buffer.byteLength;
    if (length <= 0) {
      return;
    }

    this.ensureHeadroom(length);
    const copied = module.copy(buffer, this.pointer, this.offset, length);
    if (copied !== length) {
      throw new Error(`${label} native copy failed`);
    }
    this.offset += length;
  }

  free(): void {
    if (this.pointer === 0) {
      return;
    }
    module.free(this.pointer);
    this.pointer = 0;
    this.capacity = 0;
    this.offset = 0;
  }
}

export default module;
