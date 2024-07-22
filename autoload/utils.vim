
"----------------------------------------------------
" This file contains self-defined Functions and     |
" utilitys.                                         |
"                                                   |
" Date: 2019/05/24                                  |
" Author: Ming Li (adagio.ming@gmail.com)           |
"----------------------------------------------------


"-----------------------------------------------------------------------
" relativenumber toggle function.
"-----------------------------------------------------------------------
function! utils#NumberToggle()
    if &relativenumber
        set norelativenumber nonumber
    else
        set relativenumber  number
    endif
endfunction

"-----------------------------------------------------------------------
" trigger <esc> map/unmap on insert mode.
"-----------------------------------------------------------------------
function! utils#EscMapToggle()
    if get(s:, 'esc_key_mapped', 1)
        iunmap <esc>
        let s:esc_key_mapped = 0
    else
        inoremap <silent> <esc> <esc>l
        let s:esc_key_mapped = 1
    endif
endfunction

"-----------------------------------------------------------------------
" Window size adjustment both vertically and horizontally.
"-----------------------------------------------------------------------
function! utils#AdjustWindowSize(scale, action)
    if a:scale == 'horizontal'
        if a:action == 'less'
            exec 'resize -' .. v:count1
        else
            exec 'resize +' .. v:count1
        endif
    else
        if a:action == 'less'
            exec 'vertical resize -' .. v:count1
        else
            exec 'vertical resize +' .. v:count1
        endif
    endif
endfunction


"-----------------------------------------------------------------------
" Map alt (normaly <Esc>) key as modifier key.
"-----------------------------------------------------------------------
function! utils#TerminalMapAltKey() abort
    if !has('nvim')
        " set alt key combined with a-z, A-Z
        for ascval in range(65, 90) + range(97, 122)
            exec "set <M-" .. nr2char(ascval) .. ">=\<Esc>" .. nr2char(ascval)
        endfor
        " set key response timeout to 50ms, otherwise you can't hit <Esc> in 1 sec
        set ttimeoutlen=25
    endif
endfunction


"-----------------------------------------------------------------------
" Close quickfix window or help window on pressing esc key.
"-----------------------------------------------------------------------
function! utils#OnPressEsc() abort
    let l:winnrs = winnr('$')
    " only handle multiple window cases
    if l:winnrs > 1
        for winnr in range(1, l:winnrs)
            " [untitled] buffer
            if empty(bufname(winbufnr(winnr)))
                exec winnr .. "quit"
                return
            " vim help doc
            elseif getwinvar(winnr, "&ft") == "help"
                exec winnr .. "quit"
                return
            " quickfix window
            elseif win_gettype(winnr) == "quickfix"
                cclose
                return
            " loclist window
            elseif win_gettype(winnr) == "loclist"
                lclose
                return
            endif
        endfor
    endif
endfunction


"-----------------------------------------------------------------------
" On switch to a new tabpage, TabNew event triggered.
"-----------------------------------------------------------------------
function! utils#SwitchTabWin() abort
    let curwinid = win_getid()
    let curtab = tabpagenr()
    let bufwinidlist = win_findbuf(bufnr())
    "close duplicated windows
    for bufwinid in bufwinidlist
        let [ntab, nwin] = win_id2tabwin(bufwinid)
        let winft = gettabwinvar(ntab, nwin, "&ft")
        if !(empty(winft) ||
                    \ ntab == curtab ||
                    \ winft == 'qf' ||
                    \ winft == 'quickfix' ||
                    \ winft == 'help')
            if win_gotoid(bufwinid)
                exec "wincmd c"
            endif
        endif
    endfor
    "iterate all windows
    for ntab in range(1, tabpagenr('$'))
        for nwin in range(1, tabpagewinnr(ntab, '$'))
            " No file type
            if empty(gettabwinvar(ntab, nwin, "&ft"))
                let winid = win_getid(nwin, ntab)
                if win_gotoid(winid)
                    exec "wincmd c"
                endif
            endif
        endfor
        " Close tabpage if it only contains a quickfix window
        if (tabpagewinnr(ntab, '$') == 1)
            let winft = gettabwinvar(ntab, 1, "&ft")
            if winft == 'qf' ||
                    \ winft == 'quickfix' ||
                    \ winft == 'help'
                exec ntab .. "tabclose"
            endif
        endif
    endfor
    " jump back to current window
    if !win_gotoid(curwinid)
        echoerr "window jump back failed, ID:".curwinid
    endif
