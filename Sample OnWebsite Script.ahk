; Gmail
#Include OnWebsite.ahk
#Include UIA-v2-main\Lib\UIA.ahk
#Include UIA-v2-main\Lib\UIA_Browser.ahk


#HotIf OnWebsite("mail.google.com")
; Control + n to create new message
^n::{ 
    Send "c"  
}

;Control + d  or ^Capslock to delete a message or draft. This utilizes the UIA version 2 library by Descolada. The 'browser' variable in this case will be retrieved from the OnWebsite("") command through GetBrowserHandle() and GetBrowserURL(), so this approach will work with any browser without needing to alter the code.
^d::
^Capslock::
{ 
    Try { 
        SetCapsLockState("Off"), UIA.ElementFromHandle(WinActive("ahk_exe " browser)).WaitElement({LocalizedType:"button", Name:"Delete"}, 100).Click() 
    } 
    catch{
        try
            {
            browserEl := UIA.ElementFromHandle("ahk_exe " browser)
            browserEl.WaitElement({LocalizedType:"text", Name:"Discard drafts"}, 1000).Click()
            }
       }
    }

; Search all emails with control f (instead of find on page)
^f::{ 
    Try UIA.ElementFromHandle(WinActive("ahk_exe " browser)).WaitElement({Name:"Search mail", LocalizedType:"edit"}, 1000).ControlClick() 
    Send "^{a}"
}

; Find on page shortcut remapped control shift f
^+f::{ 
    Send "^{f}" 
}

#Hotif
