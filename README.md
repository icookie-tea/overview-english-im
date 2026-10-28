# Overview English Input

GNOME Shell 50 扩展：打开 overview（Super / 活动 / 手势）时自动切到英文输入源，
回到桌面时恢复打开前的输入源。这样在总览里搜索时不用先按一次 Shift。

## 行为

- `overview` 的 `showing`：记住当前输入源，切换到配置的英文布局（`xkb us`）。
- `overview` 的 `hidden`：如果当前输入源仍是扩展切过去的那个，就恢复；用户中途手动
  切换过则不回滚。
- 启用 `org.gnome.desktop.input-sources per-window` 时扩展自动闭嘴，交给 GNOME 自己
  按窗口切换。

## 安装

```bash
./install.sh          # 复制安装
./install.sh --dev    # 符号链接，改代码后注销重登即可
./install.sh --uninstall
```

NixOS 上 `glib-compile-schemas` 在 glib 的 `-dev` 输出里，脚本会自动去 nix store 找；
找不到时：

```bash
nix shell nixpkgs#glib.dev -c bash ./install.sh
```

新装的 UUID 运行中的 shell 扫不到，需要注销重登一次。

## 设置

`gnome-extensions prefs overview-english-im@icookie`（或扩展应用里的齿轮）：

- **English input source**：切到哪个 XKB 布局，默认 `us`
- **Restore on exit**：退出总览时是否恢复
- **Debug logging**：把切换决策写进 journal，`journalctl --user -f | grep overview-english-im`

## 实现备注

- 切输入源走 shell 内部的 `InputSourceManager.activateInputSource(source, false)`，
  它同时处理键盘布局与 IBus 引擎，状态栏图标也同步；第二个参数 `false` 表示不写 MRU。
- 调 IBus D-Bus（`SetGlobalEngine`）或直接改 `input-sources current` 都会让
  `InputSourceManager` 的内部状态与状态栏脱节，所以不用。
- `inputSources` 是按索引的对象而不是数组，取列表要 `Object.values()`。
- 切换本身是异步的（`set_global_engine_async`），刚进总览立刻打字可能仍有几十毫秒
  的延迟，和 GNOME 自己的 `Super+Space` 一样。
