
"-----------------------------------------------------------------------
" Set up winloc plugin.
"-----------------------------------------------------------------------
let g:winloc_enabled = 1     " enable winloc
augroup winloc
    autocmd!
    autocmd WinEnter *  :call winloc#winloc#OnWinEnter()
    autocmd WinClosed * :call winloc#winloc#OnWinClose()
augroup END
nnoremap <silent> <M-i> :call winloc#winloc#JumpWinloc('next')<cr>
nnoremap <silent> <M-o> :call winloc#winloc#JumpWinloc('prev')<cr>
