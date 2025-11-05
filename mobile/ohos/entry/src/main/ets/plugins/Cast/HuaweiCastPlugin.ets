/**
 * MIT License
 *
 * Copyright (c) 2025 dgh1818
 * https://github.com/dgh1818/immich_ohos
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { FlutterPlugin, FlutterPluginBinding, MethodCall,
  MethodCallHandler,
  MethodChannel, MethodResult,
  StandardMethodCodec,AbilityAware,AbilityPluginBinding,FlutterLoader,
  PluginRegistry } from "@ohos/flutter_ohos";

import { avSession } from '@kit.AVSessionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';


const TAG = "HuaweiCastPlugin"

/** ImageGallerySaverPlugin2 **/
export default class HuaweiCastPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  public avCastController?: avSession.AVCastController;
  public avSession?: avSession.AVSession;
  public sessionId?: string;
  public playItem?: avSession.AVQueueItem;
  private channel: MethodChannel | null = null;
  private applicationContext: common.UIAbilityContext | null = null;
  //private fileMimeType: FileMimeTypeUtil = new FileMimeTypeUtil();
  private binding: AbilityPluginBinding | null = null;
  private metadata?: avSession.AVMetadata;

  private contentUrl?: string;
  private mediaImage?: string;
  private title?: string;
  private duration?:number;

  private assetId?: string;

  private position: number = 0;
  private isPlaying: boolean = true

  constructor() {
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.binding = binding;
    this.applicationContext = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {

  }

  getUniqueClassName(): string {
    return "HuaweiCastPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "huawei_cast");
    this.channel.setMethodCallHandler(this);
    //this.applicationContext = binding.getApplicationContext();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult) {
    switch (call.method) {
      case "setMetadata":
        this.contentUrl = call.args.get("contentUrl");
        this.mediaImage = call.args.get("mediaImage");
        this.title = call.args.get("title");
        this.duration = call.args.get("duration");
        await this.createSession(this.contentUrl!, this.mediaImage!, this.title!, this.duration!,result);
        break;
      case "startCast":
        this.assetId = call.args.get("assetId");
        //await this.setOutputDeviceChangeListener(this.assetId!, this.title!, this.contentUrl!);
        await this.startCast(this.assetId!, this.title!, this.contentUrl!);
        result.success({});
        break;
      case "setCurrentPosition":
        this.position = call.args.get("position");
        this.isPlaying = call.args.get("isPlaying") as boolean;
        this.setCurrentPosition(this.position,this.isPlaying);
        result.success({});
        break;
      case "clearSession":
        await this.clearSession();
        result.success({});
      default:
        return result.notImplemented();
    }
  }


  /**
   * 设置输出设备变化监听器
   */
private async setOutputDeviceChangeListener(assetId: string, title: string, mediaUri: string): Promise<void> {
    this.avSession?.on('outputDeviceChange', async (connectState: avSession.ConnectionState,
      device: avSession.OutputDeviceInfo) => {
      const castCategory = device?.devices?.[0].castCategory;
      // 成功连接远程设备
      if (castCategory === avSession.AVCastCategory.CATEGORY_REMOTE &&
        connectState === avSession.ConnectionState.STATE_CONNECTED) {
        this.avCastController = await this.avSession!.getAVCastController();
        // 获取cast控制器

        this.avCastController?.prepare(this.playItem);
        this.avCastController!.start(this.playItem);

        }
      })
    };


  /**
   * 开始投播
   */



  async createSession(url: string, mediaImage: string, title: string, duration: number,
    result: MethodResult): Promise<void> {

    // this.avSession = await avSession.createAVSession(this.applicationContext, 'video_test', 'video');
    if (!this.applicationContext) {
      return;
    }

    if(!this.avSession) {
      this.avSession = await avSession.createAVSession(this.applicationContext, 'cast', 'video');
    }

    this.avSession.activate();

    this.metadata = {
      assetId: url,
      mediaImage: mediaImage,
      title: title, // 需要配置实际id
      duration: duration, // 播放媒体资源的标题
      // 发现Cast+ Stream 和 DLNA协议设备，TYPE_CAST_PLUS_STREAM为默认必选。
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    };

    await this.avSession.setAVMetadata(this.metadata);
    await this.avSession.setExtras({ 'requireAbilityList': ['url-cast'] })
    await this.setListenerForMesFromController();
    result.success({});
  }

  async clearSession(): Promise<void> {

    // this.avSession = await avSession.createAVSession(this.applicationContext, 'video_test', 'video');
    if (!this.applicationContext) {
      return;
    }

    if(this.avSession) {
      this.avSession.destroy();
      this.avSession = undefined;
    }
  }


  private async startCast(assetId: string, title: string, mediaUri: string): Promise<void> {



    if (this.applicationContext) {
      this.playItem = {
        itemId: 1,
        description: {
          assetId: `${assetId}`,
          title: title,
          mediaUri: mediaUri,
        }
      };
      let avCastPicker = new avSession.AVCastPickerHelper(this.applicationContext);

      let tag = "createNewSession";

      let avCastPickerOptions: avSession.AVCastPickerOptions = {
        sessionType: 'video',
      }

      this.setOutputDeviceChangeListener(assetId, title, mediaUri);


      avCastPicker.select(avCastPickerOptions).then( () => {
        console.info('select successfully');
        try {
          // this.avCastController = this.avSession!.getAVCastController();
          // this.avCastController?.prepare(this.playItem);
          // this.avCastController!.start(this.playItem);
        } catch (err) {
          console.error(err);
          //this.handlerCastError(err, 'avSessionError', 'prepare');
        }

      }).catch((err: BusinessError) => {
        console.error(`AVCastPicker.select failed with err: ${err.code}, ${err.message}`);
      });

    }
  }

  private async setCurrentPosition(position: number, isplaying: boolean): Promise<void> {
    let playbackState: avSession.AVPlaybackState = {
      state: isplaying?avSession.PlaybackState.PLAYBACK_STATE_PLAY :avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: position, // 已经播放的位置，以ms为单位。
        updateTime: new Date().getTime(), // 应用更新当前位置时的时间戳，以ms为单位。
      },
    };

    this.avSession!.setAVPlaybackState(playbackState, (err) => {
      if (err) {
        console.error(`Failed to set AVPlaybackState. Code: ${err.code}, message: ${err.message}`);
      } else {
        //console.info(`SetAVPlaybackState successfully`);
      }
    });
  }

  async setListenerForMesFromController() {
    if (!this.avSession) {
      return;
    }
    this.avSession.on('play', this.playCall);
    this.avSession.on('pause', this.pauseCall);
    this.avSession.off('playNext');
    this.avSession.off('playPrevious');
    this.avSession.on('seek', (time: number) => {
      this.channel?.invokeMethod('seekTo',{'position':time});
    });
  }

  async unregisterSessionListener() {
    if (!this.avSession) {
      return;
    }
    this.avSession.off('play');
    this.avSession.off('pause');
    this.avSession.off('playNext');
    this.avSession.off('playPrevious');
  }

  private playCall: () =>void = () => {
    //his.m
    this.channel?.invokeMethod('play',{});


  };
  private pauseCall: () =>void = () => {
    this.channel?.invokeMethod('pause',{});
    //this.pause();
  };
  private playNextCall: () =>void = () => {

    return;
  };
  private playPreviousCall: () =>void = () => {
    return
  };
}
