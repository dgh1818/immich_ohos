import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import { Want } from '@kit.AbilityKit';

import {
  FORM_NAME_MEMORIES,
  DEFAULT_SLIDE_INTERVAL_SECONDS,
  WidgetState,
  WidgetType,
  WidgetFormData,
  loadFormMap,
  loadFormNameMap,
  saveFormMap,
  saveFormNameMap,
  saveWidgetIndex,
} from './model/Model';
import { loadMoreWidgetImages, updateWidgetForm } from './ImageDownloadWorker';

const FORM_ID_KEY = 'ohos.extra.param.key.form_identity';
const FORM_NAME_KEY = 'ohos.extra.param.key.form_name';

export default class RandomReceiver extends FormExtensionAbility {
  private readonly formTypes: Map<string, WidgetType> = new Map();
  private readonly loadMoreInFlight: Set<string> = new Set();

  onAddForm(want: Want): formBindingData.FormBindingData {
    const params = want.parameters as Record<string, ESObject> | undefined;
    const paramKeys = params ? Object.keys(params) : [];
    console.error(`[WidgetReceiver] onAddForm params keys=${paramKeys.join(',')}`);
    const formId = (params?.[FORM_ID_KEY] as string) ?? '';
    const formName = (params?.[FORM_NAME_KEY] as string) ?? '';
    const isMemories = formName === FORM_NAME_MEMORIES;
    const widgetType = isMemories ? WidgetType.MEMORIES : WidgetType.RANDOM;
    console.error(
      `[WidgetReceiver] onAddForm formId=${formId} formName=${formName} type=${widgetType}`,
    );
    console.error(
      `[WidgetReceiver] onAddForm resolve memoriesName=${FORM_NAME_MEMORIES} isMemories=${isMemories}`,
    );

    if (formId) {
      this.rememberFormType(formId, widgetType, formName);
    }

    const formImages: Record<string, number> = {};
    const initialData: WidgetFormData = {
      text: '',
      loaded: false,
      imgName: '',
      formImages,
      deeplink: 'immich://',
      entriesJson: '[]',
      activeIndex: 0,
      slideIntervalSeconds: DEFAULT_SLIDE_INTERVAL_SECONDS,
      state: WidgetState.LOADING,
    };

    if (formId) {
      updateWidgetForm(this.context, formId, widgetType).catch(() => {});
    }
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

  onFormEvent(formId: string, message: string): void {
    if (!formId) {
      console.error('[WidgetReceiver] onFormEvent missing formId');
      return;
    }
    console.error(`[WidgetReceiver] onFormEvent formId=${formId} message=${message}`);
    let payload: Record<string, string | number | boolean> = {};
    try {
      payload = JSON.parse(message) as Record<string, string | number | boolean>;
    } catch (err) {
      console.error(`[WidgetReceiver] onFormEvent parse failed error=${err}`);
      return;
    }
    const rawIndex = payload['index'];
    const index =
      typeof rawIndex === 'number' ? rawIndex : parseInt(`${rawIndex ?? ''}`, 10);
    const normalizedIndex = Number.isFinite(index) ? index : 0;
    if (Number.isFinite(index)) {
      saveWidgetIndex(this.context, formId, index);
    }
    const loadMore = payload['loadMore'] === true || payload['event'] === 'load_more';
    if (loadMore) {
      const rawImgName = payload['imgName'];
      const imgName = typeof rawImgName === 'string' ? rawImgName : '';
      const widgetType = this.resolveWidgetType(formId);
      if (this.loadMoreInFlight.has(formId)) {
        console.error(`[WidgetReceiver] onFormEvent skip loadMore (in flight) formId=${formId}`);
        return;
      }
      this.loadMoreInFlight.add(formId);
      loadMoreWidgetImages(this.context, formId, widgetType, imgName, normalizedIndex)
        .catch(() => {})
        .finally(() => {
          this.loadMoreInFlight.delete(formId);
        });
    }
  }

  private rememberFormType(formId: string, widgetType: WidgetType, formName?: string): void {
    if (!formId) {
      return;
    }
    this.formTypes.set(formId, widgetType);
    const formMap = loadFormMap(this.context);
    formMap[formId] = widgetType;
    saveFormMap(this.context, formMap);
    console.error(`[WidgetReceiver] rememberFormType saved formId=${formId} type=${widgetType}`);
    if (formName) {
      const formNameMap = loadFormNameMap(this.context);
      formNameMap[formId] = formName;
      saveFormNameMap(this.context, formNameMap);
      console.error(
        `[WidgetReceiver] rememberFormType saved formName=${formName} formId=${formId}`,
      );
    }
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
    const formNameMap = loadFormNameMap(this.context);
    if (formNameMap[formId]) {
      const nextFormNameMap: Record<string, string> = {};
      for (const key of Object.keys(formNameMap)) {
        if (key !== formId) {
          nextFormNameMap[key] = formNameMap[key];
        }
      }
      saveFormNameMap(this.context, nextFormNameMap);
      console.error(`[WidgetReceiver] forgetFormType removed formName formId=${formId}`);
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
