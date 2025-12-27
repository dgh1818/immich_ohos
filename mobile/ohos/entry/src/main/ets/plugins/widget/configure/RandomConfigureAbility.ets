import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { AbilityConstant, Want } from '@kit.AbilityKit';

import { loadFormNameMap } from '../model/Model';

const FORM_ID_KEY = 'ohos.extra.param.key.form_identity';
const FORM_ID_KEY_ALT = 'formId';
const FORM_NAME_KEY = 'ohos.extra.param.key.form_name';

export default class RandomConfigureAbility extends UIAbility {
  private formId: string = '';
  private formName: string = '';

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const params = want.parameters as Record<string, ESObject> | undefined;
    const paramKeys = params ? Object.keys(params) : [];
    console.error(`[WidgetConfigAbility] onCreate params keys=${paramKeys.join(',')}`);
    const rawFormIdPlain =
      (params?.[FORM_ID_KEY] as string) ?? (params?.[FORM_ID_KEY_ALT] as string) ?? '';
    const rawFormNamePlain = (params?.[FORM_NAME_KEY] as string) ?? '';
    let resolvedFormName = rawFormNamePlain;
    if (!resolvedFormName && rawFormIdPlain) {
      const formNameMap = loadFormNameMap(this.context);
      const storedFormName = formNameMap[rawFormIdPlain];
      if (storedFormName) {
        resolvedFormName = storedFormName;
        console.error(
          `[WidgetConfigAbility] fallback formName=${resolvedFormName} formId=${rawFormIdPlain}`,
        );
      }
    }
    console.error(
      `[WidgetConfigAbility] raw formId=${rawFormIdPlain} formName=${rawFormNamePlain}`
    );
    this.formId = rawFormIdPlain;
    this.formName = resolvedFormName;
    console.error(`[WidgetConfigAbility] resolved formId=${this.formId} formName=${this.formName}`);
    AppStorage.setOrCreate('widgetConfigFormId', this.formId);
    AppStorage.setOrCreate('widgetConfigFormName', this.formName);
    console.error('[WidgetConfigAbility] AppStorage set for formId/formName');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.error('[WidgetConfigAbility] onWindowStageCreate loadContent start');
    windowStage.loadContent('plugins/widget/configure/RandomConfigure', (err) => {
      if (err.code) {
        console.error('Failed to load widget config page', JSON.stringify(err));
      } else {
        console.error('[WidgetConfigAbility] loadContent success');
      }
    });
  }

}
