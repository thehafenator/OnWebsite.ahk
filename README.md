# OnWebsite.ahk Website-Specific Hotkeys in AutoHotkey v2

## TL;DR
**On** is a class that caches the current website URL on window title change or application using event listeners.  
This allows you to create **context-sensitive hotkeys and hotstrings** that are URL-specific.  

It uses [Descolada's UIA library](https://github.com/Descolada/UIA-v2) and a `SetTimer` call to quietly update the URL in the background (default: 15 ms).  

Because `#HotIf` blocks are evaluated at execution time, caching the URL allows a **fast string comparison** with *close to zero latency* — much faster than calling `WinActive()` directly.  

---

## 1. Purpose
The `On` class is an AutoHotkey v2 library designed to make it easier for users to create hotkeys/hotstrings that depend on the **current URL**.

Example:

```
#Include OnWebsite.ahk

#HotIf On.Website("mail.google.com")
^d::MsgBox("On Gmail")
#HotIf
```

Normally, you might do this with `WinActive`:

```
#HotIf WinActive("Gmail")
^d::MsgBox("On Gmail")
#HotIf
```

But that approach is unreliable because page titles often overlap with unrelated windows.

---

## 2. Issues with Current Alternatives

### Example problems with `WinActive`
1. **Title collision**  
   If Notepad contains `"gmail"` in its title, the Gmail hotkey will also trigger there.  

2. **Multiple shortcuts with overlapping titles**  

```
#HotIf WinActive("Amazon")
^d::MsgBox("On Amazon")
#HotIf

#HotIf WinActive("Gmail")
^d::MsgBox("On Gmail")
#HotIf
```

- Gmail uses the email subject as the window title.  
- If an email subject contains `"Amazon"`, the Amazon shortcut will fire inside Gmail.  
- Even `#HotIf WinActive("Gmail ahk_exe chrome.exe")` won’t solve this, because all sites share the same `exe` and class.  

3. **Different areas of the same site**  
   Example: Gmail’s inbox vs. an open email — both have `"Gmail"` in the title, but you might want different shortcuts.

---

## 3. Solution: URL-Specific Context

### How `#HotIf` normally works
- Blocks are evaluated when a key is pressed.  
- If the condition is true, the hotkey is triggered.  
- You can use `#HotIf` with other contexts (mouse position, key states, etc.), but URLs are tricky without caching.

### How OnWebsite.ahk works
- Uses the **UIA library** to grab the window’s URL (via the title bar).  
- Updates through event listeners when the active window changes or its title updates.  
- Stores a **cache** of recent URLs for near-zero-latency checks.  

#### Advantages
- Runs **asynchronously**.  
- Cached URLs are available even while updates are in progress.  
- No extra UIA calls during hotkey execution.  
- Maintains a **map of the 8 most recent URLs/titles** (configurable).  

---

## 4. Best Practices

### Part 1. Prioritize Specific URLs
Place more specific URLs above broader ones.  
AutoHotkey executes the **first true `#HotIf` block**.

```
#Include OnWebsite.ahk

#HotIf On.Website("calendar.google.com/calendar/u/0/r/eventedit")
~LCtrl up::(A_ThisHotkey=A_PriorHotkey && A_TimeSincePriorHotkey < 200) && googlecalendar.addemailnotifications()
#HotIf

#HotIf On.Website("calendar.google.com")
~LCtrl up::(A_ThisHotkey=A_PriorHotkey && A_TimeSincePriorHotkey < 200) && googlecalendar.togglesidebar()
#HotIf
```

- Double-tapping `LCtrl` within 200 ms:  
  - On **event edit** page → adds email notifications.  
  - On **main calendar** → toggles sidebar.  
- If reversed, only `togglesidebar` would run, since both URLs contain `"calendar.google.com"`.

---

### Part 2. Use Inline `if` Conditions
You don’t always need `#HotIf`.  
Check URLs inline with `InStr`.

```
#Include OnWebsite.ahk

~LCtrl up::(A_ThisHotkey=A_PriorHotkey && A_TimeSincePriorHotkey < 200){
    if InStr(On.LastResult.url, "calendar.google.com/calendar/u/0/r/eventedit") {
        googlecalendar.addemailnotifications()
    }
    if InStr(On.LastResult.url, "calendar.google.com/") {
        googlecalendar.togglesidebar()
    }
}
```

Another example — only log in if not already on the site:

```
Numpad2::{
    if !On.Website("mywebsite") {
        RunWait("mywebsite.com")
    }
    ; check if login page is active
    if !InStr(On.LastResult.url, "login/") {
        mywebsitelogin()
    }
}
```

---

## 5. Config & Performance

- **UserConfig**: tweak cache speed/accuracy with:
  - `Mode`, `maxcacheentries`, `retry delay (ms)`, `maxretries`.
- **Exclusions**: skip unwanted windows:
  - `"New Tab"`, file dialogs (`Open` / `Save As`), or apps without URLs.
- **Browser detection**: uses `exe` and class to ensure browser-only operation.
- **Tip**: Only run **one script at a time** with `On.Website` to avoid excess calls.
- **Debugging**: use `On.DebugMsgBox()` to see what’s running.

---
