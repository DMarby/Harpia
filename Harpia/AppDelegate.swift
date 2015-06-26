import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var recentMenu: NSMenu!
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!
    var windowController: NSWindowController!
    
    var icon: NSImage!
    var errorIcon: NSImage!
    var workingIcon: NSImage!
    
    var languages: NSDictionary!
    
    var timer: NSTimer!
    
    var statusItemViewDelegate: StatusItemViewDelegate!
    var notificationCenterDelegate: NotificationCenterDelegate!
    

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        languages = Util.loadLanguages()
        
        statusItemViewDelegate = StatusItemViewDelegate()
        notificationCenterDelegate = NotificationCenterDelegate()
        
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = notificationCenterDelegate
        
        let defaults = ["PrivateGists": true,
            "CopyToClipboard": true,
            "PlaySound": true,
            "DisplayNotification": true,
            "ShortenUrl": true,
            "DefaultLanguage": "Text",
            "LaunchAtLogin": false]
        
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        setupStatusItem()
    
        NSUserDefaultsController.sharedUserDefaultsController().addObserver(self, forKeyPath: "values.GlobalPaste", options: NSKeyValueObservingOptions.Initial, context: nil)

        NSApplication.sharedApplication().servicesProvider = ServicesProvider()
        NSUpdateDynamicServices()
                
        Util.launchAtLogin()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        NSUserDefaultsController.sharedUserDefaultsController().removeObserver(self, forKeyPath: "values.GlobalPaste")
        var recentGists = [Dictionary<String,String>]()
        var recentGistsMenuItems = recentMenu.itemArray as! [NSMenuItem]
        
        recentGistsMenuItems.removeRange(Range(start: recentGistsMenuItems.count - 2, end: recentGistsMenuItems.count))
        
        for item in recentGistsMenuItems {
            recentGists.append(["title": item.title, "representedObject": item.representedObject as! String])
        }
        
        if (recentGists.count > 5) {
            recentGists.removeRange(Range(start: 5, end: recentGists.count))
        }
        
        NSUserDefaults.standardUserDefaults().setObject(recentGists, forKey: "RecentGists")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func setupRecentMenu() {
        var recentGists = [Dictionary<String,String>]()
        let recentGistsFromDefaults: AnyObject? = NSUserDefaults.standardUserDefaults().objectForKey("RecentGists")
        recentMenu = NSMenu()
        
        if (recentGistsFromDefaults != nil) {
            recentGists = recentGistsFromDefaults as! [Dictionary<String, String>]
        }
        
        if (recentGists.count > 5) {
            recentGists.removeRange(Range(start: 5, end: recentGists.count))
        }
        
        for item in recentGists {
            recentMenu.addItem(Util.generateRecentMenuItem(item["title"]!, representedObject: item["representedObject"]!))
        }
        
        recentMenu.addItem(NSMenuItem.separatorItem())
        recentMenu.addItemWithTitle("Clear recent Gists", action:Selector("clearMenu"), keyEquivalent:"")
    }
    
    func setupIcons() {
        let bundle = NSBundle.mainBundle()
        
        let path = bundle.pathForResource("icon", ofType: "pdf")
        let errorPath = bundle.pathForResource("icon-error", ofType: "pdf")
        let workingPath = bundle.pathForResource("icon-working", ofType: "pdf")
        
        icon = NSImage(contentsOfFile: path!)
        icon.setTemplate(true)
        
        errorIcon = NSImage(contentsOfFile: errorPath!)
        errorIcon.setTemplate(false)
        
        workingIcon = NSImage(contentsOfFile: workingPath!)
        workingIcon.setTemplate(false)
    }
    
    func setupStatusItem() {
        setupRecentMenu()
        setupIcons()
        
        let menu = NSMenu()
        
        let recentGistsMenuItem = NSMenuItem()
        recentGistsMenuItem.title = "Recent Gists"
        recentGistsMenuItem.submenu = recentMenu
        
        toggleItem = NSMenuItem(title: "Make Gist secret", action:Selector("togglePrivate"), keyEquivalent: "")
        toggleItem.state = NSUserDefaults.standardUserDefaults().boolForKey("PrivateGists") ? 1 : 0
        
        menu.addItemWithTitle("Create Gist from clipboard", action:Selector("createGistFromMenu"), keyEquivalent:"")
        menu.addItem(recentGistsMenuItem)
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Preferences", action:Selector("displayPreferences:"), keyEquivalent: "")
        menu.addItemWithTitle("Quit Harpia", action:Selector("terminate:"), keyEquivalent: "")

        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
        statusItem.menu = menu
        statusItem.image = icon
        statusItem.highlightMode = true
        
        // NSURLPboardType?
        let types = [
            NSFilenamesPboardType,
            NSStringPboardType
        ]
        
        statusItem.button?.window?.registerForDraggedTypes(types)
        statusItem.button?.window?.delegate = statusItemViewDelegate
    }
    
    
    func togglePrivate() {
        let newState = !NSUserDefaults.standardUserDefaults().boolForKey("PrivateGists")
        NSUserDefaults.standardUserDefaults().setBool(newState, forKey: "PrivateGists")
        NSUserDefaults.standardUserDefaults().synchronize()
        toggleItem.state = newState ? 1 : 0
    }
    
    func terminate(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(sender)
    }
    
    func displayPreferences(sender: AnyObject?) {
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        windowController = storyBoard?.instantiateControllerWithIdentifier("PreferencesWindowController") as? NSWindowController
        windowController.showWindow(sender)
        // TODO redundant?
        windowController.window?.makeKeyAndOrderFront(self)
        
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        // TODO redundant?
        NSApplication.sharedApplication().mainWindow?.makeKeyAndOrderFront(sender)
    }
    
    func displayPreferencesWithError() {
        displayPreferences(nil)
        
        let userInfo = [
            NSLocalizedFailureReasonErrorKey: "Invalid credentials",
            NSLocalizedDescriptionKey: "Invalid GitHub authentication token!"
        ]
        
        let error = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: userInfo)
        
        NSApplication.sharedApplication().presentError(error, modalForWindow: windowController.window!, delegate: nil, didPresentSelector: nil, contextInfo: nil)
    }
    
    func pressedLatestMenu(sender: AnyObject) {
        let url = sender.representedObject as! String
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: url)!)
    }
    
    
    func clearMenu() {
        recentMenu.removeAllItems();
        recentMenu.addItem(NSMenuItem.separatorItem())
        recentMenu.addItemWithTitle("Clear recent Gists", action:Selector("clearMenu"), keyEquivalent:"")
    }
    
    func createGistFromMenu() {
        Util.createGistFromClipboard()
    }
    
    @IBAction func pasteShortcut(sender : AnyObject) {
        Util.createGistFromClipboard()
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "values.GlobalPaste") {
            let hotKeyCenter = PTHotKeyCenter.sharedCenter()
            let oldHotKey = hotKeyCenter.hotKeyWithIdentifier(keyPath)

            hotKeyCenter.unregisterHotKey(oldHotKey)

            let newShortcut: NSDictionary? = object.valueForKeyPath(keyPath) as? NSDictionary

            if (newShortcut != nil) {
                let newHotKey: PTHotKey = PTHotKey(identifier: keyPath, keyCombo: newShortcut as! [NSObject : AnyObject], target: self, action: Selector("pasteShortcut:"))
                newHotKey.setAction(Selector("pasteShortcut:"))

                hotKeyCenter.registerHotKey(newHotKey)
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    func displayError() {
        statusItem.image = errorIcon
       
        Util.delay(10) {
            if (self.statusItem.image == self.errorIcon) {
                self.statusItem.image = self.icon
            }
        }
    }
}