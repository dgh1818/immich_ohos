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
  <a href="readme_i18n/README_zh_CN.md">中文</a>
  <a href="readme_i18n/README_uk_UA.md">Українська</a>
  <a href="readme_i18n/README_ru_RU.md">Русский</a>
  <a href="readme_i18n/README_pt_BR.md">Português Brasileiro</a>
  <a href="readme_i18n/README_sv_SE.md">Svenska</a>
  <a href="readme_i18n/README_ar_JO.md">العربية</a>
  <a href="readme_i18n/README_vi_VN.md">Tiếng Việt</a>
  <a href="readme_i18n/README_th_TH.md">ภาษาไทย</a>
</p>

## Harmonyos Next 适配

**IMMICH 1.129.0 搭配 本项目下服务器 使用**

To do:
1. v1.122.0 之后版本要用到 native_player 插件，尚未适配（由于修改了flutter引擎，因此不用native_player也能实现hdr，因此用回flutter video player)

Harmonyos Next 鸿蒙端的 Immich
实现了 HDR 图片和视频的显示
优化ui布局 点击左上角logo可收起侧栏

To Do：

1. 华为动态照片的播放显示（修改 Server 端？）初步完成！需使用本项目服务器，重新分析元数据
2. 替换地图：ExifInfo 小地图初步完成！大地图 Mapkit 尚未有热力图功能，待官方功能完善 （需App Gallery Connect开通地图权限并签名才能显示地图）
https://ost.51cto.com/answer/23898 mapkit开通教程
3. AI HDR（待完成）
4. 地理反向编码中文化：完成！（需使用本项目服务器，重新分析元数据）（需App Gallery Connect开通地图权限并签名）
5. 当前 flutter 版本受限（3.27），无法使用最新 flutter 版本（3.32），后续更新

.env 文件设置：
PETALMAP_GEOCODE_KEYS: //华为 App Gallery Connect API KEY.
GEOCODE_WITH_PETALMAP: 'true' // 启用 Petal Map 逆地理编码. 80000次/月免费 包括国内和国际

AMAP_GEOCODE_KEYS: //高德地图 key.
GEOCODE_WITH_AMAP: 'true' // 启用高德 逆地理编码 个人开发者国内免费 5000 次每天，国际收费.

## Disclaimer

- ⚠️ The project is under **very active** development.
- ⚠️ Expect bugs and breaking changes.
- ⚠️ **Do not use the app as the only way to store your photos and videos.**
- ⚠️ Always follow [3-2-1](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/) backup plan for your precious photos and videos!

> [!NOTE]
> You can find the main documentation, including installation guides, at https://immich.app/.

## Links

- [Documentation](https://immich.app/docs)
- [About](https://immich.app/docs/overview/introduction)
- [Installation](https://immich.app/docs/install/requirements)
- [Roadmap](https://immich.app/roadmap)
- [Demo](#demo)
- [Features](#features)
- [Translations](https://immich.app/docs/developer/translations)
- [Contributing](https://immich.app/docs/overview/support-the-project)

## Demo

Access the demo [here](https://demo.immich.app). The demo is running on a Free-tier Oracle VM in Amsterdam with a 2.4Ghz quad-core ARM64 CPU and 24GB RAM.

For the mobile app, you can use `https://demo.immich.app/api` for the `Server Endpoint URL`

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
| Folder View                                  | No     | Yes |

## Translations

Read more about translations [here](https://immich.app/docs/developer/translations).

<a href="https://hosted.weblate.org/engage/immich/">
<img src="https://hosted.weblate.org/widget/immich/immich/multi-auto.svg" alt="Translation status" />
</a>

## Repository activity

![Activities](https://repobeats.axiom.co/api/embed/9e86d9dc3ddd137161f2f6d2e758d7863b1789cb.svg "Repobeats analytics image")

## Star history

<a href="https://star-history.com/#immich-app/immich&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=immich-app/immich&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=immich-app/immich&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=immich-app/immich&type=Date" width="100%" />
 </picture>
</a>

## Contributors

<a href="https://github.com/alextran1502/immich/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=immich-app/immich" width="100%"/>
</a>
