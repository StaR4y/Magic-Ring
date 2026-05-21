<img width="150" height="150" alt="MagicRingIcon" src="https://github.com/user-attachments/assets/a1b5711d-3a8b-4e68-a4fe-1500e2e1297f" /><img width="150" height="150" alt="MagicRingIcon" src="https://github.com/user-attachments/assets/35fdd721-4ed9-48f2-bf66-c2d504513fe2" />
# MagicRing

![Uplo<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">
  <title id="title">MagicRing Icon</title>
  <desc id="desc">A frosted glass ring surrounding a CPU mark.</desc>
  <defs>
    <radialGradient id="ambientGlow" cx="50%" cy="47%" r="58%">
      <stop offset="0%" stop-color="#8FF7FF" stop-opacity="0.34"/>
      <stop offset="48%" stop-color="#4EDAFF" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#071524" stop-opacity="0"/>
    </radialGradient>

    <linearGradient id="glassRing" x1="93" y1="70" x2="421" y2="443" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#E8FDFF" stop-opacity="0.24"/>
      <stop offset="24%" stop-color="#B8F4FF" stop-opacity="0.16"/>
      <stop offset="54%" stop-color="#48DFFF" stop-opacity="0.11"/>
      <stop offset="76%" stop-color="#D7FBFF" stop-opacity="0.15"/>
      <stop offset="100%" stop-color="#37CFFF" stop-opacity="0.08"/>
    </linearGradient>

    <linearGradient id="ringStroke" x1="104" y1="86" x2="410" y2="421" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.92"/>
      <stop offset="42%" stop-color="#A6F3FF" stop-opacity="0.50"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.22"/>
    </linearGradient>

    <linearGradient id="chipFill" x1="164" y1="151" x2="350" y2="355" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#F9FFFF" stop-opacity="0.88"/>
      <stop offset="46%" stop-color="#BDF2FF" stop-opacity="0.58"/>
      <stop offset="100%" stop-color="#4E6B7E" stop-opacity="0.40"/>
    </linearGradient>

    <linearGradient id="pinStroke" x1="140" y1="142" x2="374" y2="372" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#F8FFFF" stop-opacity="0.88"/>
      <stop offset="100%" stop-color="#78E9FF" stop-opacity="0.42"/>
    </linearGradient>

    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="22" stdDeviation="24" flood-color="#001323" flood-opacity="0.42"/>
    </filter>

    <filter id="frostedRing" x="-12%" y="-12%" width="124%" height="124%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="0.7" result="softGlass"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.92" numOctaves="2" seed="14" result="grain"/>
      <feColorMatrix in="grain" type="matrix" values="
        0 0 0 0 1
        0 0 0 0 1
        0 0 0 0 1
        0 0 0 .17 0" result="fineGrain"/>
      <feComposite in="fineGrain" in2="softGlass" operator="in" result="grainInside"/>
      <feBlend in="softGlass" in2="grainInside" mode="screen"/>
    </filter>

    <filter id="innerGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="9" result="blur"/>
      <feColorMatrix in="blur" type="matrix" values="
        0 0 0 0 0.21
        0 0 0 0 0.88
        0 0 0 0 1
        0 0 0 .65 0"/>
    </filter>

    <clipPath id="ringClip" clipPathUnits="userSpaceOnUse">
      <path fill-rule="evenodd" d="M256 54a202 202 0 1 0 0 404 202 202 0 0 0 0-404Zm0 78a124 124 0 1 1 0 248 124 124 0 0 1 0-248Z"/>
    </clipPath>
  </defs>

  <rect width="512" height="512" fill="none"/>
  <circle cx="256" cy="256" r="238" fill="url(#ambientGlow)"/>

  <g filter="url(#softShadow)">
    <path fill-rule="evenodd" d="M256 54a202 202 0 1 0 0 404 202 202 0 0 0 0-404Zm0 78a124 124 0 1 1 0 248 124 124 0 0 1 0-248Z" fill="url(#glassRing)" opacity="0.58" filter="url(#frostedRing)"/>
    <path fill-rule="evenodd" d="M256 54a202 202 0 1 0 0 404 202 202 0 0 0 0-404Zm0 78a124 124 0 1 1 0 248 124 124 0 0 1 0-248Z" fill="none" stroke="url(#ringStroke)" stroke-width="5"/>
  </g>

  <g clip-path="url(#ringClip)">
    <path d="M146 103c40-31 94-42 145-31" fill="none" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round" opacity="0.36"/>
    <path d="M348 404c-38 27-89 38-137 28" fill="none" stroke="#55E6FF" stroke-width="20" stroke-linecap="round" opacity="0.18"/>
    <path d="M386 134c39 42 51 101 35 154" fill="none" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.22"/>
  </g>

  <circle cx="256" cy="256" r="98" fill="#001727" opacity="0.22" filter="url(#innerGlow)"/>

  <g transform="translate(0 2)" filter="url(#softShadow)">
    <rect x="176" y="176" width="160" height="160" rx="34" fill="#071C2E" opacity="0.62"/>
    <rect x="176" y="176" width="160" height="160" rx="34" fill="url(#chipFill)" opacity="0.68"/>
    <rect x="198" y="198" width="116" height="116" rx="22" fill="#071624" opacity="0.44" stroke="#F3FFFF" stroke-opacity="0.48" stroke-width="4"/>

    <g stroke="url(#pinStroke)" stroke-width="9" stroke-linecap="round">
      <path d="M204 158v25M230 156v25M256 154v25M282 156v25M308 158v25"/>
      <path d="M204 329v25M230 331v25M256 333v25M282 331v25M308 329v25"/>
      <path d="M158 204h25M156 230h25M154 256h25M156 282h25M158 308h25"/>
      <path d="M329 204h25M331 230h25M333 256h25M331 282h25M329 308h25"/>
    </g>

    <g stroke="#ECFFFF" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" opacity="0.92">
      <path d="M228 242h56"/>
      <path d="M228 270h56"/>
      <path d="M242 228v56"/>
      <path d="M270 228v56"/>
    </g>

    <circle cx="228" cy="228" r="6" fill="#FFFFFF" opacity="0.78"/>
    <circle cx="284" cy="284" r="6" fill="#77F0FF" opacity="0.72"/>
  </g>
</svg>
ading MagicRingIcon.svg…]()



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

<img width="740" height="1140" alt="image" src="https://github.com/user-attachments/assets/6dc8d3b7-1144-440d-8712-0e08d5afb13e" />

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
