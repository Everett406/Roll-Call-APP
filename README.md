# 点到为止

> 让点名更有诗意

一款专为班级骨干（班长、辅导员等）设计的**安卓点名APP**，用 Flutter 构建，Material Design 3 风格。

替代飞书多维表格等工具，让点名操作更快速、更直觉。

## ✨ 功能特性

- 📋 **批量导入** — 从 Excel/Word 复制粘贴，自动识别姓名和学号
- 👆 **滑动点名** — 右滑标记已到（绿色），左滑选择其他状态（橙色）
- 🔍 **实时搜索** — 按姓名或学号快速查找
- 📊 **实时统计** — 顶部状态卡片，各去向人数一目了然
- 🏷️ **自定义标签** — 自动分配差异化颜色，支持自由添加和编辑
- 🎨 **网格视图** — 姓名学号一目了然，颜色标签直观展示
- ↩️ **撤销操作** — 72小时内可撤销误操作
- 📁 **多会话管理** — 每次点名独立记录，支持归档和回溯
- ⏰ **超时处理** — 12小时提醒，24小时自动归档
- 📈 **出勤统计** — 个人出勤率、群体缺勤排行
- 🔄 **应用内更新** — 检测新版本，系统通知栏下载安装
- 💾 **纯本地存储** — 无需联网，数据安全
- 🌙 **深色模式** — 支持亮色/暗色/跟随系统
- 🎭 **Hero 动画** — 页面切换流畅过渡

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
| Dio | 网络请求（更新检查） |
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
| 右滑 | 标记为「已到」（绿色背景） |
| 左滑 | 弹出状态选择（橙色背景） |
| 长按 | 查看该学生历史签到记录 |
| 点击顶部卡片 | 按状态筛选人员 |

### 网格视图
- 在点名页面右上角菜单中切换"网格视图"
- 每个格子显示姓名和学号后两位
- 背景色根据签到状态变化
- 点击格子弹出标签选择

### 批量导入人员
1. 进入「设置」→「数据管理」→「人员管理」→「导入」
2. 从 Excel 或 Word 复制名单，粘贴到文本框
3. 支持格式：每行一个，`姓名` 或 `姓名 学号`
4. 预览确认后一键导入

### 导出点名结果
1. 在点名页面右上角菜单选择「导出摘要」
2. 可选择是否包含已到达人员
3. 一键复制到剪贴板

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
│   ├── storage_service.dart     # Hive 本地存储
│   └── update_service.dart      # 应用更新
├── providers/
│   ├── app_state.dart           # Riverpod 状态管理
│   └── theme_provider.dart      # 主题管理
├── screens/                     # 页面
│   ├── home_screen.dart         # 首页（Session列表）
│   ├── session_screen.dart      # 点名操作主界面
│   ├── new_session_screen.dart  # 新建点名
│   ├── member_manager_screen.dart # 人员管理
│   ├── group_manager_screen.dart  # 分组管理
│   ├── tag_manager_screen.dart  # 标签管理
│   ├── import_screen.dart       # 批量导入
│   ├── member_history_screen.dart # 个人历史
│   ├── statistics_screen.dart   # 统计页面
│   ├── settings_screen.dart     # 设置页面
│   └── about_screen.dart        # 关于页面
└── widgets/                     # 可复用组件
    ├── filter_chip_bar.dart     # 状态筛选栏
    ├── swipe_person_card.dart   # 滑动点名卡片
    ├── status_bottom_sheet.dart # 状态选择抽屉
    └── undo_bar.dart            # 撤销悬浮条
```

## 🤝 支持开发者

如果您觉得这个应用对您有帮助，欢迎请开发者喝杯咖啡 ☕

## 📄 License

MIT
