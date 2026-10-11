import { hilog } from '@kit.PerformanceAnalysisKit';
import { MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';

class BackgroundWorkerLogEntry {
  readonly level: string;
  readonly timestamp: string;
  readonly message: string;

  constructor(level: string, message: string) {
    this.level = level;
    this.timestamp = new Date().toISOString();
    this.message = message;
  }
}

/** Shared HiLog tag for the native half of the background backup lifecycle. */
export class BackgroundWorkerLog {
  private static readonly DOMAIN = 0xD018;
  private static readonly TAG = 'ImmichBgWorker';
  private static readonly MAX_PENDING_LOGS = 300;
  private static pendingLogs: Array<BackgroundWorkerLogEntry> = [];
  private static droppedPendingLogs: number = 0;
  private static channel?: MethodChannel;
  private static dartLogServiceReady: boolean = false;

  static beginRun(): void {
    BackgroundWorkerLog.channel?.setMethodCallHandler(null);
    BackgroundWorkerLog.channel = undefined;
    BackgroundWorkerLog.dartLogServiceReady = false;
    BackgroundWorkerLog.pendingLogs = [];
    BackgroundWorkerLog.droppedPendingLogs = 0;
  }

  static attach(channel: MethodChannel): void {
    BackgroundWorkerLog.channel = channel;
    BackgroundWorkerLog.dartLogServiceReady = false;
    channel.setMethodCallHandler(new BackgroundWorkerLogBridge());
    BackgroundWorkerLog.info('Native-to-Immich log bridge attached; waiting for Dart LogService');
  }

  static info(message: string): void {
    BackgroundWorkerLog.write('info', message);
  }

  static warn(message: string): void {
    BackgroundWorkerLog.write('warning', message);
  }

  static error(message: string): void {
    BackgroundWorkerLog.write('severe', message);
  }

  static onDartLogServiceReady(): void {
    BackgroundWorkerLog.dartLogServiceReady = true;
    const pending = BackgroundWorkerLog.pendingLogs;
    const dropped = BackgroundWorkerLog.droppedPendingLogs;
    BackgroundWorkerLog.pendingLogs = [];
    BackgroundWorkerLog.droppedPendingLogs = 0;
    for (const entry of pending) {
      BackgroundWorkerLog.sendToDart(entry);
    }
    BackgroundWorkerLog.info(`Dart Immich LogService ready; replayed ${pending.length} buffered ArkTS log entries, dropped=${dropped}`);
  }

  private static write(level: string, message: string): void {
    const formatted = `[${level}] ${message}`;
    if (level === 'severe') {
      hilog.error(BackgroundWorkerLog.DOMAIN, BackgroundWorkerLog.TAG, '%{public}s', formatted);
    } else if (level === 'warning') {
      hilog.warn(BackgroundWorkerLog.DOMAIN, BackgroundWorkerLog.TAG, '%{public}s', formatted);
    } else {
      hilog.info(BackgroundWorkerLog.DOMAIN, BackgroundWorkerLog.TAG, '%{public}s', formatted);
    }
    const entry = new BackgroundWorkerLogEntry(level, message);
    if (!BackgroundWorkerLog.dartLogServiceReady || BackgroundWorkerLog.channel === undefined) {
      BackgroundWorkerLog.pendingLogs.push(entry);
      if (BackgroundWorkerLog.pendingLogs.length > BackgroundWorkerLog.MAX_PENDING_LOGS) {
        BackgroundWorkerLog.pendingLogs.shift();
        BackgroundWorkerLog.droppedPendingLogs++;
      }
      return;
    }
    BackgroundWorkerLog.sendToDart(entry);
  }

  private static sendToDart(entry: BackgroundWorkerLogEntry): void {
    const channel = BackgroundWorkerLog.channel;
    if (channel === undefined) {
      return;
    }
    const args = new Map<string, Object>();
    args.set('level', entry.level);
    args.set('timestamp', entry.timestamp);
    args.set('message', entry.message);
    channel.invokeMethod('log', args, {
      notImplemented: () => {
        hilog.warn(BackgroundWorkerLog.DOMAIN, BackgroundWorkerLog.TAG, 'Dart log bridge method is not implemented');
      },
      error: (code: string, message?: string) => {
        hilog.warn(BackgroundWorkerLog.DOMAIN, BackgroundWorkerLog.TAG, 'Dart log bridge failed: %{public}s %{public}s', code, message ?? '');
      },
      success: () => {},
    });
  }
}

class BackgroundWorkerLogBridge implements MethodCallHandler {
  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method === 'ready') {
      BackgroundWorkerLog.onDartLogServiceReady();
      result.success(true);
      return;
    }
    result.notImplemented();
  }
}
