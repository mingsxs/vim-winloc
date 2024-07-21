" check for vim event support.
if !(has('timers') && exists('##WinEnter') && exists('##WinClosed'))
    echomsg "Error: winloc requires feature `timers` and events #WinEnter, #WinClosed support."
    finish
endif

" global vars
"let s:windows = [1000]
let s:winloc_fifo = [1000]
let s:winloc_cursor = 0
let s:winloc_switch = 0
let s:winloc_redirect = 0
let s:winloc_update_timer = -1
let s:thread_lock = 0
let g:winloc_trace_log = []

" enable debug trace info
function! s:LogTrace(msg)
    if get(g:, 'winloc_trace_enabled', 0)
        call add(g:winloc_trace_log, a:msg)
    endif
endfunction

" collect all opened window IDs as list
function! s:GetAllWinIDs()
    let winids = []
    " iterate through all tabpages
    for tabpage in range(1, tabpagenr('$'))
        " iterate through all windows within tabpage
        for window in range(1, tabpagewinnr(tabpage, '$'))
            call add(winids, win_getid(window, tabpage))
        endfor
    endfor
    return winids
endfunction

function! winloc#winloc#DebugShow()
    echomsg "window ids all:".join(s:GetAllWinIDs(), ', ')
    echomsg "winloc fifo length: ".get(g:, 'winloc_fifo_len', 'default-16')
    echomsg "winloc fifo: ".join(s:winloc_fifo, ', ')
    echomsg "winloc cursor: ".s:winloc_cursor
    echomsg "winloc redirect flag:".s:winloc_redirect
endfunction

" add new window ID
"function! winloc#winloc#OnWinCreate() abort
"    if get(g:, 'winloc_enabled', 1)
"        call add(s:windows, win_getid())
"    endif
"endfunction

" update winloc fifo after an opened window is closed.
function! winloc#winloc#OnWinClose() abort
    " winloc needs to be enabled
    if get(g:, 'winloc_enabled', 1)
        " WinClosed autocmd will store the closed Win-ID in <amatch> & <afile>
        " and also the closed window info is still retrievable
        let closed_win = str2nr(expand('<amatch>'))
        let wt = win_gettype(closed_win)
        call s:LogTrace("Closing Window: ".closed_win.", window type: ".(empty(wt)? "normal buffer" : wt))
        " Acquire Lock
        while s:thread_lock | endwhile
        let s:thread_lock = 1
        " check if existed in the winloc fifo
        if closed_win && index(s:winloc_fifo, closed_win) >= 0
            " only track following window types:
            "   1. normal window
            "   2. quickfix window
            "   3. loclist window
            if empty(wt) || wt == "quickfix" || wt == "loclist"
                let cursor = 1
                while cursor < len(s:winloc_fifo)
                    let cursorwin = get(s:winloc_fifo, cursor)
                    " remove closed window from fifo
                    if cursorwin == closed_win
                        call remove(s:winloc_fifo, cursor)
                        if cursor < s:winloc_cursor
                            let s:winloc_cursor -= 1
                        elseif cursor == s:winloc_cursor
                            let curwin_closed = 1
                        endif
                    " remove consecutive duplicated windows from fifo
                    elseif cursorwin == get(s:winloc_fifo, cursor - 1)
                        call remove(s:winloc_fifo, cursor)
                        if cursor < s:winloc_cursor
                            let s:winloc_cursor -= 1
                        elseif cursor == s:winloc_cursor
                            let s:winloc_cursor = cursor - 1
                        endif
                    else
                        let cursor += 1
                    endif
                endwhile
                " currently opened quickfix window is closed
                " a WinEnter event will be triggered soon
                if get(l:, "curwin_closed")
                    call s:LogTrace("Closing current window")
                    if wt == 'quickfix' || wt == 'loclist'
                        call s:LogTrace("Current window is quickfix or loclist window")
                        let s:winloc_cursor -= 1
                        let s:winloc_redirect = 1
                        call s:LogTrace("skip next WinEnter event, directly jump back to previous window")
                    else
                        call s:LogTrace("Current window is normal window")
                        " set the cursor to floating state
                        let s:winloc_cursor = len(s:winloc_fifo)
                    endif
                endif
            endif
        endif
        let s:thread_lock = 0
    endif
endfunction

function! s:PostWinEventCheck() abort
    " in some unknown cases, the previous Winter/BufEnter doesn't work on current window
    " refresh the related autocmd/augroups.
    function! WinEventDelayCheck(timer) abort
        if !&cursorcolumn && !&cursorline
            let s:winloc_switch = 1
            call s:LogTrace("do au WinEnter")
            doautocmd WinEnter *
            let s:winloc_switch = 0
            if tabpagenr() != tabpagenr("#")
                call s:LogTrace("do au TabEnter")
                doautocmd TabEnter *
            endif
            if !empty(bufname())
                call s:LogTrace("do au BufEnter")
                doautocmd BufEnter *
            endif
        endif
    endfunction
    " start window event check with delay timer and repeat
    call timer_start(200, 'WinEventDelayCheck', {'repeat': 3})
endfunction

