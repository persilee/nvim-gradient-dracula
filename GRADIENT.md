# Gradient Dracula — 渐变主题说明

在原版 [nvimpire](https://github.com/colevoss/nvimpire)（Dracula 配色）基础上，复刻 VSCode 扩展
[`shaobeichen/gradient-theme`](https://github.com/shaobeichen/gradient-theme) 中
**Gradient Dracula Theme** 的核心效果。

## 核心效果：词内逐字母渐变（intra-word gradient）

VSCode 用 `background-clip:text` + `linear-gradient`，让**一个单词内部**从第一个字母到最后一个
字母连续地由深到浅，例如 `colorscheme` 首字母是深绿、尾字母是亮绿。

终端的高亮组一个组只能有一个颜色，无法做像素级连续渐变。本主题用 Neovim 的 extmark 逐字符上色
来等价实现：

1. 用 treesitter 的 highlights query 定位当前可见区域里每一个**彩色词**（关键字 / 函数名 /
   字符串 / 数字 / 类型 / 参数 / 标签）的边界和语义类别；
2. 对词内第 i 个字母，按它在词中的位置 `t = i / (n-1)`，用该类别的「深色端 → 浅色端」做插值
   `mix(deep, bright, t)`；
3. 给每个字母设置一个单字符 extmark（priority 高于 treesitter），于是整个词从首字母的深色
   平滑过渡到尾字母的亮色。

Dracula 各语义类别的渐变对（深 → 浅）：

| 类别 | deep | bright | 例子 |
| --- | --- | --- | --- |
| keyword 关键字/语句 | `#C23594` | `#FF79C6` | `local` `function` `if` `return` |
| function 函数/方法 | `#11998E` | `#50FA7B` | 函数调用名 |
| string 字符串 | `#C9E34B` | `#F1FA8C` | `"dracula"` |
| type 类型 | `#2EC5E6` | `#8BE9FD` | 类型名 |
| constant/number 常量数字 | `#8B5CF6` | `#BD93F9` | `42` `true` |
| parameter 参数 | `#FF7A3D` | `#FFB86C` | 函数参数 |
| tag 标签 | `#FF61D2` | `#FE908F` | HTML/XML tag |

普通变量名、标点、运算符保持正常前景色，不做渐变，避免整屏发花。没有 treesitter parser 时会
退化为基于 Vim 语法高亮的分段渐变；含中文等多字节字符的词不会被逐字节拆开（保留正常高亮）。

渲染只处理当前窗口可见行（带上下缓冲）并做了长度/总量上限，配合防抖，正常编辑无明显开销。

## 安装（lazy.nvim）

```lua
{
  "persilee/nvim-gradient-dracula",
  name = "gradient_dracula",
  lazy = false,
  priority = 1000,
  opts = {
    transparent_bg = true,                        -- = transparent，主编辑区透明
    style = "dracula",                            -- 主打 dracula（另含 monokai/firefox/bearded）
    terminal_colors = true,                       -- 同步内置终端 g:terminal_color_*
    italic_comment = true,                        -- = italic_comments
    flow = { enabled = true, comments = false },  -- 词内渐变开关；comments=true 连注释也灰阶渐变
  },
}
```

> 若出现 `Lua module not found for config ... use a config()`：lazy 会按插件名自动找主模块，
> 本主题已内置 `gradient_dracula` / `nvim-gradient-dracula` 门面模块；也可显式写
> `main = "nvimpire"`，或用 `config = function(_, o) require("nvimpire").setup(o) end`。

## 配置项

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `style` | `'dracula'` | 配色：dracula / monokai / firefox / bearded |
| `flow.enabled` | `true` | 词内逐字母渐变总开关 |
| `flow.comments` | `false` | 注释是否也做灰阶渐变 |
| `bold` | `true` | 渐变词加粗（对应 VSCode 的 font-weight:700） |
| `animated_cursor` | `true` | 九色流动光标（110ms 循环） |
| `rainbow_indent` | `true` | 缩进线 / 当前行号彩虹渐变 |
| `transparent`（别名 `transparent_bg`） | `false` | 透明背景 |
| `italic_comments`（别名 `italic_comment`） | `true` | 注释斜体 |
| `terminal_colors` | `true` | 同步内置终端配色 |
| `steps` | `11` | 静态渐变色阶数 |

## 命令

| 命令 | 作用 |
| --- | --- |
| `:NvimpireGradientFlow on\|off` | 开/关词内逐字母渐变（无参数=切换） |
| `:NvimpireGradientStyle <name>` | 运行时切换配色 |
| `:NvimpireGradientCursor on\|off` | 开/关流动光标 |

## 文件结构

```
lua/nvimpire/
  gradient.lua   # 颜色插值引擎 + 各配色的深/浅渐变对
  flow.lua       # 词内逐字母渐变（treesitter + extmark）与流动光标
  colors.lua     # 由渐变引擎生成调色板（保留全部旧颜色键，向后兼容）
  groups/*.lua   # 静态高亮：词尾亮色端，作为渐变的落点与无 parser 时的回退
```

## 测试

```bash
nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/word_gradient_spec.lua" -c "qa!"
nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/gradient_spec.lua" -c "qa!"
nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/lazy_path_spec.lua" -c "qa!"
```