endfunction


"-----------------------------------------------------------------------
" On openning quickfix window.
"-----------------------------------------------------------------------
function! utils#SetQuickfixOpen()
    exec "botright copen"
    nnoremap <silent> <buffer> h  <C-W><CR><C-w>K
    nnoremap <silent> <buffer> H  <C-W><CR><C-w>K<C-w>b
    nnoremap <silent> <buffer> v  <C-w><CR><C-w>H<C-W>b<C-W>J<C-W>t
endfunction


"-----------------------------------------------------------------------
" Enable block paste.
"-----------------------------------------------------------------------
function! utils#LocalClipboardPaste() abort
    set clipboard-=unnamed
    call feedkeys("p", "t")
    set clipboard+=unnamed
endfunction


"-----------------------------------------------------------------------
" Toggling open/close all folds in local buffer.
"-----------------------------------------------------------------------
function! utils#OpenAllFoldsToggle()
    if &foldenable && &foldlevel
        normal zM
    else
        normal zR
    endif
endfunction


"-----------------------------------------------------------------------
" Tabpage/Window jump.
"-----------------------------------------------------------------------
function! utils#GoToTabWin(target)
    if a:target == 'window'
        exec v:count1 .. "wincmd w"
    elseif a:target == 'tabpage'
        exec "normal" v:count1 .. "gt"
    else
        echomsg 'invalid movement target' .. a:target
    endif
endfunction

"-----------------------------------------------------------------------
" show tab line.
"-----------------------------------------------------------------------
function! utils#DisplayTabLine()
    let l:s = ''
    let l:wn = ''
    let l:t = tabpagenr()
    let l:i = 1
    while l:i <= tabpagenr('$')
        let l:buflist = tabpagebuflist(l:i)
        let l:winnr = tabpagewinnr(l:i)
        let l:s .= '%' . l:i . 'T'
        let l:s .= (l:i == l:t ? '%1*' : '%2*')
        let l:s .= ' '
        let l:wn = tabpagewinnr(l:i,'$')

        let l:s .= (l:i== l:t ? '%#TabNumSel#' : '%#TabNum#')
        let l:s .= l:i
        if tabpagewinnr(l:i,'$') > 1
            let l:s .= '.'
            let l:s .= (l:i== l:t ? '%#TabWinNumSel#' : '%#TabWinNum#')
            let l:s .= (tabpagewinnr(l:i,'$') > 1 ? l:wn : '')
        endif

        let l:s .= ' %*'
        let l:s .= (l:i == l:t ? '%#TabLineSel#' : '%#TabLine#')
        let l:bufnr = l:buflist[l:winnr - 1]
        let l:file = bufname(l:bufnr)
        if getbufvar(l:bufnr, 'buftype') == 'nofile'
            if l:file =~ '\/.'
                let l:file = substitute(l:file, '.*\/\ze.', '', '')
            endif
        else
            let l:file = fnamemodify(l:file, ':p:t')
        endif
        if empty(l:file)
            let l:ft = gettabwinvar(l:i, l:wn, '&ft')
            if l:ft == 'qf' || l:ft == 'quickfix'
                let l:file = '[Quickfix]'
            elseif l:ft == 'netrw' || l:ft == 'nerdtree'
                let l:file = '[Nerdtree]'
            else
                let l:file = '[Untitled]'
            endif
        endif
        let l:s .= l:file
        let l:s .= (l:i == l:t ? '%m' : '')
        let l:i = l:i + 1
    endwhile
    let l:s .= '%T%#TabLineFill#%='
    return l:s
endfunction
