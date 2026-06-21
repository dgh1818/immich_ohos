import { Result, ViewIntentHostApi, ViewIntentPayload } from './ViewIntent.g';

export class ViewIntentApiImpl extends ViewIntentHostApi {
  override consumeViewIntent(result: Result<ViewIntentPayload | null>): void {
    result.success(null);
  }
}
