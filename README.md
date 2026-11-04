# 基于神经网络的手势识别交互系统（Ti60F225）

面向 2026 全国大学生嵌入式芯片与系统设计竞赛 FPGA 赛道（易灵思）赛题四的参赛作品源码与约束工程。系统在 Efinix Titanium **Ti60F225** 上实现摄像头采集、神经网络推理、边缘检测、触控交互、语音播报与 HDMI 显示，并在运行时切换**静态识别**与**连续手语**两种模式。

- **器件**：Ti60F225（Timing Model C4）
- **开发工具**：Efinity 2026.1
- **工程入口**：`Ti60_Demo.xml`
- **顶层模块**：`example_top`
- **统一版本标识**：`0x50315501`

## 仓库内容

本仓库按比赛提交要求，仅包含原始源码压缩包：

```
基于神经网络的手势识别交互系统源码.rar
```

下载并解压后即可得到完整工程。压缩包内主要文件：

| 路径 | 说明 |
|---|---|
| `Ti60_Demo.xml` | Efinity 工程文件 |
| `Ti60_Demo.pt.sdc` | 时序约束 |
| `Ti60_Demo.peri.xml` | 管脚与外设配置 |
| `example_top.v` | 顶层模块 |
| `ip/` | IP 源码与配置（DDR、CSI、DSI、FIFO 等） |
| `src/` | 外设与图像处理源码（ISP、HDMI、LVDS、I2C 等） |
| `touch_ui/` | 触控 UI 与 Sobel 边缘检测 |
| `pri/mipi/` | MIPI 接收相关源码 |
| `模型数据/` | 连续网络权重与量化参数 |
| `*.v` / `*.sv` / `*.vh` | 业务 RTL 与头文件 |
| `*.mem` | 模型 ROM、字库、语音等初始化数据 |
| `文件校验.json` | 全部文件的 SHA-256 校验表 |
| `代码说明.txt` | 工程与版本说明 |

## 功能概览

| 模块 | 说明 |
|---|---|
| 视频采集 | MIPI CSI-2 摄像头输入，1920×1080 约 60 fps |
| 视频输出 | HDMI 1920×1080 约 120.24 Hz，YUV420 |
| 静态识别 | 手势、纸面数字、图形识别，CNN 权重固化在片上 ROM |
| 连续手语 | CNN/TCN/CTC 序列识别，模型由上位机加载到 DDR 后由 FPGA 推理 |
| 图像处理 | Bayer 转换、Canny 边缘检测、滤波、实时调色与曝光控制 |
| 交互 | GT911 触控屏、按键、I2S 语音播报、8 秒演示、冻结/回看 |
| 显示 | HDMI OSD 叠加，实时分辨率、采集 fps、输出 Hz 统计 |

上电默认进入**静态模式**，通过触控屏最下方按钮在静态与连续手语之间切换。切换离开连续模式时会取消计算并等待已发出的 DDR 读写结束，不复位视频 DDR。

## 打开与编译

1. 解压 `基于神经网络的手势识别交互系统源码.rar`。
2. 安装 **Efinity 2026.1**。
3. 打开解压目录中的 `Ti60_Demo.xml`。
4. 确认器件为 `Ti60F225`、顶层为 `example_top`。
5. 直接综合、布局布线并生成位流。

工程使用 Efinity 的 **SDC / peri.xml** 约束格式，不包含 Vivado 的 XDC。

## 文件范围说明

- 压缩包包含：RTL 源码（`.v/.sv/.vh`）、IP 生成源码与 `settings.json`、时序/管脚约束、模型与字库/语音初始化数据（`.mem`、`.bin`）。
- 不包含：布局布线结果、综合网表、报告、仿真缓存、`.bit/.hex` 位流、训练照片或训练脚本。
- `ip/DdrCtrl/ddr3_controller.bin` 与 `模型数据/weights_ddr.bin` 是 IP/模型数据文件，不是 FPGA 烧录文件。
- 连续手语模型需要配套上位机加载到 DDR；上位机程序不在压缩包内。
- 静态模型已固化在 ROM 中，上电即可使用。

## 完整性校验

压缩包内的 `文件校验.json` 记录了每个文件的 SHA-256。解压后可在文件所在目录核对：

```bash
python - <<'PY'
import json, hashlib
m = json.load(open('文件校验.json', encoding='utf-8'))
bad = [k for k, v in m.items() if hashlib.sha256(open(k, 'rb').read()).hexdigest() != v]
print('mismatch:', bad or 'none')
PY
```
