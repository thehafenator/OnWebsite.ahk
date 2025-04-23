#Requires AutoHotkey v2.0 ; 04.22.2025 update

; Configurable settings
global g_OnWebsiteRetryDelay := 500       ; Base delay between retries in ms
global g_OnWebsiteMaxRetries := 3         ; Maximum number of retries

; Global variables with proper initialization
global g_LastResult := {url: "", browser: "", timestamp: 0}
global g_LastActiveWindow := 0  ; Initialize to 0
global g_LastTitle := ""        ; Track the last window title
global browser := ""            ; Global browser variable for hotkeys to use
global g_InBrowserApp := false  ; Track if we're in a browser app

; Set up event hook for window title changes
InitializeEventHooks()

; ----- URL Detection Functions -----
GetBrowserURL(forceRefresh := false) {
    ; Use cache if not forcing refresh and title hasn't changed
    currentTime := A_TickCount
    
    if (!forceRefresh && g_LastResult.url != "" 
        && g_LastTitle == WinGetTitle(g_LastActiveWindow)) {
        return g_LastResult ; Return cached result if valid
    }

    ; Check if we're on a new tab page based on title
    currentTitle := WinGetTitle(WinActive("A"))
    if (IsNewTabPage(currentTitle)) {
        return {url: "", browser: GetBrowserHandle(), timestamp: currentTime}
    }

    ; Otherwise, fetch fresh URL and browser info
    try {
        browser := GetBrowserHandle()
        if (browser == "") {
            return {url: "", browser: "", timestamp: currentTime}
        }
        cUIA := UIA_Browser(WinActive("A"))
        URL := cUIA.GetCurrentURL(False)
        
        return {url: URL, browser: browser, timestamp: currentTime}
    } catch {
        return {url: "", browser: "", timestamp: currentTime}
    }
}

; Function to check if current page is a new tab page
IsNewTabPage(title) {
    ; Common new tab page titles across browsers
    static newTabTitles := ["New Tab", "Nueva pestaña", "Neuer Tab", "Nouvel onglet", 
                          "Novo separador", "Новая вкладка", "新标签页", "新分頁", 
                          "Start Page", "Speed Dial"]
    
    for titlPattern in newTabTitles {
        if (InStr(title, titlPattern)) {
            return true
        }
    }
    
    ; Check if it's an empty tab/about:blank
    if (title == "" || InStr(title, "about:blank")) {
        return true
    }
    
    return false
}

; Get handle for supported browsers
GetBrowserHandle() {
    if WinActive("ahk_exe chrome.exe")
        return "chrome.exe"
    if WinActive("ahk_exe thorium.exe")
        return "thorium.exe"
    else if WinActive("ahk_exe msedge.exe")
        return "msedge.exe"
    else if WinActive("ahk_exe firefox.exe")
        return "firefox.exe"
    else if WinActive("ahk_exe floorp.exe")
        return "floorp.exe"
    else
        return ""
}

; Function to check if we're on a specific website - This is the key function for hotkeys
OnWebsite(pattern) {
    global g_LastResult, g_LastActiveWindow, g_LastTitle, browser, g_InBrowserApp

    currentWin := WinActive("A")
    if (currentWin == 0) {
        g_InBrowserApp := false
        browser := ""
        return false
    }

    currentBrowser := GetBrowserHandle()
    if (currentBrowser == "") {
        g_InBrowserApp := false
        browser := ""
        return false
    }

    g_InBrowserApp := true
    browser := currentBrowser
    
    ; Check if we're on a new tab page
    if (IsNewTabPage(WinGetTitle(currentWin))) {
        return false  ; Don't even try to get URL from new tab page
    }

    ; Use the cached URL almost always (99/100 times)
    try {
        if (g_LastResult.url != "" && InStr(g_LastResult.url, pattern) > 0) {
            return true
        } else if (g_LastResult.url != "") {
            return false
        }
    } catch {
        ; If there's an error checking the cached URL, continue to fresh check
    }

    ; If we don't have a cached URL or there was an error, get a fresh URL
    ; This will only happen rarely (the 1% case you mentioned)
    result := GetBrowserURL(true)
    
    ; Check if the fresh URL contains the pattern
    try {
        return InStr(result.url, pattern) > 0
    } catch {
        return false
    }
}

; Browser cache refresh function (optimized)
BrowserCacheEl(refresh := false) {
    static cachedBrowserEl := ""
    if (refresh || !cachedBrowserEl) {
        browser := GetBrowserHandle()
        cachedBrowserEl := UIA.ElementFromHandle("ahk_exe " browser)
    }
    return cachedBrowserEl
}

