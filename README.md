# Treehopper 🐇

Syntax trees + hop = Treehopper

A Plugin that provides region selection using hints on the abstract syntax tree of a document.

![Demo](https://user-images.githubusercontent.com/38700/121786551-b5d92b80-cbc0-11eb-81f4-180e6d4c71e3.gif)


## Requirements

- Neovim 0.7.2+

Treehopper operates on syntax trees. It uses tree-sitter to retrieve the tree
if a parser is available, otherwise it tries to use the built-in LSP client in
Neovim (using the `selectionRange` functionality).

You can install tree-sitter parsers either via:

- [nvim-treesitter][4] `TSInstall`
- Manually: You need to download and compile the language specific parsers
  using `gcc` and place the object files into `~/.config/nvim/parser`. See
  http://tree-sitter.github.io/tree-sitter/


## Installation

- Install it like any other neovim plugin:
  - If using [vim-plug][2]: `Plug mfussenegger/nvim-treehopper`
  - If using [packer.nvim][3]: `use mfussenegger/nvim-treehopper`


## Usage


### Selecting a region

Define two mappings:

```
omap     <silent> m :<C-U>lua require('tsht').nodes()<CR>
xnoremap <silent> m :lua require('tsht').nodes()<CR>
```

You can configure which keys are used for hint labels, the first N characters will be taken from the `hint_keys` and then after that it will restart from `a-zA-Z`

```
require("tsht").config.hint_keys = { "h", "j", "f", "d", "n", "v", "s", "l", "a" }
```

### Moving

Moving depends on [hop.nvim][5]

If you want to move to the start or end of a syntax node you can use
`require('tsht').move({ side = "start" })`.

The parameter is optional and defaults to `start`. Use `side = "end"` if you
want to move to the end of a node.


## Credits

- [hop.nvim][5]


[1]: https://github.com/neovim/neovim/releases/tag/nightly
[2]: https://github.com/junegunn/vim-plug
[3]: https://github.com/wbthomason/packer.nvim
[4]: https://github.com/nvim-treesitter/nvim-treesitter
[5]: https://github.com/phaazon/hop.nvim
