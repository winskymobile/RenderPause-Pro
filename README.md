# RenderPause Pro

**解决 macOS 闲时 GPU 占用过高** 的菜单栏工具。

很多应用（Electron、自绘 UI、自定义 Metal 等）在你已经不用、窗口被挡住时，仍会让系统 **WindowServer** 持续合成，GPU 居高不下，带来发热、风扇和掉电。RenderPause Pro 只对你**主动加入名单**的应用，在「离开前台 + 完全遮挡 + 达到设定秒数」后自动**隐藏**，压低闲时合成开销；切回即恢复。

| 项目 | 说明 |
|------|------|
| 版本 | v1.0.0 |
| 系统 | macOS 26+ · Apple Silicon |
| 形态 | 菜单栏常驻（无 Dock 图标） |
| 策略 | 默认仅「隐藏」（不注入、不挂起进程） |

完整说明 → **[docs/USER-GUIDE.md](docs/USER-GUIDE.md)**

---

## 要解决的问题

| 现象 | 常见原因 |
|------|----------|
| 什么都没干，GPU / WindowServer 仍偏高 | 后台窗口图层仍在被合成 |
| 笔记本发热、风扇转、续航变差 | 统一内存上合成与 App 互相传导 |
| Pencil、腾讯文档、Discord 等「挂着不用也费电」 | 静止时仍占用渲染/合成路径 |

你无法像在 Windows 上那样直接挂钩第三方 Metal 循环（SIP / 驱动边界）。本工具走**系统合法路径**：隐藏窗口 → 系统停止对其图层的持续合成 → 闲时 GPU 下来。

**验证过的有效手段：** 非活跃时最小化/隐藏，WindowServer 负载可明显下降。产品把这件事做成「设一次就忘」的后台服务。

---

## 怎么用（30 秒）

1. 运行 App，点菜单栏图标 → **打开 RenderPause Pro**  
2. **添加**需要管的应用（仅名单内生效）  
3. 确认 **启用监控**，按需改 **触发时间**（默认 30 秒）  
4. 把名单应用丢到后面并完全挡住，等阈值 → 自动隐藏  
5. `Cmd+Tab` 切回 → 立即恢复  

**菜单栏：** 状态 · 暂停/恢复监控 · 名单（✓ / 状态字）· 打开窗口 · 退出  

**偏好窗：** 左：通用 + 最近活动 · 右：应用名单（状态 + 垃圾桶移除）

---

## 何时才会动手（防误伤）

同时满足才隐藏：

1. 在名单且已启用  
2. 监控总开关打开  
3. 不是常规前台  
4. 窗口**完全遮挡**（露出一点也不藏）  
5. 持续达到触发秒数  
6. 不是分屏搭档保护对象  

输入法/本工具前台不会误判你的工作窗。

---

## 构建

```bash
cd "/path/to/RenderPause Pro"
xcodegen generate   # 改过 project.yml 时
xcodebuild -scheme RenderPausePro -destination 'platform=macOS' -configuration Debug build
xcodebuild -scheme RenderPausePro -destination 'platform=macOS' -configuration Debug test
```

安装示例：

```bash
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/RenderPausePro-*/Build/Products/Debug/RenderPausePro.app | head -1)
pkill -x RenderPausePro 2>/dev/null || true
cp -R "$APP" /Applications/RenderPausePro.app
open /Applications/RenderPausePro.app
```

---

## 权限

| 能力 | 权限 |
|------|------|
| 隐藏（当前默认，主路径） | **不需要**辅助功能 |
| 最小化（代码保留，界面默认关闭） | 需辅助功能 |
| 登录时启动 | 系统登录项 |
| 遮挡 / 前台检测 | 公开 API，无需「输入监控」 |

不注入第三方进程，不读应用内数据。

---

## 文档

| 文档 | 内容 |
|------|------|
| [docs/USER-GUIDE.md](docs/USER-GUIDE.md) | 问题背景、使用、规则、排障（完整说明） |

---

## 不做的事

- 挂钩 / 修改第三方 Metal Command Buffer  
- `SIGSTOP` 挂起进程  
- 未加入名单的「全家桶清理」  
- 夸张「已省电 xx%」仪表盘  

---

私有项目 · Copyright © 2026 · [GitHub](https://github.com/winskymobile/RenderPause-Pro)
