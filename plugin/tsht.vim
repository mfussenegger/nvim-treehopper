if exists('g:nvim_ts_hint_textobject')
  finish
endif
let g:nvim_ts_hint_textobject = 1

function s:setup_highlights()
  hi def link TSNodeUnmatched Comment
  hi! def TSNodeKey gui=reverse cterm=reverse
endfunction

call s:setup_highlights()
augroup TreehopperHighlight
    autocmd!
    autocmd ColorScheme * call s:setup_highlights()
augroup end
