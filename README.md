---
title: 日語文獻 OCR 校讀
emoji: 📖
colorFrom: yellow
colorTo: red
sdk: docker
app_port: 7860
pinned: false
---

# 日语文献 OCR 校读工具

面向日语及多语言学术文献的本地 OCR、翻译与逐页校读工具。

从 PDF 或扫描图片开始，一站式完成：

> OCR 识别 → 多模型翻译 → 书影/原文/译文三栏校读 → 导出 Word 或 Markdown

本项目首先针对日语学术文献设计，同时支持英语、韩语、中文、法语、德语、拉丁语等源语言。Windows 用户可以双击启动，无需手动配置 Web 服务。

## 功能特点

- **复杂版式 OCR**：调用 PaddleOCR-VL，适合竖排、表格、多栏、页眉页脚等版面。
- **多语言翻译**：支持 Claude、DeepSeek、OpenAI、Gemini，以及 OpenAI 兼容接口。
- **三栏校读**：书影、OCR 原文、译文并排查看；OCR 原文可直接修改并单页重译。
- **书影细节查看**：书影列支持滚轮缩放、按住拖动和平移查看各个角落。
- **逐页增量显示**：OCR 完成后先展示原文，译文完成一页显示一页。
- **进度续接**：可保存 `.review.json` 校读存档，刷新后也可重新连接正在执行的任务。
- **局部处理**：支持 `1-5, 8, 10-15` 形式的页码范围，减少时间与 API 消耗。
- **导入已有文本**：可直接导入 `.md` 或 `.txt`，跳过 OCR，仅做翻译与校读。
- **多种导出**：支持 OCR Markdown、双语 Markdown、校读存档和 Word 对照文档。
- **疑难页图片模式**：无法可靠识别的页面可在 Word 导出时直接嵌入书影。

## 界面与基本流程

1. 展开“API 设置”，填写 PaddleOCR Token 和翻译服务商 API Key。
2. 选择源语言和目标语言。
3. 拖入 PDF、图片、已有 OCR 文本或校读存档。
4. 可选填页码范围，然后点击“开始处理”。
5. 在三栏视图中修改 OCR、检查译文、添加笔记或重译单页。
6. 导出 Word、Markdown，或保存校读进度供下次继续。

## Windows 本地版（推荐）

### 最简单的启动方式

1. 下载并解压整个项目文件夹。
2. 双击 **`开始使用（本地版）.bat`**。
3. 首次启动等待程序自动安装组件，随后浏览器会自动打开。

启动器会自动：

- 在项目内创建独立的 `.venv`，不影响电脑里的其他 Python 项目；
- 安装或更新依赖，遇到失效代理时自动尝试直连和 PyPI 镜像；
- 使用 Waitress 在 `http://127.0.0.1:7860` 启动服务；
- 服务就绪后打开默认浏览器。

工作期间不要关闭黑色启动窗口。完成后关闭该窗口即可停止服务。

### 系统要求

- Windows 10 或 Windows 11；
- Python 3.10 或更高版本；
- 首次启动时需要联网下载 Python 组件；
- 使用 OCR 和云端翻译时需要联网及相应 API 凭据。

