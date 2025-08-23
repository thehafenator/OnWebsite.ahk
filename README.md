# OnWebsite: Website-Specific-Hotkeys in Autohotkey Version 2

ReadMe:

TLDR: On Website is a class that caches the current website url on window title change or application using event listeners, allowing users to make context sensitive hotkeys and hotstrings. It uses Descolada's UIA library (https://github.com/Descolada/UIA-v2) and a set timer call to quietly update the url in the background (typically 15ms). Because #Hotif blocks are evaluated at the time of execution, caching the url allows a quick string comparison to perform true, close to 0 latency compared to a if WinActive() call. 

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

