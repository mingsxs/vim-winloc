
"-----------------------------------------------------------------------
" Set up winloc plugin.
"-----------------------------------------------------------------------
let g:winloc_enabled = 1     " enable winloc
augroup winloc
    autocmd!
    autocmd WinEnter *  :call tabwinloc#OnWinEnter()
    autocmd WinClosed * :call tabwinloc#OnWinClose()
augroup END
nnoremap <silent> <M-i> :call tabwinloc#JumpWinloc('next')<cr>
nnoremap <silent> <M-o> :call tabwinloc#JumpWinloc('prev')<cr>