如果电脑尚未安装 Python，请从 [Python 官方网站](https://www.python.org/downloads/windows/) 安装，并在安装界面勾选 **Add Python to PATH**。

## 隐私与数据流

本地版默认只监听 `127.0.0.1`，不会向局域网或公网开放。

| 数据 | 去向 | 是否写入本地后端磁盘 |
|---|---|---|
| PaddleOCR Token | 浏览器 → 本机后端 → 百度 PaddleOCR API | 否 |
| 翻译 API Key | 浏览器 → 本机后端 → 所选模型 API | 否 |
| 待 OCR 文件 | 浏览器 → 本机后端 → 百度 PaddleOCR API | 否 |
| 待翻译文本 | 浏览器 → 本机后端 → 所选模型 API | 否 |
| 书影 PDF | 仅在浏览器本地渲染 | 否 |
| 校读自动存档 | 当前浏览器 localStorage | 不经过后端 |

API Key 默认不长期保存。只有明确勾选“在这台电脑的浏览器中记住 API Key”时，才会写入当前浏览器的 localStorage；可随时点击“清除已保存密钥”。

> **注意：本地运行不等于完全离线。** OCR 文件仍会直接发送给百度 PaddleOCR，翻译文本仍会直接发送给所选模型服务商。本地版消除的是 HF Space 或其他公共 Web 服务器这一中转环节。

## API 准备

### PaddleOCR

在 [百度 AI Studio PaddleOCR](https://aistudio.baidu.com/paddleocr/task) 页面申请并复制 Token。

### 翻译模型

按实际使用的服务商填写 Key。项目不会附带或代管任何 API Key，相关费用及数据处理规则由对应服务商决定。

若只需要 OCR，可勾选“仅 OCR，不翻译”，无需填写翻译 Key。

## 开发者运行方式

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
python server.py
```

打开 <http://127.0.0.1:7860>。

Windows 一键启动器使用 Waitress。Linux/Hugging Face Docker 部署使用单 worker 的 Gunicorn：

```bash
gunicorn -w 1 --threads 8 --timeout 1800 -b 0.0.0.0:7860 server:app
```

必须保持单 worker，因为任务状态存储在当前进程内存中；多个 worker 会导致轮询时找不到任务。

## Docker / Hugging Face Spaces

仓库中的 `Dockerfile` 可直接用于 Docker 或 Hugging Face Docker Space：

```bash
docker build -t ja-lit-ocr-reader .
docker run --rm -p 7860:7860 ja-lit-ocr-reader
```

若公开部署，使用者的文件和 API Key 请求会经过部署服务器。对密钥安全要求较高时，建议使用 Windows 本地版。

## 常见问题

### 双击启动后提示没有 Python

安装 Python 3.10 或更高版本，勾选 **Add Python to PATH**，然后重新双击启动文件。

### 首次安装组件失败

确认网络可用后重新双击。启动器会自动继续，并依次尝试当前网络、清除失效代理后的直连，以及 PyPI 镜像。

### 7860 端口被占用

关闭此前启动的本工具黑色窗口，再重新双击。也可检查是否有其他程序正在使用 7860 端口。

### 大文件处理到一半出现 OCR 500

`OCR 服务请求失败，状态码 500` 通常来自 PaddleOCR 云端服务，而不是本地 Key 或浏览器。可先重试；对于数百页文献，建议按 `1-60`、`61-120` 等范围分批处理，避免一次任务失败后整本重来。

### Windows 显示脚本安全提醒

`.bat` 和 `.ps1` 均为可用记事本查看的纯文本启动脚本，只会在项目目录创建 `.venv` 并启动本机网页服务。

## 项目结构

```text
.
├─ index.html                 # 前端界面与校读逻辑
├─ server.py                  # Flask API、OCR/翻译任务和 Word 导出
├─ requirements.txt           # Python 依赖
├─ 开始使用（本地版）.bat      # Windows 双击入口
├─ start-local.ps1            # 环境准备、容错和服务启动
├─ 本地版使用说明.txt          # 面向普通用户的简明说明
├─ Dockerfile                 # Docker / Hugging Face 部署
└─ README.md
```

## 安全提醒

- 不要把 API Key 写入源代码、截图、Issue 或提交记录。
- 不要上传受版权或隐私限制的文献，除非你拥有相应权限。
- 公共电脑上不要勾选“记住 API Key”，使用后点击“清除已保存密钥”。
- 发现安全问题时，请不要在公开 Issue 中粘贴真实 Key 或敏感文献内容。

## 当前限制

- 任务状态保存在内存中，服务关闭后正在运行的任务无法继续；
- PaddleOCR 云端任务失败时，目前需要手动重试或拆分页码范围；
- OCR 与翻译质量受原始扫描、版式和外部模型影响，学术引用前必须人工核对；
- 本项目不提供任何第三方 API 的额度或服务保证。

## 贡献

欢迎提交问题报告和改进建议。提交前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

本项目采用 [MIT License](LICENSE)。你可以使用、修改和再发布代码，但须保留原版权与许可声明。

## 致谢

OCR 能力由百度 PaddleOCR-VL 提供。项目参考并使用了 [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) 相关服务与生态。

本工具仅用于合法的学术研究、阅读与文献整理。请自行遵守著作权、隐私及第三方 API 服务条款。
