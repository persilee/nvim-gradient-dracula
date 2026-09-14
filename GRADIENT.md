# Gradient nvimpire — 渐变色改造说明

本主题在原版 [nvimpire](https://github.com/colevoss/nvimpire)（Dracula 配色）基础上，
把 VSCode 扩展 [`shaobeichen/gradient-theme`](https://github.com/shaobeichen/gradient-theme)
的渐变视觉移植到了 Neovim。

## 终端里的“渐变”是怎么实现的

VSCode 靠注入 CSS（`background-clip:text` + `linear-gradient`）给**一个单词内部**填充连续
渐变；终端的高亮组一个组只能有一个前景色，做不到像素级连续渐变。因此这里用三种终端可行的
方式还原同一套渐变语言：

| VSCode 里的效果 | Neovim 里的对应实现 |
| --- | --- |
| 每个语法类别一条 `深→亮` 双色渐变、且加粗（`font-weight:700`） | **渐变家族**：一条渐变插值成 11 个色阶，同族的不同高亮（如 `@keyword` / `@keyword.return` / `@keyword.operator`）落在不同色阶，整块代码呈现一条渐变带；主类别取最亮端并加粗 |
| `.mtk1` 默认文本八色彩虹渐变 | **逐字符流动渐变**：用 extmark 给注释（或全部文本）逐字符上八色渐变，见 `flow.lua` |
| `div.cursor` 九色流动光标 | **流动光标**：定时器每 110ms 让光标在九色渐变中循环 |
| 活动标签页四色流动上边框 `#EACD61→#EA618E→#3CEC85→#61AFEA` | **彩虹 UI**：缩进线、当前行号、lualine 分段共用这条四色渐变色带 |

## 四套移植配色

颜色对逐套取自 VSCode 主题的 `src/*/index.css`：

- `dracula`（默认，贴合原 nvimpire 的 Dracula 底色，对应 `gradient-dracula-theme`）
- `monokai`（对应 `gradient-monokai-pro`）
- `firefox`（对应 `gradient-developer-theme-firefox-dark`，语法类别渐变最全）
- `bearded`（对应 `gradient-bearded-theme-arc-woodfishhhh`，最炫，含八色文本/九色光标）

## 配置

```lua
require('nvimpire').setup({
  transparent = false,   -- 原有：透明背景

  -- —— 渐变相关（均为可选，下面是默认值）——
  style = 'dracula',     -- dracula | monokai | firefox | bearded
  steps = 11,            -- 每条渐变插值的色阶数
  bold = true,           -- 渐变语法 token 加粗（对应 VSCode font-weight:700）
  italic_comments = true,
  rainbow_indent = true, -- 缩进线 / 当前行号走彩虹渐变
  animated_cursor = true,-- 九色流动光标
  flow = {
    enabled = true,      -- 逐字符流动渐变
    scope = 'comment',   -- comment=只给注释逐字符渐变 | all=全部文本 | off=关闭
  },
})
vim.cmd('colorscheme nvimpire')
```

## 命令（运行时切换，无需重启）

| 命令 | 作用 |
| --- | --- |
| `:NvimpireGradientStyle monokai` | 切换渐变配色并即时重绘 |
| `:NvimpireGradientFlow all` | 逐字符渐变铺满全部文本（`comment` / `off` 切换） |
| `:NvimpireGradientCursor off` | 关闭/开启流动光标（`on`） |

## 缩进线彩虹渐变

- 旧版 indent-blankline.nvim：直接使用 `IndentBlanklineIndent1..6`（已是彩虹色阶）。
- 新版 ibl.nvim：主题已生成 `@ibl.indent.char.1..N`，可这样启用整条彩虹：

```lua
require('ibl').setup({
  indent = {
    highlight = vim.tbl_map(function(i) return '@ibl.indent.char.' .. i end,
      vim.range(1, 12)),
  },
})
```

## lualine

`lualine.themes.nvimpire` 已改为渐变分段：各段沿渐变色阶分布，模式段 `a` 为实心渐变色，
并随 normal/insert/visual/replace/command 切换主渐变。

## 文件结构

```
lua/nvimpire/
  gradient.lua   # 渐变引擎（颜色插值、色阶、四套移植配色）—— 新增
  flow.lua       # 逐字符流动渐变 + 流动光标（extmark/timer）—— 新增
  colors.lua     # 改为由渐变引擎按 style 生成（保留全部旧颜色键，向后兼容）
  config.lua     # 新增渐变配置项，加载组前重建配色
  init.lua       # 串联加载、注册三个 :NvimpireGradient* 命令
  groups/*.lua   # code/treesitter 渐变家族化，core/indent-blankline 彩虹化
lua/lualine/themes/nvimpire.lua  # 渐变分段状态栏
```

## 备注

- 流动光标依赖终端支持自定义光标颜色（`termguicolors`，已强制开启）；不支持的终端上该效果
  会被忽略，不影响其它渐变。
- 逐字符渐变只渲染当前窗口可见区域（带上下缓冲），并对超长行/总量做了上限，正常编辑无感知
  开销；如机器较慢可 `flow.enabled=false` 或 `scope='comment'`。
- 顺手修复了上游三处颜色键笔误（`c.pruple`、`c.yello`、`c.enum`，原本会解析成 nil）。
