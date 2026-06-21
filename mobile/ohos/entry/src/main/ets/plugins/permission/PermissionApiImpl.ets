import { common } from '@kit.AbilityKit';
import abilityAccessCtrl, { PermissionRequestResult, Permissions } from '@ohos.abilityAccessCtrl';
import { PermissionApi, PermissionStatus, Result } from './PermissionApi.g';

const MEDIA_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.MEDIA_LOCATION',
  'ohos.permission.READ_IMAGEVIDEO',
  'ohos.permission.WRITE_IMAGEVIDEO',
];

export class PermissionApiImpl extends PermissionApi {
  private ctx?: common.Context;
  private uiCtx?: common.UIAbilityContext;

  constructor(context: common.Context) {
    super();
    this.ctx = context;
    this.uiCtx = this.isUiContext(context) ? context as common.UIAbilityContext : undefined;
  }

  override isIgnoringBatteryOptimizations(): PermissionStatus {
    return PermissionStatus.GRANTED;
  }

  override hasManageMediaPermission(): boolean {
    return true;
  }

  override async requestManageMediaPermission(result: Result<boolean>): Promise<void> {
    result.success(await this.requestMediaPermissions());
  }

  override async manageMediaPermission(result: Result<boolean>): Promise<void> {
    result.success(await this.requestMediaPermissions());
  }

  private isUiContext(context: common.Context): boolean {
    return (context as common.UIAbilityContext).abilityInfo !== undefined;
  }

  private async requestMediaPermissions(): Promise<boolean> {
    const uiContext = this.uiCtx;
    if (!uiContext) {
      return false;
    }

    try {
      const manager = abilityAccessCtrl.createAtManager();
      const permissionResult: PermissionRequestResult = await manager.requestPermissionsFromUser(uiContext, MEDIA_PERMISSIONS);
      return permissionResult.authResults.every((authResult: number): boolean => authResult === 0);
    } catch (_) {
      return false;
    }
  }
}
