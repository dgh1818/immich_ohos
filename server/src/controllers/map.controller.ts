import {
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Query,
  StreamableFile,
} from '@nestjs/common';
import { ApiOkResponse, ApiParam, ApiTags } from '@nestjs/swagger';
import { Endpoint, HistoryBuilder } from 'src/decorators.js';
import type { AuthDto } from 'src/dtos/auth.dto.js';
import {
  MapMarkerDto,
  MapMarkerResponseDto,
  MapReverseGeocodeDto,
  MapReverseGeocodeResponseDto,
} from 'src/dtos/map.dto.js';
import { ApiTag, Permission } from 'src/enum.js';
import { Auth, Authenticated } from 'src/middleware/auth.guard.js';
import { MapService } from 'src/services/map.service.js';

@ApiTags(ApiTag.Map)
@Controller('map')
export class MapController {
  constructor(private service: MapService) {}

  @Get('petal/tiles/:z/:x/:y')
  @Authenticated({ permission: Permission.MapRead })
  @Header('Cache-Control', 'private, no-store')
  @ApiParam({ name: 'z', schema: { type: 'integer', minimum: 0, maximum: 20 } })
  @ApiParam({ name: 'x', schema: { type: 'integer', minimum: 0 } })
  @ApiParam({ name: 'y', schema: { type: 'integer', minimum: 0 } })
  @ApiOkResponse({ content: { 'image/png': { schema: { type: 'string', format: 'binary' } } } })
  @Endpoint({
    summary: 'Get a Petal Maps tile',
    description:
      'Retrieve a PNG tile when Petal Maps tiles are enabled. Both x and y must be less than 2 to the power of z.',
    history: new HistoryBuilder().added('v3').alpha('v3'),
  })
  async getPetalTile(
    @Param('z', ParseIntPipe) z: number,
    @Param('x', ParseIntPipe) x: number,
    @Param('y', ParseIntPipe) y: number,
  ): Promise<StreamableFile> {
    const tile = await this.service.getPetalTile(z, x, y);
    return new StreamableFile(tile, { type: 'image/png' });
  }

  @Get('markers')
  @Authenticated({ permission: Permission.MapRead })
  @Endpoint({
    summary: 'Retrieve map markers',
    description: 'Retrieve a list of latitude and longitude coordinates for every asset with location data.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  getMapMarkers(@Auth() auth: AuthDto, @Query() options: MapMarkerDto): Promise<MapMarkerResponseDto[]> {
    return this.service.getMapMarkers(auth, options);
  }

  @Get('reverse-geocode')
  @Authenticated({ permission: Permission.MapSearch })
  @HttpCode(HttpStatus.OK)
  @Endpoint({
    summary: 'Reverse geocode coordinates',
    description: 'Retrieve location information (e.g., city, country) for given latitude and longitude coordinates.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  reverseGeocode(@Query() dto: MapReverseGeocodeDto): Promise<MapReverseGeocodeResponseDto[]> {
    return this.service.reverseGeocode(dto);
  }
}
