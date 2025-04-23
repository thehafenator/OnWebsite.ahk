# OnWebsite: Website-Specific-Hotkeys in Autohotkey Version 2

OnWebsite is an Autohotkey version 2 library that leverages the UIA.ahk framework to target specific URLs for use in #Hotif statements. This allows users to make hotkeys that are context specific to one website. (I.e. you could use control d on gmail in chrome and not have it affect control d on a different website). I orginally wrote this for myself to make it much easier to expand my library of hotkeys in Autothotkey (The alternative is using TitleMatchMode and specifying every browser that you might use for this hotkey each time). I have over 75 different websites I currently use that keeps them context sensitive.

How do we target the URL? Simply put, the script waits for either the program or the window title to change. When either of these events happen, it uses the UIA library to find the value of the current URL, which is then cached as the most current website. When a user has presses website-specific hotkey like using ^n in gmail:

```
#Hotif OnWebsite("gmail.com")
^n::
{
Msgbox("this is a test on gmail.")
}
#Hotif
```

The script checks the currently cached URL against the string, "gmail.com". If it matches, it allows the code to run. See additional formatting/ideas the "Sample OnWebsite.ahk" script for ideas of formatting. For those unfamiliar with the UIA library, here is a mini tutorial:

Let's look at its most basic use: writing a hotkey to click a button. For this example, we will click the 'delete' button in Gmail. Feel free to follow along:

1. Open the OnWebsite folder. Double click UIA.ahk within the UIA folder, then the Lib folder, to open the tree viewer. Press "Show macro sidebar" on the bottom right to show the Macropad creator section.
2. Capture Element (a button, icon, link, etc. you want to target). To do this, click on Start Capturing on the bottom left (or press F1 or Escape) and try hovering around the screen with the mouse. If you have gmail pulled up, see if you can get it over the delete button.
Once the blue rectangle is close to the rectangle, press Escape or F1 to stop capturing. You should notice on the middle column a tree that shows all available elements (things you can target on a webpage or application). Left click the one called, (button "Delete") - without the parenthesis - in the middle column. This will now let you see all available information in the properties section on the left.
![image](https://github.com/user-attachments/assets/cbcc94b2-e4bf-47b7-b4e1-6ed8002d7c6e)

4. Select and copy desired properties to send to the macro sidebar. To do this, hold down control and left click on the row that says, "Name Delete" (without the ""), then continue to hold control down and click "Localized type, button". (Note that if Localized type and Name do not have these values, you are not selected on the delete button. Try clicking on (button "Delete") - without the () -  in the middle of the UIA tree.) You will notice a tooltip appear that says, "Copied: LocalizedType:"button", Name:"Delete". 
![image](https://github.com/user-attachments/assets/a1211f03-970a-4f8d-989f-9b942fb3401b)

6. Next, look at the right side of the screen. The Action should be "Click()". Now press the Add element button on the top right and you should get this:
![image](https://github.com/user-attachments/assets/b69b96c8-e5b2-4995-b4ef-e42394f5c9f6)
```
browser := "chrome.exe"

try
{
browserEl := UIA.ElementFromHandle("ahk_exe " browser)
browserEl.WaitElement({LocalizedType:"button", Name:"Delete"}, 1000).Click()
}
```

5. Press, "Test" to see if this combination will work. The UIA program will attempt to click the button. If successful, the email will be deleted. If not, try using "Invoke()" or "ControlClick()" instead of Click()".

6. If that did work simply copy the above code, except for "browser := "chrome.exe".

7. Format it into your code as follows:

```
    ; Include these Libraries(dependencies) by using the #Include function. Note that you will need the OnWebsite.ahk and the UIA-v2-main folder to be in the same folder as your script:

    #Include OnWebsite.ahk
    #Include UIA-v2-main\Lib\UIA.ahk
    #Include UIA-v2-main\Lib\UIA_Browser.ahk

    ; Next, specify we only want this to be on gmail.com. It only needs to be a short, identifiable part of the URL.
    #HotIf OnWebsite("mail.google.com")

    ; typical autohotkey formatting for version 2 (^d:: is control delete, and the code following in {} will be run. ; the formatting from the macropad creator using the 'browser' variable, along with the Onwebsite library will allow this hotkey to run on chrome, firefox, or other browsers. (In other words, you won't have to specify the browser because OnWebsite will detect that for you.)
    ^d::
    {
    try
    {
    browserEl := UIA.ElementFromHandle("ahk_exe " browser)
    browserEl.WaitElement({LocalizedType:"button", Name:"Delete"}, 1000).Click()
    }
    }

    ; close the conditional hotif statement with an ending #Hotif
    #Hotif
```

Now, run the script. When you are on Gmail, pressing control and d will attempt to hit the delete button. It will attempt to look for 1 second (1000 milliseconds). 
For a more detailed tutorial, see the official wiki, which also links several tutorials: https://github.com/Descolada/UIAutomation/wiki. These tutorials do get somewhat advanced, so I did try to show the most basic principle in this readme and Sample file - clicking on certain element. Paired with Onwebsite, you can now create hotkeys for Websites by targeting their URL, not just the Window Title, Class, or Exe. 
