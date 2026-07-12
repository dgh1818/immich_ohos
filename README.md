<p align="center"> 
  <br/>
  <a href="https://opensource.org/license/agpl-v3"><img src="https://img.shields.io/badge/License-AGPL_v3-blue.svg?color=3F51B5&style=for-the-badge&label=License&logoColor=000000&labelColor=ececec" alt="License: AGPLv3"></a>
  <a href="https://discord.immich.app">
    <img src="https://img.shields.io/discord/979116623879368755.svg?label=Discord&logo=Discord&style=for-the-badge&logoColor=000000&labelColor=ececec" alt="Discord"/>
  </a>
  <br/>
  <br/>
</p>

<p align="center">
<img src="design/immich-logo-stacked-light.svg" width="300" title="Login With Custom URL">
</p>
<h3 align="center">High performance self-hosted photo and video management solution</h3>
<br/>
<a href="https://immich.app">
<img src="design/immich-screenshots.png" title="Main Screenshot">
</a>
<br/>

<p align="center">
  <a href="readme_i18n/README_ca_ES.md">Català</a>
  <a href="readme_i18n/README_es_ES.md">Español</a>
  <a href="readme_i18n/README_fr_FR.md">Français</a>
  <a href="readme_i18n/README_it_IT.md">Italiano</a>
  <a href="readme_i18n/README_ja_JP.md">日本語</a>
  <a href="readme_i18n/README_ko_KR.md">한국어</a>
  <a href="readme_i18n/README_de_DE.md">Deutsch</a>
  <a href="readme_i18n/README_nl_NL.md">Nederlands</a>
  <a href="readme_i18n/README_tr_TR.md">Türkçe</a>
  <a href="readme_i18n/README_zh_CN.md">简体中文</a>
  <a href="readme_i18n/README_zh_TW.md">正體中文</a>
  <a href="readme_i18n/README_uk_UA.md">Українська</a>
  <a href="readme_i18n/README_ru_RU.md">Русский</a>
  <a href="readme_i18n/README_pt_BR.md">Português Brasileiro</a>
  <a href="readme_i18n/README_sv_SE.md">Svenska</a>
  <a href="readme_i18n/README_ar_JO.md">العربية</a>
  <a href="readme_i18n/README_vi_VN.md">Tiếng Việt</a>
  <a href="readme_i18n/README_th_TH.md">ภาษาไทย</a>
  <a href="readme_i18n/README_ml_IN.md">മലയാളം</a>
</p>

# Harmonyos Next 鸿蒙端的 Immich <br/>

为了解决云图下载后缓存过大的问题，华为的解决方法如下，因此关于备份云端照片以后不可能再支持：

<img width="1320" height="1690" alt="e768ff15125690d0a43a9cc0b025db39" src="https://github.com/user-attachments/assets/44e3a49d-f88f-41ad-ac6a-7ad16a86bdd9" />



# 网页版查看HDR照片小技巧 <br/>

打开edge或者chrome的硬件加速，并打开Windows显示设置中的“使用HDR”，并打开 Immich账户设置->应用设置->显示原始照片即可 <br/>
安装本服务器，并.env 文件设置：CUVA_TO_ISO_HDR: true ，更可实现网页端查看华为老的私有格式的HDR照片（包括麒麟9000s及之前的平台鸿蒙系统拍摄的照片，或者4.2系统拍摄的照片），也可将转换后的ISO HDR 照片下载到本地。实时请求，实时转换，实时清理。<br/>
不安装本服务器，仅支持查看ISO HDR照片以及苹果iphone15及之前拍摄的MPF HDR照片<br/>

# 升级v2.4.1 之后版本 <br/>

注意事项：

1. 需安装2.x.x版本服务器 <br/>
2. 第一次打开APP白屏，请尝试重启APP <br/>
3. 如果APP打开一直白屏需重新安装APP <br/>
4. 大地图页面待完善 <br/>

链接已实测可用，解决了发布地区在海外导致不能安装的问题，推荐先卸载自签名版本再重新安装，如仍不可用可以提issue <br/>
2026.06.01更新
https://appgallery.huawei.com/link/invite-test-wap?taskId=e0f0682ce3b53061c3a24cd7d0f81202&invitationCode=3qNdJmKFniB <br/>
https://appgallery.huawei.com/app/detail?id=com.dgh18.immich&channelId=SHARE&source=appshare <br/>
**IMMICH 搭配对应版本 本项目下服务器 使用**

