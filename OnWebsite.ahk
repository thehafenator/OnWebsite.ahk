#Requires AutoHotkey v2.0 ; Version 08.23.2025

/*

ReadMe:

TLDR: On Website is a class that caches the current website url on window title change or application using event listeners, allowing users to make context sensitive hotkeys and hotstrings based on the URL itself. It uses Descolada's UIA library (https://github.com/Descolada/UIA-v2) and a set timer call to quietly update the url in the background (typically 15ms). Because #Hotif blocks are evaluated at the time of execution, caching the url allows a quick string comparison to perform true, close to 0 latency compared to a if WinActive() call. 

1 . Class On Purpose:
The On class is a AutoHotkey Version 2 library designed to make it easier for users to make context sensitive hotkeys/hotstrings based on the current URL. For example, I could use a block like this, where pressing ^d would show the message box on onlygmail.com:

#Include OnWebsite.ahk

#Hotif On.Website("mail.google.com")
^d::MsgBox("On Gmail")
#Hotif

Normally, #Hotif blocks are used with TitleMatchMode set to 2 and doing something like this:
#Hotif WinActive("Gmail")
^d::MsgBox("On Gmail")
#Hotif

2. Issues with current alternatives:
The issue this creates is if another page contains, "Gmail" in the title, making it a bit unreliable. For example:
a) Editing a script in notepad that contains, "gmail" in the in title, this hotkey will trigger there.
b) Other shortcuts you define also match words in the title. For example: 

#Hotif WinActive("Amazon")
^d::MsgBox("On Amazon")
#Hotif

#Hotif WinActive("Gmail")
^d::MsgBox("On Gmail")
#Hotif

On Gmail, each time you view a message, it uses the Email Subject as the Wintitle. If you received an email from Amazon, it's likely that "Amazon" 
would be in your title. I like to use ^d as delete in various applications, but if I was on Gmail and I ran ^d while viewing the Amazon email, it will trigger the Amazon shortcut because it is defined first. Even Specifying #Hotif WinActive("Gmail ahk_exe chrome.exe") wouldn't be sufficient, because all websites will share Exe and class on the same browser. 
c) You want to have different shortcuts on different areas of the same website, but they both contain the same name, "Gmail". 

3. Solution: URL specific context - #Hot if, caching, and performance
How #Hotif normally works:
#Hotif blocks are evaluated at the time a key is pressed. If the condition to the right of #Hotif is true, it allows the hotkey to be triggered. (this is how people made contex-specific hotkeys and triggers other than just #Hotif WinActive(). Ex. using Mouse location (ex. scroll over taskbar to change volume), Key state (capslock remapping scripts), etc.)

The UIA Library is used to quickly grab the value of the title bar cache evaluate the url. This is grabbed once on script load, and updated  through even listeners each time the active window changes or the name of the current window is changed. 

Caching the URL this way offers a few advantages:
a) Runs asyncronously
b) While cache updates using a settimer, which won't tie up your hotkeys/hotstrings and allow the currently cached url to be used even while it is still in the process of getting update. For example, deleting an email will change the URL, but you don't have to wait for the URL to be updated befor your next function call. 
b) On code execution, your script won't make any unnecessary UIA calls
c) A map is made of the titles of the most recent 8 (you can change this in userconfig) Wintitles and pages. Each time the script detects change, it checks this map first before making any unnecessary UIA calls.

Best practices:
Part 1. - Use the same hotkey on similar URLs - pace the the most specific/longest on top
a) For example, to use (separate hotkeys for editing a google calendar event and the main google calendar page, place the more specific/long one at the top. In AutoHotkey Version 2 in general, when multiple #hotif conditions return true, the one written first (lower line number) is executed first. 

#Include OnWebsite.ahk

#HotIf On.Website("calendar.google.com/calendar/u/0/r/eventedit")
~LCtrl up::(A_ThisHotkey=A_PriorHotkey&&A_TimeSincePriorHotkey<200)&&googlecalendar.addemailnotifications()
#HotIf

#HotIf On.Website("calendar.google.com")
~LCtrl up::(A_ThisHotkey=A_PriorHotkey&&A_TimeSincePriorHotkey<200)&&googlecalendar.togglesidebar()
#HotIf

For this example, Double Clicking the lctrl button within 200 ms of itself other will either add email notifications (if on edit event) or toggle the sidebar (if on the main one). If we were to switch the order, and have the normal ("calendar.google.com") above, it would trigger only 'togglesidebar' on both urls, because (both URLs contain calendar.google.com). 


Part 2. You don't always have to use #Hotifs, either. You can use them for simple If statements as well, especially if easier to do mid function. To check if the current url contains or doesn't contain "sampleurl" on the inside, you could use the line if (InString(On.LastResult.url, "sampleurl")) or if (!InString(On.LastResult.url, "sampleurl")), respectively. 

For example, I could rewrite the earlier set of fucntions like this (to avoid ordering issues between #hotif blocks):  
#Include OnWebsite.ahk

~LCtrl up::(A_ThisHotkey=A_PriorHotkey&&A_TimeSincePriorHotkey<200){ ; this line just means if I double tap control (within 200 ms, and it is the same key as the last hotkey) then it will trigger. The ~ allows Lctrl to be used normally. 
If InStr(On.LastResult.url, "calendar.google.com/calendar/u/0/r/eventedit")
{
googlecalendar.addemailnotifications()
}
if InStr(On.LastResult.url, "calendar.google.com/") 
{
googlecalendar.togglesidebar()
}
}

Another example for using a simple 'if' depending on the url - a shortcut to run/login to website, but only run the login information if we aren't already logged in:

Numpad2::{
If !On.Website("mywebsite") ; if we are currently not on the mywebsite, run it
{
RunWait("mywebsite.com")
}
; possibly logic here to make sure the website/specific element has loaded to ensure it works
if !InStr(On.LastResult.url, "login/") ; or the actual different url for login  ; only login if the login url is here
{
mywebsitelogin()
}
}

Part 3:
4. Additional information: Config/Performance
A) See the static userconfig to change the cache speed/accuracy with Mode, maxcacheentries, retry delay in ms, and maxretries if you encounter performance issues.
B) See "exclusions" for exe, classes, and wintitles you want to skip the URL cache. For example, the "New Tab" page and Dialogue boxes like, "Open"/"Save as", etc., don't contain a URL. Add additional programs/pages here if they don't load.
C) The On.website method ensures that both the URL cache is up to date and that a browser is active. Browsers are defined with their full Exe class because chromium browsers often share classes and exe with other chromium browsers. 
D) To keep URL calls to a minimum, I reccommend Only Running one script with at a time On.Website included if you run into issues. 
E) Run On.DebugMsgBox() to see information about what is currently running. 


*/


