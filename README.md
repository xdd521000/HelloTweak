# 小叮当（微信增强插件）

> 适配设备：iPhone 14 Pro Max · iOS 16.2 · Dopamine（rootless 越狱）

## 这是什么

微信增强插件，所有功能入口都在「微信 → 我 → 设置」里，**不弹窗**。

## 当前功能（v0.0.6）

- 微信设置页加入「🔔 小叮当」入口
- 「微信防撤回」开关：可随时开关，自动记住设置（默认关）

## 打包方式（手动触发）

- 本项目打包是**手动触发**：改完代码不会自动打包
- 需要出包时：仓库 Actions → Build HelloTweak → Run workflow
- 产物：Actions 里的 HelloTweak-deb 安装包（.deb）

## 关键文件

| 文件 | 作用 |
| --- | --- |
| Tweak.x | 插件逻辑（设置页入口 + 防撤回开关） |
| Makefile | 编译配置（rootless、arm64/arm64e） |
| control | 包信息（包名 com.yourname.hellotweak，显示名 小叮当） |
| HelloTweak.plist | 生效范围：微信（com.tencent.xin） |
| .github/workflows/build.yml | 云端打包脚本（手动触发） |

## 开发记录

### v0.0.6（当前）
- 去掉弹窗
- 微信设置页加入「小叮当」入口（Hook NewSettingViewController + MMTableViewInfo 注入）
- 加入防撤回开关（NSUserDefaults 持久化）
- 打包改为手动触发

### v0.0.5
- 弹窗加入「版本体检」：显示微信版本 + 防撤回接口是否就绪

### v0.0.4
- 插件改名「小叮当」

### v0.0.3
- 加入防撤回（Hook CMessageMgr onRevokeMsg）

### v0.0.2
- 改为微信版插件（生效范围 com.tencent.xin）

### v0.0.1
- 第一个插件：打开「设置」时弹窗

## 待解决问题

- [ ] 微信设置页「小叮当」入口在部分微信版本上不显示
  - 原因：微信更新后内部接口可能变化
  - 当前注入方式：NewSettingViewController reloadTableData + MMTableViewInfo
  - 备选方案：换成 WCTableViewManager / 其他注入方式（需要知道具体微信版本号）
