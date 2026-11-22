import { UnauthorizedException } from '@nestjs/common';
import request from 'supertest';
import { MapController } from 'src/controllers/map.controller.js';
import { Permission } from 'src/enum.js';
import { MapService } from 'src/services/map.service.js';
import { factory } from 'test/small.factory.js';
import { ControllerContext, controllerSetup, mockBaseService } from 'test/utils.js';

describe(MapController.name, () => {
  let ctx: ControllerContext;
  const service = mockBaseService(MapService);

  beforeAll(async () => {
    ctx = await controllerSetup(MapController, [{ provide: MapService, useValue: service }]);
    return () => ctx.close();
  });

  beforeEach(() => {
    service.resetAllMocks();
    ctx.reset();
  });

  describe('GET /map/petal/tiles/:z/:x/:y', () => {
    it('rejects requests without authentication before fetching a tile', async () => {
      ctx.authenticate.mockRejectedValueOnce(new UnauthorizedException());
      const response = await request(ctx.getHttpServer()).get('/map/petal/tiles/0/0/0');
      expect(response.status).toBe(401);
      expect(service.getPetalTile).not.toHaveBeenCalled();
    });

    it('requires map-read authorization and serves a private PNG', async () => {
      service.getPetalTile.mockResolvedValue(Buffer.from('tile'));
      const response = await request(ctx.getHttpServer()).get('/map/petal/tiles/2/1/3');
      expect(response.status).toBe(200);
      expect(response.headers['cache-control']).toBe('private, no-store');
      expect(response.headers['content-type']).toBe('image/png');
      expect(response.body).toEqual(Buffer.from('tile'));
      expect(service.getPetalTile).toHaveBeenCalledWith(2, 1, 3);
      expect(ctx.authenticate).toHaveBeenCalledWith(
        expect.objectContaining({ metadata: expect.objectContaining({ permission: Permission.MapRead }) }),
      );
    });

    it.each(['1.5/0/0', '2/0x1/0', '2/0/1e0'])('rejects non-integer path syntax %s', async (coordinates) => {
      const response = await request(ctx.getHttpServer()).get(`/map/petal/tiles/${coordinates}`);
      expect(response.status).toBe(400);
      expect(service.getPetalTile).not.toHaveBeenCalled();
    });
  });

  describe('GET /map/reverse-geocode', () => {
    it('should require a lat', async () => {
      const { status, body } = await request(ctx.getHttpServer()).get('/map/reverse-geocode').query({ lon: 123 });

      expect(status).toBe(400);
      expect(body).toEqual(
        factory.responses.validationError([{ path: ['lat'], message: 'Invalid input: expected number, received NaN' }]),
      );
      expect(service.reverseGeocode).not.toHaveBeenCalled();
    });

    it('should require a lat that is a number', async () => {
      const { status, body } = await request(ctx.getHttpServer())
        .get('/map/reverse-geocode')
        .query({ lat: 'abc', lon: 123.456 });

      expect(status).toBe(400);
      expect(body).toEqual(
        factory.responses.validationError([{ path: ['lat'], message: 'Invalid input: expected number, received NaN' }]),
      );
      expect(service.reverseGeocode).not.toHaveBeenCalled();
    });

    it('should require a lat that is in range', async () => {
      const { status, body } = await request(ctx.getHttpServer())
        .get('/map/reverse-geocode')
        .query({ lat: 91, lon: 123.456 });

      expect(status).toBe(400);
      expect(body).toEqual(
        factory.responses.validationError([{ path: ['lat'], message: 'Too big: expected number to be <=90' }]),
      );
      expect(service.reverseGeocode).not.toHaveBeenCalled();
    });

    it('should require a lon', async () => {
      const { status, body } = await request(ctx.getHttpServer()).get('/map/reverse-geocode').query({ lat: 75 });

      expect(status).toBe(400);
      expect(body).toEqual(
        factory.responses.validationError([{ path: ['lon'], message: 'Invalid input: expected number, received NaN' }]),
      );
      expect(service.reverseGeocode).not.toHaveBeenCalled();
    });
  });
});