<h1>签名有关注意事项：</h1>
1. 本目录下服务器可实现华为动态照片解析<br/>
2. 本目录下服务器搭配PETAL MAP的API KEY可实现中文逆地理编码（中文地名）<br/>
.env 文件设置：<br/>
PETALMAP_GEOCODE_KEYS: //华为 App Gallery Connect API KEY.<br/>
GEOCODE_WITH_PETALMAP: 'true' // 启用 Petal Map 逆地理编码. 80000次/月免费 包括国内和国际<br/>
CUVA_TO_ISO_HDR: 'true' // 启用 CUVA 转 ISO HDR<br/>

AMAP_GEOCODE_KEYS: //高德地图 key.<br/>
GEOCODE_WITH_AMAP: 'true' // 启用高德 逆地理编码 个人开发者国内免费 5000 次每天，国际收费.<br/>
也可以搭配官方对应版本服务器版本使用，但无上述功能。过高的服务器版本可能导致无法登陆<br/>

1. 要实现应用内地图显示，需在APPGALLERY CONNECT中申请签名的同时开通地图权限 <br/>
   控制台地址：https://developer.huawei.com/consumer/cn/service/josp/agc/index.html <br/>
   教程地址：https://ost.51cto.com/answer/23898 mapkit <br/>
2. 要实现照片的备份，要申请开通ACL权限(测试还是很容易开通的，上架可能比较难申请）： <br/>
   "ohos.permission.READ_IMAGEVIDEO" <br/>
   "ohos.permission.WRITE_IMAGEVIDEO" <br/>

<h1>Additional Features：</h1>
1. 实现了 HDR 图片和视频的显示  <br/>
2. 优化了ui布局 点击左上角logo可收起侧栏  <br/>
3. 小地图替换成了petalmap  <br/>
4. 增加了photopicker，无需ACL可手动上传媒体。beta时间线暂未实现，需background_downloader <br/>
5. 接入华为投屏和华为分享 <br/>

<h1>已知问题：</h1>
2. 每行显示数量更改不即时生效（原版app也存在） <br/>

<h1>未完成的功能：</h1>

~~1. beta时间线数据库迁移同步：work_manager未适配~~ <br/>
~~2. 照片同步功能以及后台上传下载功能：background_downloader未适配~~<br/>
~~3. 大地图：[maplibre/flutter-maplibre-gl](https://github.com/maplibre/flutter-maplibre-gl) Huawei mapkit缺少热力图功能~~ <br/>
~~4. wifi信息获取：network_info_plus已发现适配版~~<br/>
~~5. 投屏功能：gcast谷歌投屏~~<br/>
~~6. 桌面小组件~~<br/>
~~7. 分享照片到APP上传功能：share_handler~~ <br/> 8. dynamic_color <br/>

<h1>适配计划：</h1>
4. 动态照片播放改为使用Native侧组件，因为arkts组件有放大照片的防抖算法，停止长按也可立即停止播放动态照片 <br/>
7. 桌面小组件 <br/>

新增的：<br/> 8. 多设备协同？或许可以平板上点击docker栏图片直接跳进手机上的图片页面 <br/> 9. 一碰传？ <br/>

</h1>

<h2>History：</h2>

To Do：

1. 华为动态照片的播放显示（修改 Server 端？）初步完成！需使用本项目服务器，重新分析元数据
2. 替换地图：ExifInfo 小地图替换完成！ （需App Gallery Connect开通地图权限并签名才能显示地图）
   https://ost.51cto.com/answer/23898 mapkit开通教程
3. AI HDR（待完成）
4. 地理反向编码中文化：完成！（需使用本项目服务器，重新分析元数据）（需App Gallery Connect开通地图权限并签名

<h2>备忘：</h2>
1. photopicker最大媒体数量从9修改为了500

https://github.com/dgh1818/immich_ohos/blob/v1.137.3-merge/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250830025443_89_165.jpg?raw=true

<h2>DEMO:</h2>

<table align="center">
  <tr>
    <td>
      <img src="https://github.com/dgh1818/immich_ohos/blob/v1.137.3-merge/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250830024549_88_165.jpg" alt="手机1" width="400">
    </td>
    <td>
      <img src="https://github.com/dgh1818/immich_ohos/blob/v1.137.3-merge/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250830025443_89_165.jpg" alt="手机2" width="400">
    </td>
  </tr>
</table>

<p align="center">
  <img src="https://github.com/user-attachments/assets/bcd88029-4e22-4742-95ae-77477a2fc855" alt="平板1" width="800" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/79e9e708-26d7-49d8-b2fc-e61859f581d3" alt="平板2" width="800" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/b9087716-ef8e-4f24-b3dc-3728fc6400a6" alt="平板3" width="800" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/dd8c81d6-e76b-4669-be88-2867eb94966f" alt="平板4" width="800" />
</p>
<p align="center">
  <img src="https://github.com/dgh1818/immich_ohos/blob/v1.137.3-merge/%E5%BE%AE%E4%BF%A1%E5%9B%BE%E7%89%87_20250830031325_93_165.jpg" alt="平板5" width="800" />
</p>

</h1>

> [!WARNING]
> ⚠️ Always follow [3-2-1](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/) backup plan for your precious photos and videos!

> [!NOTE]
> You can find the main documentation, including installation guides, at https://immich.app/.

## Links

- [Documentation](https://docs.immich.app/)
- [About](https://docs.immich.app/overview/introduction)
- [Installation](https://docs.immich.app/install/requirements)
- [Roadmap](https://immich.app/roadmap)
- [Demo](#demo)
- [Features](#features)
- [Translations](https://docs.immich.app/developer/translations)
- [Contributing](https://docs.immich.app/overview/support-the-project)

## Demo

Access the demo [here](https://demo.immich.app). For the mobile app, you can use `https://demo.immich.app` for the `Server Endpoint URL`.

### Login credentials

| Email           | Password |
| --------------- | -------- |
| demo@immich.app | demo     |

## Features

| Features                                     | Mobile | Web |
| :------------------------------------------- | ------ | --- |
| Upload and view videos and photos            | Yes    | Yes |
| Auto backup when the app is opened           | Yes    | N/A |
| Prevent duplication of assets                | Yes    | Yes |
| Selective album(s) for backup                | Yes    | N/A |
| Download photos and videos to local device   | Yes    | Yes |
| Multi-user support                           | Yes    | Yes |
| Album and Shared albums                      | Yes    | Yes |
| Scrubbable/draggable scrollbar               | Yes    | Yes |
| Support raw formats                          | Yes    | Yes |
| Metadata view (EXIF, map)                    | Yes    | Yes |
| Search by metadata, objects, faces, and CLIP | Yes    | Yes |
| Administrative functions (user management)   | No     | Yes |
| Background backup                            | Yes    | N/A |
| Virtual scroll                               | Yes    | Yes |
| OAuth support                                | Yes    | Yes |
| API Keys                                     | N/A    | Yes |
| LivePhoto/MotionPhoto backup and playback    | Yes    | Yes |
| Support 360 degree image display             | No     | Yes |
| User-defined storage structure               | Yes    | Yes |
| Public Sharing                               | Yes    | Yes |
| Archive and Favorites                        | Yes    | Yes |
| Global Map                                   | Yes    | Yes |
| Partner Sharing                              | Yes    | Yes |
| Facial recognition and clustering            | Yes    | Yes |
| Memories (x years ago)                       | Yes    | Yes |
| Offline support                              | Yes    | No  |
| Read-only gallery                            | Yes    | Yes |
| Stacked Photos                               | Yes    | Yes |
| Tags                                         | No     | Yes |
| Folder View                                  | Yes    | Yes |

## Translations

Read more about translations [here](https://docs.immich.app/developer/translations).

<a href="https://hosted.weblate.org/engage/immich/">
<img src="https://hosted.weblate.org/widget/immich/immich/multi-auto.svg" alt="Translation status" />
</a>

## Repository activity

![Activities](https://repobeats.axiom.co/api/embed/9e86d9dc3ddd137161f2f6d2e758d7863b1789cb.svg "Repobeats analytics image")

## Star history

<a href="https://star-history.com/#immich-app/immich&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=immich-app/immich&type=date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=immich-app/immich&type=date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=immich-app/immich&type=date" width="100%" />
 </picture>
</a>

## Contributors

<a href="https://github.com/immich-app/immich/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=immich-app/immich" width="100%"/>
</a>
