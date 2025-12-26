import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import { Want } from '@kit.AbilityKit';

import {
  FORM_NAME_MEMORIES,
  WidgetState,
  WidgetType,
  WidgetFormData,
  loadFormMap,
  saveFormMap,
} from './model/Model';
import { updateWidgetForm } from './ImageDownloadWorker';

const FORM_ID_PLAIN_KEY = 'formId';
const FORM_NAME_PLAIN_KEY = 'formName';

export default class RandomReceiver extends FormExtensionAbility {
  private readonly formTypes: Map<string, WidgetType> = new Map();

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = (want.parameters?.[FORM_ID_PLAIN_KEY] as string) ?? '';
    const formName = (want.parameters?.[FORM_NAME_PLAIN_KEY] as string) ?? '';
    const widgetType = formName === FORM_NAME_MEMORIES ? WidgetType.MEMORIES : WidgetType.RANDOM;
    console.error(`[WidgetReceiver] onAddForm formId=${formId} formName=${formName} type=${widgetType}`);

    if (formId) {
      this.rememberFormType(formId, widgetType);
    }

    const formImages: Record<string, number> = {};
    const initialData: WidgetFormData = {
      text: '',
      loaded: false,
      imgName: '',
      formImages,
      deeplink: 'immich://',
      state: WidgetState.LOADING,
    };

    updateWidgetForm(this.context, formId, widgetType).catch(() => {});
    return formBindingData.createFormBindingData(initialData);
  }

  onUpdateForm(formId: string): void {
    if (!formId) {
      console.error('[WidgetReceiver] onUpdateForm missing formId');
      return;
    }
    const widgetType = this.resolveWidgetType(formId);
    console.error(`[WidgetReceiver] onUpdateForm formId=${formId} type=${widgetType}`);
    updateWidgetForm(this.context, formId, widgetType).catch(() => {});
  }

  onRemoveForm(formId: string): void {
    if (!formId) {
      console.error('[WidgetReceiver] onRemoveForm missing formId');
      return;
    }
    console.error(`[WidgetReceiver] onRemoveForm formId=${formId}`);
    this.forgetFormType(formId);
  }

  private rememberFormType(formId: string, widgetType: WidgetType): void {
    if (!formId) {
      return;
    }
    this.formTypes.set(formId, widgetType);
    const formMap = loadFormMap(this.context);
    formMap[formId] = widgetType;
    saveFormMap(this.context, formMap);
    console.error(`[WidgetReceiver] rememberFormType saved formId=${formId} type=${widgetType}`);
  }

  private forgetFormType(formId: string): void {
    if (!formId) {
      return;
    }
    this.formTypes.delete(formId);
    const formMap = loadFormMap(this.context);
    if (formMap[formId]) {
      const nextFormMap: Record<string, WidgetType> = {};
      for (const key of Object.keys(formMap)) {
        if (key !== formId) {
          nextFormMap[key] = formMap[key];
        }
      }
      saveFormMap(this.context, nextFormMap);
      console.error(`[WidgetReceiver] forgetFormType removed formId=${formId}`);
    } else {
      console.error(`[WidgetReceiver] forgetFormType no entry for formId=${formId}`);
    }
  }

  private resolveWidgetType(formId: string): WidgetType {
    const cached = this.formTypes.get(formId);
    if (cached) {
      console.error(`[WidgetReceiver] resolveWidgetType cache hit formId=${formId} type=${cached}`);
      return cached;
    }
    const formMap = loadFormMap(this.context);
    const stored = formMap[formId];
    if (stored) {
      this.formTypes.set(formId, stored);
      console.error(`[WidgetReceiver] resolveWidgetType map hit formId=${formId} type=${stored}`);
      return stored;
    }
    console.error(`[WidgetReceiver] resolveWidgetType fallback formId=${formId}`);
    return WidgetType.RANDOM;
  }
}
