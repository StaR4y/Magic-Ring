<img width="150" height="150" alt="MagicRingIcon" src="https://github.com/user-attachments/assets/bedf71fd-7bb0-40ea-b448-b77ad7d04d12" /><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">

# MagicRing

完全免费且开源的 macOS 状态栏性能监测控件。用于快速查看 CPU、内存、磁盘、电池、网络和进程占用情况。


## 功能

- 状态栏实时显示 CPU 占用
- 支持 CPU、内存、磁盘、电池和网络监测
- 展示 CPU 历史曲线、内存曲线和网络上下行曲线
- 展示进程 CPU 与内存占用排行
- 支持多种语言

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

![Alt](https://repobeats.axiom.co/api/embed/7d9db3ff5a2114c3054cfd77ff2399582bacd83f.svg "Repobeats analytics image")

![Stone Badge](https://stone.professorlee.work/api/stone/StaR4y/Magic-Ring)

## 许可

MIT License