class On {

    static userconfig := {
        Mode: "Fast",  ;  "Fast" or "Accurate". "Fast" is reccommended in most cases.  Accurate uses the DOM to retrieve url with 'https://', but slower to update because it needs to connect to the DOM with UIA_Browser.ahk. For simple hotkeys, Fast is sufficient
        MaxCacheEntries: 8, ; number of website pages to keep before updating
        RetryDelay: 100, ; in milliseconds. if we are unable to find the URL, we wait this amount and try again. 
        MaxRetries: 4 ; 
    }
    
    static LastResult := {url: "", browser: "", timestamp: 0}
    
    static currentstate := {
        LastActiveWindow: 0,
        LastTitle: "",
        Browser: "",
        InBrowserApp: false,
        TitleURLCache: Map()
    }
    
    static Exclusions := {
        WinTitles: [
            "New Tab", "Nueva pestaña", "Neuer Tab", "Nouvel onglet", 
            "Novo separador", "Новая вкладка", "新标签页", "新分頁", 
            "Start Page", "Speed Dial", "Open", "Save As", "UIAViewer.ahk", "Edit Current"
        ],
        Exes: [
            "autohotkey64.exe",
            "anki.exe"
        ],
        Classes: [
            "#32770"  ; Standard dialog class
        ]
    }
    
    static Initialize() {
        ; Hooks and initialization state as local static variables
        static ForegroundHook := 0
        static NameChangeHook := 0
        static Initialized := false
        if (Initialized)
            return
        Initialized := true
        this.InitializeEventHooks()
        this.InitialURLCache()
    }
    

