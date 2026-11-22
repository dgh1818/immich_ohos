import { context } from '@opentelemetry/api';
import { isTracingSuppressed } from '@opentelemetry/core';
import { vitest } from 'vitest';
import { LoggingRepository } from 'src/repositories/logging.repository.js';
import { MapRepository } from 'src/repositories/map.repository.js';

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5i4AAAAASUVORK5CYII=',
  'base64',
);

describe('MapRepository.getPetalTile', () => {
  const logger = LoggingRepository.create();
  const sut = new MapRepository(undefined!, undefined!, logger, undefined!);
  const fetchMock = vitest.fn<typeof fetch>();

  beforeEach(() => {
    fetchMock.mockReset();
    vitest.stubGlobal('fetch', fetchMock);
    vitest.stubEnv('PETALMAP_GEOCODE_KEYS', ' , tile-test/key+, ');
  });

  afterEach(() => {
    vitest.unstubAllGlobals();
    vitest.unstubAllEnvs();
    vitest.restoreAllMocks();
  });

  it('uses the encoded query key only on the official upstream request and suppresses tracing', async () => {
    const withContext = vitest.spyOn(context, 'with');
    fetchMock.mockResolvedValue(new Response(png, { headers: { 'content-type': 'image/png' } }));
    await expect(sut.getPetalTile(2, 1, 3)).resolves.toEqual(png);
    expect(fetchMock).toHaveBeenCalledExactlyOnceWith(
      new URL('https://mapapi.cloud.huawei.com/mapApi/v1/mapService/getTile?x=1&y=3&z=2&key=tile-test%2Fkey%2B'),
      expect.objectContaining({
        headers: { 'Content-Type': 'application/json', Accept: 'image/png' },
        redirect: 'error',
        signal: expect.any(AbortSignal),
      }),
    );
    expect(isTracingSuppressed(withContext.mock.calls[0][0])).toBe(true);
  });

  it('fails without a network request when no key is configured', async () => {
    vitest.stubEnv('PETALMAP_GEOCODE_KEYS', ' , ');
    await expect(sut.getPetalTile(0, 0, 0)).rejects.toMatchObject({ status: 503 });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([
    [302, 'image/png', png, undefined],
    [405, 'application/json', 'REQUEST_DENIED tile-test/key+', undefined],
    [200, 'application/json', png, undefined],
    [200, 'image/png', 'not a PNG', undefined],
    [200, 'image/png', png.subarray(0, -1), undefined],
    [200, 'image/png', png, '1048577'],
    [200, 'image/png', Buffer.alloc(1_048_577), undefined],
  ] as const)('rejects invalid upstream responses (%s, %s)', async (status, type, body, length) => {
    const headers = { 'content-type': type, ...(length && { 'content-length': length }) };
    fetchMock.mockResolvedValue(new Response(body, { status, headers }));
    await expect(sut.getPetalTile(0, 0, 0)).rejects.toMatchObject({
      status: 502,
      message: 'Unable to retrieve Petal Maps tile',
    });
  });

  it('does not expose upstream URLs or keys through errors or logs', async () => {
    const errorLog = vitest.spyOn(logger, 'error');
    const warnLog = vitest.spyOn(logger, 'warn');
    const debugLog = vitest.spyOn(logger, 'debug');
    const upstreamError = new Error(
      'Upstream error at https://mapapi.cloud.huawei.com/?key=tile-test%2Fkey%2B (tile-test/key+)',
    );
    fetchMock.mockRejectedValue(upstreamError);
    const failure = sut.getPetalTile(0, 0, 0);
    await expect(failure).rejects.toMatchObject({
      status: 502,
      message: 'Unable to retrieve Petal Maps tile',
    });
    await expect(failure).rejects.toHaveProperty('cause', undefined);
    const error = await failure.catch((error: unknown) => error);
    expect(JSON.stringify(error)).not.toMatch(/mapapi\.cloud\.huawei\.com|tile-test/i);
    expect(errorLog).not.toHaveBeenCalled();
    expect(warnLog).not.toHaveBeenCalled();
    expect(debugLog).not.toHaveBeenCalled();
  });

  it('uses the same timeout while reading the response body', async () => {
    const controller = new AbortController();
    const timeout = vitest.spyOn(AbortSignal, 'timeout').mockReturnValue(controller.signal);
    const body = new ReadableStream<Uint8Array>({
      pull() {
        controller.abort();
        throw new Error('body read timed out');
      },
    });
    fetchMock.mockResolvedValue(new Response(body, { headers: { 'content-type': 'image/png' } }));
    await expect(sut.getPetalTile(0, 0, 0)).rejects.toMatchObject({ status: 504 });
    expect(timeout).toHaveBeenCalledWith(5000);
  });
});
