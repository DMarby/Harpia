import Cocoa

class PreferencesController: NSViewController, SRRecorderControlDelegate, SRValidatorDelegate, NSComboBoxDataSource {
   
    @IBOutlet weak var authField: NSTextField!
    @IBOutlet weak var copyLink: NSButton!
    @IBOutlet weak var playSound: NSButton!
    @IBOutlet weak var displayNotification: NSButton!
    @IBOutlet weak var makeSecret: NSButton!
    @IBOutlet weak var shortenUrls: NSButton!
    @IBOutlet weak var defaultLanguage: NSComboBox!
    
    @IBOutlet weak var launchAtLogin: NSButton!
    
    var languagesList: [String]!
    
    var validator: SRValidator!
    
    @IBOutlet weak var globalPasteShortcutRecorder: SRRecorderControl!
    
    override func awakeFromNib() {
        let languages = Util.getAppDelegate().languages.allKeys as! [String]
        languagesList = languages.sorted { $0.localizedCaseInsensitiveCompare($1) == NSComparisonResult.OrderedAscending }
        languagesList.insert("Text", atIndex: 0)
        
        let selectedDefaultLanguage:Int = find(languagesList, NSUserDefaults.standardUserDefaults().objectForKey("DefaultLanguage") as! String)!
        
        defaultLanguage.dataSource = self
        defaultLanguage.selectItemAtIndex(selectedDefaultLanguage)
        
        copyLink.state = Util.loadPreferenceState(copyLink.identifier!)
        playSound.state = Util.loadPreferenceState(playSound.identifier!)
        displayNotification.state = Util.loadPreferenceState(displayNotification.identifier!)
        shortenUrls.state = Util.loadPreferenceState(shortenUrls.identifier!)
        launchAtLogin.state = Util.loadPreferenceState(launchAtLogin.identifier!)
        
        authField.stringValue = Util.getCredentials()
        
        validator = SRValidator(delegate: self)
        
        globalPasteShortcutRecorder.enabled = true
        globalPasteShortcutRecorder.bind(NSValueBinding, toObject: NSUserDefaultsController.sharedUserDefaultsController(), withKeyPath: "values.GlobalPaste", options: nil)
    }
    
    @IBAction func getCheckboxAction(sender : NSButton) {
        let state = sender.state == 0 ? false : true
        
        NSUserDefaults.standardUserDefaults().setBool(state, forKey: sender.identifier!)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        if (sender.identifier == makeSecret.identifier) {
            Util.getAppDelegate().toggleItem?.state = sender.state
        } else if (sender.identifier == launchAtLogin.identifier) {
            Util.launchAtLogin()
        }
    }
    
    
    @IBAction func authFieldAction(sender: NSTextField) {
        saveAuth(sender.stringValue)
    }
    
    @IBAction func saveAuthButton(sender: AnyObject) {
        saveAuth(authField!.stringValue)
    }
    
    
    @IBAction func defaultLanguageSelection(sender: NSComboBox) {
        if (contains(languagesList, sender.stringValue)) {
            NSUserDefaults.standardUserDefaults().setObject(sender.stringValue, forKey: "DefaultLanguage")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    func numberOfItemsInComboBox(aComboBox: NSComboBox) -> Int {
        return languagesList.count
    }
    
    
    func comboBox(aComboBox: NSComboBox, objectValueForItemAtIndex index: Int) -> AnyObject {
        return languagesList[index]
    }

    func comboBox(aComboBox: NSComboBox, completedString string: String) -> String? {
        for language in languagesList {
            if (count(language.commonPrefixWithString(string, options: NSStringCompareOptions.CaseInsensitiveSearch)) == count(string)) {
                return language
            }
        }
        
        return ""
    }
    
    func comboBox(aComboBox: NSComboBox, indexOfItemWithStringValue string: String) -> Int {
        var index = -1
        let findResult = find(languagesList, string)
        
        if (findResult != nil) {
            index = findResult!
        }
        
        return index
    }
    
    func saveAuth(auth: String) {
        if (auth.isEmpty) {
            Util.deleteCredentials()
        } else {
            Util.saveCredentials(auth)
        }
    }

    func shortcutRecorder(aRecorder: SRRecorderControl!, canRecordShortcut aShortcut: [NSObject : AnyObject]!) -> Bool {
        var error: NSError?
        var shortcut = aShortcut as NSDictionary

        var keyCode:UInt16 = UInt16(shortcut.valueForKey(SRShortcutKeyCode) as! Int)
        var flagsTaken:UInt = UInt(shortcut.valueForKey(SRShortcutModifierFlagsKey) as! Int)
        
        let isTaken:Bool = validator.isKeyCode(keyCode, andFlagsTaken: flagsTaken, error: &error)
        
        if (isTaken) {
            NSBeep()
            let window:NSWindow = self.view.window!
            presentError(error!, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
        }
        
        return !isTaken
    }
    
    func shortcutRecorderShouldBeginRecording(aRecorder: SRRecorderControl!) -> Bool {
        PTHotKeyCenter.sharedCenter().pause()
        return true
    }
    
    func shortcutRecorderDidEndRecording(aRecorder: SRRecorderControl!) {
        PTHotKeyCenter.sharedCenter().resume()
    }
    
    func shortcutRecorder(aRecorder: SRRecorderControl!, shouldUnconditionallyAllowModifierFlags aModifierFlags: UInt, forKeyCode aKeyCode: UInt16) -> Bool {
        // Keep required flags required.
        if ((aModifierFlags & aRecorder.requiredModifierFlags) != aRecorder.requiredModifierFlags) {
            return false
        }
        
        // Don't allow disallowed flags.
        if ((aModifierFlags & aRecorder.allowedModifierFlags) != aModifierFlags) {
            return true
        }
        
        
        let theKeyCode:Int = Int(aKeyCode)
        
        switch (theKeyCode) {
        case kVK_F1,
        kVK_F2,
        kVK_F3,
        kVK_F4,
        kVK_F5,
        kVK_F6,
        kVK_F7,
        kVK_F8,
        kVK_F9,
        kVK_F10,
        kVK_F11,
        kVK_F12,
        kVK_F13,
        kVK_F14,
        kVK_F15,
        kVK_F16,
        kVK_F17,
        kVK_F18,
        kVK_F19,
        kVK_F20:
            return true
        default:
            return false
        }
    }
    
    func shortcutValidatorShouldCheckMenu(aValidator: SRValidator!) -> Bool {
        return false
    }
    
    @IBAction func helpButtonClicked(sender: AnyObject) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: "https://github.com/settings/applications#personal-access-tokens")!)
    }
    
    override func viewWillAppear() {
        NSUserDefaultsController.sharedUserDefaultsController().addObserver(self, forKeyPath: "values.PrivateGists", options: NSKeyValueObservingOptions.Initial, context: nil)
    }
    
    override func viewWillDisappear() {
        NSUserDefaultsController.sharedUserDefaultsController().removeObserver(self, forKeyPath: "values.PrivateGists")
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (keyPath == "values.PrivateGists") {
            makeSecret!.state = Util.loadPreferenceState(makeSecret!.identifier!)
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}