" append new window id to the winloc fifo and update the winloc cursor.
" This updater works as a delayed timer function
function! s:AppendWinloc(winid, ...)
    if !empty(getwininfo(a:winid))
        let iprev = get(a:000, 0, 0) - 1
        " previous window is not changed
        if get(s:winloc_fifo, iprev) == a:winid
            call s:LogTrace("previous window is not changed, no append")
            let s:winloc_cursor = iprev < 0 ? iprev + len(s:winloc_fifo) : iprev
            return
        endif
        if empty(a:000) || a:000[0] >= len(s:winloc_fifo)
            call s:LogTrace("Append window:".a:winid)
            call add(s:winloc_fifo, a:winid)
            let s:winloc_cursor = len(s:winloc_fifo) - 1
        else
            call s:LogTrace("Insert window:".a:winid." to index:".a:000[0])
            call insert(s:winloc_fifo, a:winid, a:000[0])
            let s:winloc_cursor = a:000[0]
        endif
        if len(s:winloc_fifo) > get(g:, 'winloc_fifo_len', 16)
            let s:winloc_fifo = s:winloc_fifo[1:]
            let s:winloc_cursor -= 1
        endif
    else
        echomsg "Append invalid window:".a:winid
    endif
endfunction

" timer function to append current window to winloc fifo on WinEnter.
function s:WinlocUpdateOnEnter(timer) abort
    let wt = win_gettype()
    let curwin = win_getid()
    call s:LogTrace("Window Entered:".curwin.", window type:".(empty(wt)? "normal buffer" : wt))
    "Acquire Lock
    while s:thread_lock | endwhile
    let s:thread_lock = 1
    let lastwin = get(s:winloc_fifo, s:winloc_cursor)
    " entering the same window, skip
    if curwin != lastwin && (empty(wt) || wt == "quickfix" || wt == "loclist")
        " only track following window types:
        "   1. normal window, append to fifo end
        "   2. quickfix window, append to current cursor
        "   3. loclist window, append to current cursor
        if empty(wt)
            if lastwin && lastwin != get(s:winloc_fifo, -1)
                " determine the windows that needs to be shifted to the end
                let move_start = s:winloc_cursor
                while move_start > 0 && !empty(win_gettype(s:winloc_fifo[move_start]))
                    let move_start -= 1
                endwhile
                while move_start <= s:winloc_cursor
                    let winmove = remove(s:winloc_fifo, move_start)
                    let s:winloc_cursor -= 1
                    if winmove != get(s:winloc_fifo, -1)
                        call add(s:winloc_fifo, winmove)
                    endif
                endwhile
                " remove consecutive duplicate
                while get(s:winloc_fifo, move_start) && get(s:winloc_fifo, move_start) == get(s:winloc_fifo, move_start-1)
                    call remove(s:winloc_fifo, move_start)
                endwhile
                call s:LogTrace("After shift, winloc fifo:".join(s:winloc_fifo, ", "))
            endif
            " append current window only if it's not the latest
            call s:AppendWinloc(curwin)
        else
            " entering quickfix window and loclist window
            call s:AppendWinloc(curwin, s:winloc_cursor+1)
        endif
        " window au event post check
        call s:PostWinEventCheck()
    endif
    let s:thread_lock = 0
endfunction

" handler for updating winloc fifo on event #WinEnter with delay timer.
" the default delay is 25 ms which can be specified with g:winloc_update_delay.
function! winloc#winloc#OnWinEnter() abort
    " winloc needs to be enabled and shuold be doing winloc jumping
    if get(g:, 'winloc_enabled', 1) && !s:winloc_switch
        " need to redirect window
        if s:winloc_redirect
            let s:winloc_redirect = 0
            let jumpwin = get(s:winloc_fifo, s:winloc_cursor)
            call s:LogTrace("redirect current window to:".jumpwin)
            if !empty(getwininfo(jumpwin))
                " do fake *Leave autocmds
                doautocmd BufLeave *
                doautocmd WinLeave *
                doautocmd TabLeave *
                call win_gotoid(jumpwin)
                return
            else
                echomsg "Invalid jump window:".jumpwin.", should never be reached."
            endif
        else
            let lastcmd = split(histget("cmd", -1), " ")[0]
            if lastcmd ==# "OpenSession"
                call s:WinlocUpdateOnEnter(0)
            else
                " with fifo update function with delay to avoid WinEnter flood
                " delay with 100ms by default
                " for unknown reason, DO NOT set the delay too short that's less than 50ms
                if empty(timer_info(s:winloc_update_timer))
                    call timer_stop(s:winloc_update_timer)
                    call s:LogTrace("Entering Window, delay timer to handle event")
                    let l:WinlocUpdater = function("<SID>WinlocUpdateOnEnter")
                    let s:winloc_update_timer = timer_start(get(g:, "winloc_update_delay", 100), l:WinlocUpdater)
                endif
            endif
        endif
    endif
endfunction

" jump across winloc fifo
function! winloc#winloc#JumpWinloc(direction) abort
    if get(g:, 'winloc_enabled', 1)
        call s:LogTrace("winloc jump ".a:direction)
        " turn on switch to block incoming WinEnter event
        let s:winloc_switch = 1
        let curwin = win_getid()
        if a:direction == 'prev'
            let next_cursor = v:count1 <= s:winloc_cursor ? s:winloc_cursor - v:count1 : -1
        else
            let next_cursor = (s:winloc_cursor + v:count1) < len(s:winloc_fifo) ? s:winloc_cursor + v:count1 : -1
        endif
        if next_cursor == -1
            echo "exceed winloc jump range"
        else
            let nextwin = get(s:winloc_fifo, next_cursor)
            if nextwin != curwin
                call s:LogTrace("initiate jumping to window:".nextwin)
                if win_gotoid(nextwin)
                    let s:winloc_cursor = next_cursor
                    call s:PostWinEventCheck()
                else
                    echomsg "Window ID .".nextwin." not found, do nothing"
                    if nextwin != 0
                        call remove(s:winloc_fifo, next_cursor)
                    endif
                    call s:WinlocUpdateOnEnter(0)
                endif
            endif
        endif
        " turn off switch for incoming WinEnter event
        let s:winloc_switch = 0
    endif
endfunction
