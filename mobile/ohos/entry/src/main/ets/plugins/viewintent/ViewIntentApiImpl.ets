import { Result, ViewIntentHostApi, ViewIntentPayload } from './ViewIntent.g';

export class ViewIntentApiImpl extends ViewIntentHostApi {
  override consumeViewIntent(result: Result<ViewIntentPayload | undefined>): void {
    result.success(undefined);
  }
}
