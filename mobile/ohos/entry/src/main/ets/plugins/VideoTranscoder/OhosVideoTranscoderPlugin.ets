import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { fileIo as fs } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';

const CHANNEL = 'immich/ohos_video_transcoder';

export default class OhosVideoTranscoderPlugin implements FlutterPlugin, MethodCallHandler {
  private channel?: MethodChannel;

  getUniqueClassName(): string {
    return 'OhosVideoTranscoderPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(undefined);
    this.channel = undefined;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    if (call.method !== 'transcodeMovToMp4') {
      result.notImplemented();
      return;
    }

    const args = call.args as Map<string, string>;
    const inputPath = args.get('inputPath') ?? '';
    const outputPath = args.get('outputPath') ?? '';
    if (!inputPath || !outputPath) {
      result.error('INVALID_ARGS', 'inputPath and outputPath are required', null);
      return;
    }

    try {
      result.success(await this.transcodeMovToMp4(inputPath, outputPath));
    } catch (e) {
      const message = this.errorMessage('OHOS AVTranscoder failed', inputPath, outputPath, e);
      console.error(message);
      result.error('AVTRANSCODER_FAILED', message, null);
    }
  }

  private async transcodeMovToMp4(inputPath: string, outputPath: string): Promise<string> {
    let inputFile: fs.File | undefined = undefined;
    let outputFile: fs.File | undefined = undefined;
    let avTranscoder: media.AVTranscoder | undefined = undefined;

    try {
      const stat = fs.statSync(inputPath);
      inputFile = fs.openSync(inputPath, fs.OpenMode.READ_ONLY);
      outputFile = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.truncateSync(outputFile.fd, 0);

      avTranscoder = await media.createAVTranscoder();
      avTranscoder.fdSrc = { fd: inputFile.fd, offset: 0, length: stat.size };
      avTranscoder.fdDst = outputFile.fd;

      const config: media.AVTranscoderConfig = {
        fileFormat: media.ContainerFormatType.CFT_MPEG_4,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        videoCodec: media.CodecMimeType.VIDEO_AVC,
      };

      await new Promise<void>((resolve, reject) => {
        let settled = false;

        const finish = async (error?: Error): Promise<void> => {
          if (settled) {
            return;
          }
          settled = true;
          try {
            avTranscoder?.off('complete');
            avTranscoder?.off('error');
            avTranscoder?.off('progressUpdate');
          } catch (_) {}
          try {
            await avTranscoder?.release();
          } catch (releaseError) {
            if (!error) {
              error = releaseError as Error;
            }
          }
          avTranscoder = undefined;
          if (error) {
            reject(error);
          } else {
            resolve();
          }
        };

        avTranscoder!.on('complete', () => {
          finish();
        });
        avTranscoder!.on('error', (err: BusinessError) => {
          finish(new Error(this.errorMessage('OHOS AVTranscoder error event', inputPath, outputPath, err)));
        });
        avTranscoder!.prepare(config)
          .then(() => avTranscoder!.start())
          .catch((err: Error) => finish(err));
      });

      const outputStat = fs.statSync(outputPath);
      if (outputStat.size <= 0) {
        throw new Error(`OHOS AVTranscoder produced empty output: inputPath=${inputPath}, outputPath=${outputPath}`);
      }
      console.info(`OHOS AVTranscoder success: inputPath=${inputPath}, outputPath=${outputPath}, outputBytes=${outputStat.size}`);
      return outputPath;
    } finally {
      if (avTranscoder) {
        try {
          await avTranscoder.release();
        } catch (_) {}
      }
      if (inputFile) {
        fs.closeSync(inputFile);
      }
      if (outputFile) {
        fs.closeSync(outputFile);
      }
    }
  }

  private errorMessage(prefix: string, inputPath: string, outputPath: string, error: Object): string {
    const businessError = error as BusinessError;
    return `${prefix}: inputPath=${inputPath}, outputPath=${outputPath}, code=${businessError.code ?? ''}, message=${businessError.message ?? error}`;
  }
}
