# Immich OHOS 待办 / 后续优化

> 2026-08-23 调研整理:HDR 照片显示切换优化(engine 代码在 `F:\flutter_engine_ohos\engine\src`)

## HDR 查看器切换优化(按此顺序做)

现状:切换 HDR/SDR = 整个 Vulkan swapchain 销毁重建(格式 `RGBA8+sRGB ↔ A2B10G10R10+PQ/HLG`),
immich 侧靠"每资产模式缓存 + 解码完成才切 + 未就绪兜底重置 SDR"防闪烁,首看 HDR 图仍有
HDR→SDR→HDR 双跳。

### 1. 引擎:纹理内容补目标色彩空间转换(地基,必做)

- 现状:只有 `solid_color_contents.cc:88-90` 把 `target_color_space` 传入 shader 做转换;
  **`texture_contents.cc` / `tiled_texture_contents.cc`(图片绘制路径)完全没有色彩空间处理**,
  SDR 纹理(sRGB)直接写进按 HLG 解释的缓冲 → 亮度/伽马错误(即"HLG 污染预览")
- 改法:给两个纹理 contents 加同款 target color space 逻辑——SDR 纹理画到 HLG/PQ 表面时做
  sRGB→HLG(OETF)转换;HDR 纹理(1010102 原生)直通。模式照抄 solid color 实现
- 关联:`surface_context_vk.cc` 已有 `GetTargetColorSpaceForSurface`(HLG/PQ→kExtendedSRGB)
  和 swapchain 变化时的 `swapchain_changed_` 机制可复用

### 2. 引擎:is_hdr 提前暴露(依赖第 1 步)

- `ohos_image_generator.cpp:441` 的 `OH_ImageSourceInfo_GetDynamicRange` 在 generator 初始化
  (只读头)阶段就已知 is_hdr,不必等全图解码
- 把该信息在加载开始时暴露给 Dart(ImageInfo 通道或轻量回调),immich 在图片开始加载瞬间
  即切到最终模式,swapchain 重建藏在滑动动画中
- ⚠️ 没有第 1 步的转换,提前切会把 SDR 预览画到 HLG 表面上(污染),不可单独做

### 3. 可选:查看器内常驻 HLG swapchain(终极方案)

- 第 1 步就位后,`enable_hdr` 时 swapchain 常驻 A2B10G10R10+HLG,SDR 内容全部着色器转换,
  切换从"换 swapchain"变成"换 shader 分支",重建闪烁归零
- SDR 内容常驻转换的精度/亮度校准需仔细验证(对比纯 SDR swapchain 显示效果)

### 附:防护项(小改)

- `impeller::Context::hdr_` 为全局单值,图像侧 `SetHdr::initSetHdr` 与视频侧每帧 OHB 探测
  (`ohb_texture_source_vk.cc:86-103`)都写它,图像/视频快速交替时 native 层无 token 保护,
  可能一帧错配——可加代际校验
- 评估 `ViewerHdr.resetModes()`(asset_viewer.page.dart:188,382)进出查看器的两次重建是否可省
