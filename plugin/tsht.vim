if exists('g:nvim_ts_hint_textobject')
  finish
endif
let g:nvim_ts_hint_textobject = 1

function s:setup_highlights()
  hi! def TSNodeUnmatched guifg=#666666 ctermfg=242
  hi! def TSNodeKey guifg=#ff007c gui=bold ctermfg=198 cterm=bold
endfunction

call s:setup_highlights()
augroup TreehopperHighlight
    autocmd!
    autocmd ColorScheme * call s:setup_highlights()
augroup end
