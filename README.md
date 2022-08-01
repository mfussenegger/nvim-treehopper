# TSHT (Treesitter hint textobject)


Plugin that provides region selection using hints on the abstract syntax tree of a document.
This is intended to be used for pending operator mappings.

![Demo](https://user-images.githubusercontent.com/38700/121786551-b5d92b80-cbc0-11eb-81f4-180e6d4c71e3.gif)


## Requirements

- Requires [Neovim HEAD/Nightly][1]
- A treesitter parser for each language you plan to use the plugin with.
  - Parsers can be installed via [nvim-treesitter][4] `TSInstall`
  - For manual installation, you need to compile the language specific parsers using `gcc` and place the object files into `~/.config/nvim/parser`.
- `locals` queries for each language you plan to use the plugin with.
  - [nvim-treesitter][4] ships locals queries for many languages. If you've it installed they'll be picked up.
  - You can install them manually by placing `locals.scm` query files into `~/.config/nvim/queries/<language>/`


## Installation

- nvim-ts-hint-textobject is a plugin. Install it like any other neovim plugin:
  - If using [vim-plug][2]: `Plug mfussenegger/nvim-ts-hint-textobject`
  - If using [packer.nvim][3]: `use mfussenegger/nvim-ts-hint-textobject`


## Usage


### Selecting a region

Define two mapppings:

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
