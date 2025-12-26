import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityAware,
  AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';

import { WidgetType, loadFormMap, loadWidgetData, saveWidgetData } from './model/Model';
import { updateWidgetForm } from './ImageDownloadWorker';

export default class HomeWidgetPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel?: MethodChannel;
  private abilityContext?: common.Context;

  getUniqueClassName(): string {
    return 'HomeWidgetPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'home_widget');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(undefined);
    this.channel = undefined;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityContext = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    this.abilityContext = undefined;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    const context = this.abilityContext;
    switch (call.method) {
      case 'saveWidgetData': {
        if (!context) {
          result.error('NO_CONTEXT', 'Ability context not available', null);
          return;
        }
        const args = call.args as Map<string, string>;
        const key = args.get('id') ?? '';
        const value = args.get('data') ?? '';
        if (!key) {
          result.error('INVALID_ARGS', 'Missing key', null);
          return;
        }
        saveWidgetData(context, key, value);
        result.success(true);
        return;
      }
      case 'updateWidget': {
        if (!context) {
          result.error('NO_CONTEXT', 'Ability context not available', null);
          return;
        }
        const formMap = loadFormMap(context);
        const formIds = Object.keys(formMap);
        for (let i = 0; i < formIds.length; i++) {
          const formId = formIds[i];
          const widgetType = formMap[formId] ?? WidgetType.RANDOM;
          await updateWidgetForm(context, formId, widgetType);
        }
        result.success(true);
        return;
      }
      case 'setAppGroupId': {
        result.success(true);
        return;
      }
      case 'getWidgetData': {
        if (!context) {
          result.error('NO_CONTEXT', 'Ability context not available', null);
          return;
        }
        const args = call.args as Map<string, string>;
        const key = args.get('id') ?? '';
        const defaultValue = args.get('defaultValue') ?? '';
        if (!key) {
          result.error('INVALID_ARGS', 'Missing key', null);
          return;
        }
        const value = loadWidgetData(context, key, defaultValue);
        result.success(value);
        return;
      }
      default:
        result.notImplemented();
    }
  }
}
