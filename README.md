# 点名助手

一款专为班级骨干（班长、辅导员等）设计的**安卓点名APP**，用 Flutter 构建，Material Design 3 风格。

替代飞书多维表格等工具，让点名操作更快速、更直觉。

## ✨ 功能特性

- 📋 **批量导入** — 从 Excel/Word 复制粘贴，自动识别姓名和学号
- 👆 **滑动点名** — 右滑标记已到，左滑选择其他状态（病假/重修/合唱/上岗等）
- 🔍 **实时搜索** — 按姓名或学号快速查找
- 📊 **实时统计** — 顶部状态卡片，各去向人数一目了然
- 🏷️ **自定义标签** — 预设6种去向标签，支持自由添加
- ↩️ **撤销操作** — 72小时内可撤销误操作
- 📁 **多会话管理** — 每次点名独立记录，支持归档和回溯
- 📈 **出勤统计** — 个人出勤率、群体缺勤排行
- 💾 **纯本地存储** — 无需联网，数据安全

## 🎯 使用场景

- 早自习 / 晚自习点名
- 合唱排练签到
- 勤工俭学上岗考勤
- 任何需要快速清点人员去向的场景

## 🛠 技术栈

| 技术 | 用途 |
|------|------|
| Flutter | 跨平台 UI 框架 |
| Riverpod | 状态管理 |
| Hive | 本地数据存储 |
| Material Design 3 | 设计语言 |

## 📦 构建与安装

本项目通过 **GitHub Actions** 自动构建，无需本地配置 Flutter 环境。

### 下载 APK

1. 进入 [Releases](../../releases) 页面
2. 下载最新版本的 `app-release.apk`
3. 传到安卓手机，安装即可

### 手动构建（可选）

```bash
git clone https://github.com/Everett406/Roll-Call-APP.git
cd Roll-Call-APP
flutter pub get
flutter build apk --release
# APK 位于 build/app/outputs/flutter-apk/app-release.apk
```

## 📱 操作说明

### 点名操作
| 手势 | 操作 |
|------|------|
| 右滑 | 标记为「已到」 |
| 左滑 | 弹出状态选择（病假/迟到/公干等）+ 备注输入 |
| 长按 | 查看该学生历史签到记录 |
| 点击顶部卡片 | 按状态筛选人员 |

### 批量导入人员
1. 进入「设置」→「人员管理」→「导入」
2. 从 Excel 或 Word 复制名单，粘贴到文本框
3. 支持格式：每行一个，`姓名` 或 `姓名 学号`
4. 预览确认后一键导入

## 📂 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── member.dart              # 人员
│   ├── status_tag.dart          # 状态标签
│   ├── session.dart             # 点名会话
│   ├── check_in.dart            # 签到记录
│   └── operation_log.dart       # 操作日志
├── services/
│   └── storage_service.dart     # Hive 本地存储
├── providers/
│   └── app_state.dart           # Riverpod 状态管理
├── screens/                     # 页面
│   ├── home_screen.dart         # 首页（Session列表）
│   ├── session_screen.dart      # 点名操作主界面
│   ├── new_session_screen.dart  # 新建点名
│   ├── member_manager_screen.dart # 人员管理
│   ├── import_screen.dart       # 批量导入
│   ├── tag_manager_screen.dart  # 标签管理
│   ├── member_history_screen.dart # 个人历史
│   └── statistics_screen.dart   # 统计页面
└── widgets/                     # 可复用组件
    ├── filter_chip_bar.dart     # 状态筛选栏
    ├── swipe_person_card.dart   # 滑动点名卡片
    ├── status_bottom_sheet.dart # 状态选择抽屉
    └── undo_bar.dart            # 撤销悬浮条
```

## 📄 License

MIT
