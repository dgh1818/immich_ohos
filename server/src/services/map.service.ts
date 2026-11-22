import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { AuthDto } from 'src/dtos/auth.dto.js';
import { MapMarkerDto, MapMarkerResponseDto, MapReverseGeocodeDto } from 'src/dtos/map.dto.js';
import { BaseService } from 'src/services/base.service.js';
import { getMyPartnerIds } from 'src/utils/asset.util.js';

@Injectable()
export class MapService extends BaseService {
  async getPetalTile(z: number, x: number, y: number): Promise<Buffer> {
    const { map } = await this.getConfig({ withCache: true });
    if (!map.enabled || !map.webUsePetalTiles) {
      throw new ForbiddenException('Petal Maps tiles are disabled');
    }

    const isCoordinate = (coordinate: number) =>
      Number.isSafeInteger(coordinate) && coordinate >= 0 && coordinate < 2 ** z;
    if (!Number.isSafeInteger(z) || z < 0 || z > 20 || !isCoordinate(x) || !isCoordinate(y)) {
      throw new BadRequestException('Invalid tile coordinates');
    }
    return this.mapRepository.getPetalTile(z, x, y);
  }

  async getMapMarkers(auth: AuthDto, options: MapMarkerDto): Promise<MapMarkerResponseDto[]> {
    const userIds = [auth.user.id];
    if (options.withPartners) {
      const partnerIds = await getMyPartnerIds({ userId: auth.user.id, repository: this.partnerRepository });
      userIds.push(...partnerIds);
    }

    const albumIds = options.withSharedAlbums ? await this.albumRepository.getAllIds(auth.user.id) : [];

    return this.mapRepository.getMapMarkers(auth.user.id, userIds, albumIds, options);
  }

  async reverseGeocode(dto: MapReverseGeocodeDto) {
    const { lat: latitude, lon: longitude } = dto;
    // eventually this should probably return an array of results
    const result = await this.mapRepository.reverseGeocode({ latitude, longitude });
    return result ? [result] : [];
  }
}
