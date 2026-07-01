# 开发日志 - 2026-07-01

## 背景

用户在 DroidSpaces（Android 上运行 Linux 容器）环境中使用 Plasma Mobile，屏幕键盘（maliit）无法正常工作：
- 桌面搜索、系统设置：键盘弹出后高频闪烁
- 文件管理器、终端：键盘闪一下就消失，手速快能输入一个字符

## 排查过程

### 第一阶段：applyConfigure() 循环修复（最初的方案）

最初的问题分析指向 `inputpanel-shell` 插件的 `applyConfigure()` 每次 configure 事件都调用 `set_toplevel()`，导致与 KWin 形成无限循环。

**修复**：添加 `m_toplevelSet` 标志，只在第一次 configure 时调用 `set_toplevel()`。

**结果**：deb 编译安装成功，但问题依旧。

### 第二阶段：编译问题修复

原始仓库 `Yizhou147/maliit-keyboard-qt6-fix` 存在多个编译问题：

1. **缺少 Qt6Quick 依赖**：`build.sh` 没装 `qt6-declarative-dev`，cmake 报错 `Could NOT find Qt6Quick`
2. **重复协议生成**：`input-panel-unstable-v1` 和 `input-method-unstable-v1` 定义了相同的接口，导致符号重定义
3. **头文件引用错误**：源码 include 了 `qwayland-input-panel-unstable-v1.h`，但该头文件不再生成

逐一修复后编译通过，但安装后键盘问题依旧。

### 第三阶段：定位真正根因

通过 `WAYLAND_DEBUG=1 maliit6-server` 分析 Wayland 协议交互，发现关键事实：

```
Wayland Registry 中：
✅ zwp_text_input_manager_v1
✅ zwp_text_input_manager_v2
✅ zwp_text_input_manager_v3
✅ zwlr_layer_shell_v1
❌ zwp_input_panel_v1  ← 缺失！
```

**根因确认**：KWin 6.6.4 不广播 `zwp_input_panel_v1` 协议。该协议已从 wayland-protocols 1.47+ 中移除。maliit 的 `inputpanel-shell` 插件依赖这个协议来创建键盘 surface，找不到就无法工作。

`applyConfigure()` 的修复完全是在修一个**不会被执行到的代码路径**。

### 第四阶段：用 wlr-layer-shell 替代

研究了以下项目：
- [DroidSpaces](https://github.com/MGHazz/Droidspaces) - Android 上的 Linux 容器运行时
- [Anland](https://github.com/superturtlee/anland) - Wayland on Android 的 buffer-sharing 协议
- [maliit-framework](https://github.com/maliit/framework) - 输入法框架

发现 KWin 6.x 支持 `zwlr_layer_shell_v1`（wlr-layer-shell 协议），可以用来创建 overlay 层的 surface，替代 `input-panel-v1`。

**方案**：完全重写 `inputpanel-shell` 插件，用 `zwlr_layer_shell_v1` 替代 `zwp_input_panel_v1`。

## 实现细节

### 新文件结构

| 文件 | 作用 |
|------|------|
| `qwaylandlayerkeyboard.h/cpp` | 键盘 surface，用 `zwlr_layer_surface_v1` 锚定屏幕底部 |
| `qwaylandlayerkeyboardintegration.h/cpp` | 绑定 `zwlr_layer_shell_v1` 全局对象 |
| `layerkeyboardplugin.cpp` | 插件入口，key 保持 `"inputpanel-shell"` |
| `inputpanelshell.json` | 插件元数据，key 为 `"inputpanel-shell"` |

### 编译问题修复记录

| 问题 | 原因 | 修复 |
|------|------|------|
| `namespace` 关键字冲突 | wlr-layer-shell C 协议头用 `namespace` 做参数名 | 编译前 sed 替换 XML 中 `namespace` → `ns` |
| `qwayland-wlr-layer-shell-unstable-v1.h` 不存在 | ecm 生成的 Qt wrapper 包含了不存在的头文件名 | 用 symlink 指向实际生成的头文件 |
| `global.name` 不存在 | Qt API 使用 `global.id` 而非 `global.name` | 修改源码 |
| `isEmbedded()` / `getPopup()` 不是虚函数 | 该 Qt 版本的 `QWaylandShellSurface` 没有这些方法 | 删除 override |
| `ecm_add_qtwayland_client_protocol` 参数错误 | `$LAYER_SHELL_XML` 是 shell 变量不是 CMake 变量 | 用 Python f-string 传入实际路径 |
| `add_custom_command TARGET` 找不到 | `POST_BUILD` 需要 target 先存在 | 改用 `OUTPUT` 方式 |
| `get_filename_component` 参数错误 | XML 路径传入 CMake 方式不正确 | 修正 Python f-string 变量引用 |

### 关键设计决策

1. **插件 key 保持 `"inputpanel-shell"`**：Qt 靠这个 key 为键盘窗口加载 shell integration，改了就找不到
2. **使用 overlay 层**：`ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY` 确保键盘在所有窗口之上
3. **锚定底部**：`ANCHOR_BOTTOM | ANCHOR_LEFT | ANCHOR_RIGHT` 让键盘横跨屏幕底部
4. **`namespace` 关键字 workaround**：编译前修改 XML，而非修改生成的代码

## 当前状态

- [x] 根因确认：KWin 6.x 不支持 `zwp_input_panel_v1`
- [x] 方案设计：用 `zwlr_layer_shell_v1` 替代
- [x] 代码编写：新的 layer-shell 插件
- [x] 编译问题修复：多个 C++/CMake 兼容性问题
- [ ] 编译通过验证
- [ ] 功能测试：键盘是否正常显示和输入
- [ ] README 和文档

## 相关 commit

| Commit | 描述 |
|--------|------|
| `db12236` | fix: applyConfigure only calls set_toplevel once |
| `befd8bf` | fix: add missing input-panel-unstable-v1.xml protocol |
| `72a36b3` | fix: add missing Qt6Quick and xkbcommon build dependencies |
| `eb3c158` | fix: remove duplicate input-panel protocol generation |
| `62880af` | fix: use input-method-unstable-v1 header instead of input-panel |
| `73ef237` | feat: replace input-panel-v1 with wlr-layer-shell for KWin 6.x |
| `5c341b6` | fix: resolve compilation errors in layer-shell plugin |
| `0e3491f` | fix: create symlink for wlr-layer-shell protocol header |
| `4efbfcc` | fix: use OUTPUT-based custom command for header copy |
| `f516560` | fix: rename namespace to ns in wlr-layer-shell XML before build |
| `aae402c` | fix: correct ecm XML path variable and remove duplicate lines |
