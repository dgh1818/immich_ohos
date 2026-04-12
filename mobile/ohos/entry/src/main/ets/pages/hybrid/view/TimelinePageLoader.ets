import { TimelineView } from './TimelineView';

export interface TimelinePageLoaderParams {
  topInset: number;
}

@Builder
export function TimelinePageLoader(params: TimelinePageLoaderParams) {
  TimelineView({
    topInset: params.topInset,
  });
}