    static Website(pattern) {
        this.Initialize()
        currentWin := WinActive("A")
        if (currentWin == 0) {
            this.currentstate.InBrowserApp := false
            this.currentstate.Browser := ""
            return false
        }
        currentBrowser := this.GetBrowserHandle()
        if (currentBrowser == "") {
            this.currentstate.InBrowserApp := false
            this.currentstate.Browser := ""
            return false
        }
        this.currentstate.InBrowserApp := true
        this.currentstate.Browser := currentBrowser
        
        ; Check if current window is excluded
        currentTitle := WinGetTitle(currentWin)
        if (this.IsExcludedWindow(currentTitle)) {
            return false
        }
        
        ; Check title-URL cache for fast response
        if (this.currentstate.TitleURLCache.Has(currentTitle)) {
            cachedResult := this.currentstate.TitleURLCache[currentTitle]
            try {
                if (InStr(cachedResult.url, pattern) > 0) {
                    this.LastResult := cachedResult
                    return true
                } else if (cachedResult.url != "") {
                    this.LastResult := cachedResult
                    return false
                }
            } 
        }
        ; Use the cached URL almost always
        try {
            if (this.LastResult.url != "" && InStr(this.LastResult.url, pattern) > 0) {
                return true
            } else if (this.LastResult.url != "") {
                return false
            }
        }

        ; Get fresh URL using the selected mode
        result := this.GetBrowserURL(true)

        ; Update title-URL cache if we got a valid URL
        if (result.url != "") {
            this.currentstate.TitleURLCache[currentTitle] := result
            this.LastResult := result
        }
        
        ; Check if the fresh URL contains the pattern
        try {
            return InStr(result.url, pattern) > 0
        } catch {
            return false
        }
    }
    
    ; Get browser URL with mode selection - combines both fast and accurate modes
    static GetBrowserURL(forceRefresh := false) {
        currentTime := A_TickCount
        
        if (!forceRefresh && this.LastResult.url != "" 
            && this.currentstate.LastTitle == WinGetTitle(this.currentstate.LastActiveWindow)) {
            return this.LastResult
        }
        try currentTitle := WinGetTitle(WinActive("A"))
        try {
            if (this.IsExcludedWindow(currentTitle)) {
                return {url: "", browser: this.GetBrowserHandle(), timestamp: currentTime}
            }
        }
        browser := this.GetBrowserHandle()
        if (browser == "") {
            return {url: "", browser: "", timestamp: currentTime}
        }
        
        ; Use mode-specific URL retrieval
        if (this.userconfig.Mode == "Fast") {
            Loop this.userconfig.MaxRetries {
                url := this.GetAddressBarDirect()
                if (url != "") {
                    return {url: url, browser: browser, timestamp: currentTime}
                }
                Sleep(this.userconfig.RetryDelay * A_Index)  ; Progressive backoff
            }
        } else {
            url := this.GetDocumentURL()
        }
        
        return {url: url, browser: browser, timestamp: currentTime}
    }
    
    ; Direct UIA address bar access (FAST), may not contain "https://""
    static GetAddressBarDirect() {
        try {
            browserEl := UIA.ElementFromHandle(WinActive("A"))
            try {
                return browserEl.FindElement({LocalizedType:"edit", Name:"Address and search bar"}).Value
            } catch {
                try {
                    return browserEl.FindElement({LocalizedType:"edit", Name:"Address field"}).Value
                } catch {
                    return ""
                }
            }
        } catch {
            return ""
        }
    }
    
    ; Document URL (ACCURATE)
    static GetDocumentURL() {
        try {
            cUIA := UIA_Browser(WinActive("A"))
            return cUIA.GetCurrentURL(False)
        } catch {
            return ""
        }
    }
    
    static IsExcludedWindow(winTitle := "") {
        if (winTitle == "") {
            activeWin := WinActive("A")
            if (activeWin == 0)
                return false
            winTitle := WinGetTitle(activeWin)
        }
        
        activeWin := WinActive("A")
        if (activeWin == 0)
            return false
            
        ; Check for title exclusions
        for titlePattern in this.Exclusions.WinTitles {
            if (InStr(winTitle, titlePattern)) {
                return true
            }
        }
        
        ; Check for exe exclusions
        activeExe := WinGetProcessName(activeWin)
        for exePattern in this.Exclusions.Exes {
            if (activeExe == exePattern) {
                return true
            }
        }
        
        ; Check for class exclusions
        activeClass := WinGetClass(activeWin)
        for classPattern in this.Exclusions.Classes {
            if (activeClass == classPattern) {
                return true
            }
        }
        
        ; Check if it's an empty tab/about:blank
        if (winTitle == "" || InStr(winTitle, "about:blank")) {
            return true
        }
        
        return false
    }
    
