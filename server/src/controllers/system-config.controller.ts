import { Body, Controller, Delete, Get, Post, Put } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Endpoint, HistoryBuilder } from 'src/decorators';
import { SystemConfigDto, SystemConfigTemplateStorageOptionDto } from 'src/dtos/system-config.dto';
import { ApiTag, Permission } from 'src/enum';
import { Authenticated } from 'src/middleware/auth.guard';
import { StorageTemplateService } from 'src/services/storage-template.service';
import { SystemConfigService } from 'src/services/system-config.service';
import { StorageTemplateMigrationState } from 'src/types';

@ApiTags(ApiTag.SystemConfig)
@Controller('system-config')
export class SystemConfigController {
  constructor(
    private service: SystemConfigService,
    private storageTemplateService: StorageTemplateService,
  ) {}

  @Get()
  @Authenticated({ permission: Permission.SystemConfigRead, admin: true })
  @Endpoint({
    summary: 'Get system configuration',
    description: 'Retrieve the current system configuration.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  getConfig(): Promise<SystemConfigDto> {
    return this.service.getSystemConfig();
  }

  @Get('defaults')
  @Authenticated({ permission: Permission.SystemConfigRead, admin: true })
  @Endpoint({
    summary: 'Get system configuration defaults',
    description: 'Retrieve the default values for the system configuration.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  getConfigDefaults(): SystemConfigDto {
    return this.service.getDefaults();
  }

  @Put()
  @Authenticated({ permission: Permission.SystemConfigUpdate, admin: true })
  @Endpoint({
    summary: 'Update system configuration',
    description: 'Update the system configuration with a new system configuration.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  updateConfig(@Body() dto: SystemConfigDto): Promise<SystemConfigDto> {
    return this.service.updateSystemConfig(dto);
  }

  @Get('storage-template-options')
  @Authenticated({ permission: Permission.SystemConfigRead, admin: true })
  @Endpoint({
    summary: 'Get storage template options',
    description: 'Retrieve exemplary storage template options.',
    history: new HistoryBuilder().added('v1').beta('v1').stable('v2'),
  })
  getStorageTemplateOptions(): SystemConfigTemplateStorageOptionDto {
    return this.storageTemplateService.getStorageTemplateOptions();
  }

  @Get('storage-template-migration')
  @Authenticated({ permission: Permission.SystemConfigRead, admin: true })
  @Endpoint({
    summary: 'Get storage template migration state',
    description: 'Retrieve the current storage template migration progress and failures.',
    history: new HistoryBuilder().added('v3.0.0'),
  })
  getStorageTemplateMigrationState(): Promise<StorageTemplateMigrationState> {
    return this.storageTemplateService.getStorageTemplateMigrationState();
  }

  @Post('storage-template-migration/retry-failed')
  @Authenticated({ permission: Permission.SystemConfigUpdate, admin: true })
  @Endpoint({
    summary: 'Retry failed storage template migration items',
    description: 'Queue a single-asset storage template migration for every recorded failed item.',
    history: new HistoryBuilder().added('v3.0.0'),
  })
  retryStorageTemplateMigrationFailures(): Promise<StorageTemplateMigrationState> {
    return this.storageTemplateService.retryStorageTemplateMigrationFailures();
  }

  @Delete('storage-template-migration/failures')
  @Authenticated({ permission: Permission.SystemConfigUpdate, admin: true })
  @Endpoint({
    summary: 'Clear storage template migration failures',
    description: 'Clear the recorded storage template migration failure list.',
    history: new HistoryBuilder().added('v3.0.0'),
  })
  clearStorageTemplateMigrationFailures(): Promise<StorageTemplateMigrationState> {
    return this.storageTemplateService.clearStorageTemplateMigrationFailures();
  }
}