; Initialize event hooks for window changes
InitializeEventHooks() {
    EVENT_SYSTEM_FOREGROUND := 0x0003
    EVENT_OBJECT_NAMECHANGE := 0x800C
    
    ForegroundCallback := CallbackCreate(OnWindowChange, "F")
    DllCall("SetWinEventHook", "UInt", EVENT_SYSTEM_FOREGROUND, "UInt", EVENT_SYSTEM_FOREGROUND, 
            "Ptr", 0, "Ptr", ForegroundCallback, "UInt", 0, "UInt", 0, "UInt", 0)
    
    NameChangeCallback := CallbackCreate(OnTitleChange, "F")
    DllCall("SetWinEventHook", "UInt", EVENT_OBJECT_NAMECHANGE, "UInt", EVENT_OBJECT_NAMECHANGE, 
            "Ptr", 0, "Ptr", NameChangeCallback, "UInt", 0, "UInt", 0, "UInt", 0)
}

; Callback for window change event
OnWindowChange(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
    global g_LastActiveWindow, g_LastTitle
    
    if (idObject != 0)
        return
    
    activeWin := WinActive("A")
    if (activeWin == 0)
        return
    
    if (activeWin != g_LastActiveWindow) {
        g_LastActiveWindow := activeWin
        g_LastTitle := WinGetTitle(activeWin)
        if (GetBrowserHandle() != "") {
            ; Skip URL update for new tab pages
            if (!IsNewTabPage(g_LastTitle)) {
                BrowserCacheEl(true)  ; Refresh UIA cache
                UpdateURLCache()      ; Update on window change - this is where retries might be needed
            } else {
                g_LastResult := {url: "", browser: GetBrowserHandle(), timestamp: A_TickCount}
            }
        } else {
            ; If not in a browser, clear the URL
            g_LastResult := {url: "", browser: "", timestamp: A_TickCount}
        }
    }
}

; Callback for title change event
OnTitleChange(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
    global g_LastActiveWindow, g_LastTitle, g_LastResult
    
    activeWin := WinActive("A")
    if (activeWin == 0 || activeWin != hwnd)
        return
    
    newTitle := WinGetTitle(activeWin)
    if (newTitle != g_LastTitle) {
        g_LastTitle := newTitle
        if (GetBrowserHandle() != "") {
            ; If we're on a new tab page, just clear the URL without trying to update
            if (IsNewTabPage(newTitle)) {
                g_LastResult := {url: "", browser: GetBrowserHandle(), timestamp: A_TickCount}
            } else {
                ; Otherwise, update URL - this is a title change so retries might be needed
                UpdateURLCache()
            }
        } else {
            ; If we left the browser, clear the URL
            g_LastResult := {url: "", browser: "", timestamp: A_TickCount}
        }
    }
}

; Update URL cache with retry mechanism - this is the key function for title changes
UpdateURLCache() {
    UpdateURLCacheWorker()  ; Start the worker immediately
}

UpdateURLCacheWorker(retryCount := 0) {
    global g_LastResult, g_OnWebsiteMaxRetries, g_OnWebsiteRetryDelay
    
    ; Skip if we're on a new tab page
    if (IsNewTabPage(WinGetTitle(WinActive("A")))) {
        g_LastResult := {url: "", browser: GetBrowserHandle(), timestamp: A_TickCount}
        return
    }
    
    ; Try to get the URL
    newResult := GetBrowserURL(true)  ; Force refresh
    
    ; If we got a valid URL, update and we're done
    if (newResult.url != "") {
        g_LastResult := newResult
        return
    }
    
    ; If we're no longer in a browser, clear the result and we're done
    if (GetBrowserHandle() == "") {
        g_LastResult := {url: "", browser: "", timestamp: A_TickCount}
        return
    }
    
    ; Here's the key part - only retry if we're still in a browser but failed to get a URL
    ; This should happen only in that 1% case you mentioned
    if (retryCount < g_OnWebsiteMaxRetries) {
        ; Calculate the delay with exponential backoff
        backoffDelay := g_OnWebsiteRetryDelay * (2 ** retryCount)
        
        ; Schedule the retry
        SetTimer(() => UpdateURLCacheWorker(retryCount + 1), -backoffDelay)
    }
    ; If we hit max retries, keep the old g_LastResult
}

; Function to initialize URL cache 
InitialURLCache() {
    global g_LastActiveWindow, g_LastTitle
    
    ; Capture current active window
    activeWin := WinActive("A")
    if (activeWin != 0) {
        g_LastActiveWindow := activeWin
        g_LastTitle := WinGetTitle(activeWin)
        
        ; If we're in a browser but not on a new tab page, cache the URL
        if (GetBrowserHandle() != "" && !IsNewTabPage(g_LastTitle)) {
            BrowserCacheEl(true)      ; Refresh UIA cache
            UpdateURLCache()          ; Initial update
        }
    }
}

; Cache the URL immediately when script starts
InitialURLCache()