    ; Get handle for supported browsers
    static GetBrowserHandle() {
        ; Browser cache as local static variables
        static CachedBrowserEl := ""
        static CachedBrowser := ""
        static CachedBrowserWindow := 0
        
        ; Quick cached check to avoid redundant calls
        currentWin := WinActive("A")
        if (currentWin == CachedBrowserWindow && CachedBrowser != "") {
            return CachedBrowser
        }
        
        CachedBrowserWindow := currentWin
            if WinActive("ahk_exe chrome.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "chrome.exe"
        else if WinActive("ahk_exe thorium.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "thorium.exe"
        else if WinActive("ahk_exe msedge.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "msedge.exe"
        else if WinActive("ahk_exe firefox.exe ahk_class MozillaWindowClass")
            CachedBrowser := "firefox.exe"
        else if WinActive("ahk_exe floorp.exe ahk_class MozillaWindowClass")
            CachedBrowser := "floorp.exe"
        else if WinActive("ahk_exe brave.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "brave.exe"
        else if WinActive("ahk_exe opera.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "opera.exe"
        else if WinActive("ahk_exe vivaldi.exe ahk_class Chrome_WidgetWin_1")
            CachedBrowser := "vivaldi.exe"
        else
            CachedBrowser := ""
            
        return CachedBrowser
    }
    
    ; Browser cache refresh function
    static BrowserCacheEl(refresh := false) {
        ; Browser cache as local static variables
        static CachedBrowserEl := ""
        static CachedBrowser := ""
        
        this.Initialize()
        currentBrowser := this.GetBrowserHandle()
        
        ; Only refresh if explicitly requested or browser changed
        if (refresh || !CachedBrowserEl || currentBrowser != CachedBrowser) {
            if (currentBrowser != "") {
                CachedBrowserEl := UIA.ElementFromHandle("ahk_exe " currentBrowser)
                CachedBrowser := currentBrowser
            } else {
                CachedBrowserEl := ""
                CachedBrowser := ""
            }
        }
        return CachedBrowserEl
    }
    
    ; Initialize event hooks for window changes
    static InitializeEventHooks() {
        ; Hook handles as local static variables
        static ForegroundHook := 0
        static NameChangeHook := 0
        
        EVENT_SYSTEM_FOREGROUND := 0x0003
        EVENT_OBJECT_NAMECHANGE := 0x800C
        
        ; Create callbacks with proper parameter counts
        ForegroundCallback := CallbackCreate(ObjBindMethod(this, "OnWindowChange"), "F", 7)
        ForegroundHook := DllCall("SetWinEventHook", "UInt", EVENT_SYSTEM_FOREGROUND, "UInt", EVENT_SYSTEM_FOREGROUND, 
                "Ptr", 0, "Ptr", ForegroundCallback, "UInt", 0, "UInt", 0, "UInt", 0)
        
        NameChangeCallback := CallbackCreate(ObjBindMethod(this, "OnTitleChange"), "F", 7)
        NameChangeHook := DllCall("SetWinEventHook", "UInt", EVENT_OBJECT_NAMECHANGE, "UInt", EVENT_OBJECT_NAMECHANGE, 
                "Ptr", 0, "Ptr", NameChangeCallback, "UInt", 0, "UInt", 0, "UInt", 0)
    }

    ; Callback for window change event
    static OnWindowChange(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (idObject != 0)
            return
        
        activeWin := WinActive("A")
        if (activeWin == 0)
            return
        
        if (activeWin != this.currentstate.LastActiveWindow) {
            this.currentstate.LastActiveWindow := activeWin
            this.currentstate.LastTitle := WinGetTitle(activeWin)
            if (this.GetBrowserHandle() != "") {
                ; Skip URL update for excluded windows
                if (!this.IsExcludedWindow(this.currentstate.LastTitle)) {
                    this.BrowserCacheEl(true)
                    this.UpdateURLCache()
                } else {
                    this.LastResult := {url: "", browser: this.GetBrowserHandle(), timestamp: A_TickCount}
                }
            } else 
        }
    }
    
    ; Callback for title change event
    static OnTitleChange(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        activeWin := WinActive("A")
        if (activeWin == 0 || activeWin != hwnd)
            return
        
        newTitle := WinGetTitle(activeWin)
        if (newTitle != this.currentstate.LastTitle) {
            this.currentstate.LastTitle := newTitle
            if (this.GetBrowserHandle() != "") {
                ; If window is excluded, just clear the URL without trying to update
                if (this.IsExcludedWindow(newTitle)) {
                    this.LastResult := {url: "", browser: this.GetBrowserHandle(), timestamp: A_TickCount}
                } else {
                    ; Otherwise, update URL
                    this.UpdateURLCache()
                }
            } else {
                ; If we left the browser, clear the URL
               ; try this.LastResult := {url: "", browser: "", timestamp: A_TickCount}
            }
        }
    }
    
    ; Update URL cache with retry mechanism and title-URL cache
    static UpdateURLCache() {
        ; Check if current title is in our cache
        currentTitle := this.currentstate.LastTitle
        if (this.currentstate.TitleURLCache.Has(currentTitle)) {
            ; Use cached URL for this title
            this.LastResult := this.currentstate.TitleURLCache[currentTitle]
            ; ToolTip("Updated from Map!") ;;; 
            ; SetTimer () => ToolTip(), -2000 ;;;
            return
        }
        
        ; If not in cache, proceed with normal fetch
        this.UpdateURLCacheWorker()
        
        ; After successful fetch, update the title-URL cache
        if (this.LastResult.url != "") {
            ; Add to cache
            this.currentstate.TitleURLCache[currentTitle] := this.LastResult
            
            ; Trim cache if needed
            if (this.currentstate.TitleURLCache.Count > this.userconfig.MaxCacheEntries) {
                ; Remove oldest entry (Map preserves insertion order in AHK v2)
                oldestKey := ""
                for key in this.currentstate.TitleURLCache {
                    oldestKey := key
                    break
                }
                this.currentstate.TitleURLCache.Delete(oldestKey)
            }
        }
    }
    
    static UpdateURLCacheWorker(retryCount := 0) {
        ; Skip if window is excluded
        if (this.IsExcludedWindow(WinGetTitle(WinActive("A")))) {
            try this.LastResult := {url: "", browser: this.GetBrowserHandle(), timestamp: A_TickCount}
            return
        }
        
        ; Try to get the URL
        newResult := this.GetBrowserURL(true)
        
        ; If we got a valid URL, update and we're done
        if (newResult.url != "") {
            try {
                this.LastResult := newResult
                
                ; Also update the title-URL cache since we have a fresh URL
                if (this.currentstate.LastTitle && this.LastResult.url != "") {
                    this.currentstate.TitleURLCache[this.currentstate.LastTitle] := this.LastResult
                }
            }
            return
        }
        
        ; If we're no longer in a browser, clear the result and we're done
        if (this.GetBrowserHandle() == "") {
            try this.LastResult := {url: "", browser: "", timestamp: A_TickCount}
            return
        }
        
        ; Only retry if we're still in a browser but failed to get a URL
        if (retryCount < this.userconfig.MaxRetries) {
            ; Calculate the delay with exponential backoff
            backoffDelay := this.userconfig.RetryDelay * (2 ** retryCount)
            
            ; Schedule the retry
            SetTimer(() => this.UpdateURLCacheWorker(retryCount + 1), -backoffDelay)
        }
    }
    
    ; Function to initialize URL cache 
    static InitialURLCache() {
        ; Capture current active window
        activeWin := WinActive("A")
        if (activeWin != 0) {
            this.currentstate.LastActiveWindow := activeWin
            this.currentstate.LastTitle := WinGetTitle(activeWin)
            
            ; If we're in a browser but not on an excluded window, cache the URL
            if (this.GetBrowserHandle() != "" && !this.IsExcludedWindow(this.currentstate.LastTitle)) {
                this.BrowserCacheEl(true)
                this.UpdateURLCache()
            }
        }
    }
    
    ; Utility function to clear the title-URL cache
    static ClearTitleURLCache() {
        this.Initialize()
        this.currentstate.TitleURLCache := Map()
        return "Title-URL cache cleared"
    }
    
    ; Debug function
    static DebugMsgBox() {
        this.Initialize()
        activeWin := WinActive("A")
        currentTitle := activeWin ? WinGetTitle(activeWin) : "None"
        currentExe := activeWin ? WinGetProcessName(activeWin) : "None"
        currentClass := activeWin ? WinGetClass(activeWin) : "None"
        cacheCount := this.currentstate.TitleURLCache.Count
        cacheEntries := ""
        for title, result in this.currentstate.TitleURLCache {
            cacheEntries .= title . " -> " . result.url . "`n"
        }
        msg := "Debug Info:`n"
             . "Mode: " . this.userconfig.Mode . "`n"
             . "Active Window ID: " . activeWin . "`n"
             . "Window Title: " . currentTitle . "`n"
             . "Process Name: " . currentExe . "`n"
             . "Window Class: " . currentClass . "`n"
             . "Last URL: " . this.LastResult.url . "`n"
             . "Last Browser: " . this.LastResult.browser . "`n"
             . "Last Timestamp: " . this.LastResult.timestamp . "`n"
             . "Current Browser: " . this.currentstate.Browser . "`n"
             . "In Browser App: " . (this.currentstate.InBrowserApp ? "Yes" : "No") . "`n"
             . "Cache Size: " . cacheCount . "`n"
             . "Cache Entries:`n" . (cacheEntries ? cacheEntries : "None")
        MsgBox msg
    }
}
