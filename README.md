# MagicRing

一个简洁的 macOS 状态栏性能监测控件。MagicRing 常驻顶部状态栏，鼠标悬停时展开透明磨砂玻璃风格的性能面板，用于快速查看 CPU、内存、磁盘、电池、网络和进程占用情况。

## 功能

- 状态栏实时显示 CPU 占用。
- 悬停展开小型性能面板。
- 支持 CPU、内存、磁盘、电池和网络监测。
- 展示 CPU 历史曲线、内存曲线和网络上下行曲线。
- 展示进程 CPU 与内存占用排行。
- 支持右键菜单切换英文显示。
- 支持多种玻璃风格，包括完全透明玻璃风格。

## 技术栈

- Swift
- SwiftUI
- AppKit `NSStatusItem` / `NSPanel`
- Mach / IOKit / Darwin 系统 API

## 运行

使用 Xcode 打开项目：

```bash
open MagicRing.xcodeproj
```

然后选择 `MagicRing` target 运行即可。

项目当前 macOS Deployment Target 为 `26.4`。

## 目录结构

```text
MagicRing/
├── App/          # AppDelegate、状态栏和面板控制
├── Models/       # 性能数据模型和面板样式模型
├── Services/     # 系统性能采样
├── Utilities/    # 格式化和历史数据工具
├── ViewModels/   # 面板设置和性能监测状态
└── Views/        # SwiftUI 面板视图
```

## 许可

MIT License
