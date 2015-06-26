import Foundation
import SwiftHTTP

class Util : NSObject {
    
    class func loadLanguages() -> NSDictionary {
        let path = NSBundle.mainBundle().pathForResource("languages.json", ofType: nil)
        
        var possibleContent = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
        
        if let text = possibleContent {
            var jsonError: NSError?
            let json = NSJSONSerialization.JSONObjectWithData(text.dataUsingEncoding(NSUTF8StringEncoding)!, options: nil, error: &jsonError) as! NSDictionary
            return json
        }
        
        return NSDictionary()
    }
    
    class func displayError() {
        Util.getAppDelegate().displayError()
    }
    
    class func displayNormal() {
        let appDelegate = Util.getAppDelegate()
        appDelegate.statusItem.image = appDelegate.icon
    }
    
    class func displayWorking() {
        let appDelegate = Util.getAppDelegate()
        appDelegate.statusItem.image = appDelegate.workingIcon
    }
    
    class func displayAccessDenied() {
        dispatch_async(dispatch_get_main_queue(),{
            Util.getAppDelegate().displayPreferencesWithError()
        })
    }
    
    class func createGistFromClipboard() {
        let content = NSPasteboard.generalPasteboard().stringForType("public.utf8-plain-text")
        
        if (content == nil) {
            return;
        }
        
        createGistFromString(content!)
    }
    
    class func createGistFromString(content: NSString) {
        if (content.length == 0) {
            return
        }
        
        var filename = "gistfile1.txt"
        let selectedLanguage = NSUserDefaults.standardUserDefaults().objectForKey("DefaultLanguage") as! String
        let selectedLanguageKey: AnyObject? = Util.getAppDelegate().languages.objectForKey(selectedLanguage)
        
        if (selectedLanguageKey != nil) {
            filename = selectedLanguageKey as! String
        }
        
        Util.createGist([filename: ["content": content]])
    }
    
    class func createGistFromPasteboard(pasteboard: NSPasteboard) {
        let possibleItemClasses = [Util.classFromType(NSString.self), Util.classFromType(NSURL.self)]
        let pasteboardOptions = [NSPasteboardURLReadingFileURLsOnlyKey: NSNumber(bool: true)]
        let pasteboardItems:Array = pasteboard.readObjectsForClasses(possibleItemClasses, options: pasteboardOptions)!
        
        if (pasteboardItems.count == 1 && pasteboardItems[0].isKindOfClass(NSString.self) && pasteboardItems[0].length > 0) {
            createGistFromString(pasteboardItems[0] as! NSString)
        } else if (pasteboardItems.count > 0) {
            var files = Dictionary<String, AnyObject>()
            
            for sourceFile in pasteboardItems {
                var error: NSError?
                let fileContent = NSString(contentsOfURL: sourceFile as! NSURL, encoding: NSUTF8StringEncoding, error: &error)
                
                if (fileContent != nil && error == nil && fileContent?.length > 0) {
                    files.updateValue(["content": fileContent!], forKey: sourceFile.lastPathComponent)
                }
            }
            
            Util.createGist(files)
        }
    }
    
    class func createGist(files: AnyObject) {
        Util.displayWorking()
        
        let pasteBoard = NSPasteboard.generalPasteboard()
        
        let isPrivate = NSUserDefaults.standardUserDefaults().boolForKey("PrivateGists")
        
        let params: Dictionary<String,AnyObject> = ["public": !isPrivate, "files": files]
        
        var request = Util.getRequest(true)
        
        request.POST("https://api.github.com/gists", parameters: params, completionHandler: {(response: HTTPResponse) in
            if let err = response.error {
                if (err.code == 401) {
                    Util.displayAccessDenied()
                }
                
                Util.displayError()
            } else if let data = response.responseObject as? NSDictionary {
                let dict: NSDictionary = response.responseObject as! NSDictionary

                var str: String = dict["html_url"] as! String
                let gistId: String = dict["id"] as! String
                
                let hasCredentials = dict["owner"] != nil

                var shortenRequest = HTTPTask()

                if (NSUserDefaults.standardUserDefaults().boolForKey("ShortenUrl")) {
                    shortenRequest.POST("http://git.io", parameters: [ "url": str ], completionHandler: {(redirectresponse: HTTPResponse) in
                        if let err = response.error {
                            if (err.code == 401) {
                                Util.displayError()
                            }
                            return
                        }

                        if (redirectresponse.statusCode == 201) {
                            str = redirectresponse.headers!["Location"] as String!
                        }
                        
                        self.finishCreatingGist(str, gistId: gistId, files: files, hasCredentials: hasCredentials)
                    })
                } else {
                    self.finishCreatingGist(str, gistId: gistId, files: files, hasCredentials: hasCredentials)
                }
            }
        })
        
    }
    
    class func finishCreatingGist(str: String, gistId: String, files: AnyObject, hasCredentials: Bool) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        
        if (NSUserDefaults.standardUserDefaults().boolForKey("CopyToClipboard")) {
            pasteBoard.clearContents()
            pasteBoard.writeObjects([str])
        }
        
        let appDelegate = self.getAppDelegate()
        
        var menuCount = appDelegate.recentMenu?.itemArray.count
        menuCount = menuCount! - 2
        
        if (menuCount >= 5) {
            appDelegate.recentMenu?.removeItemAtIndex(menuCount! - 1)
        }
        
        var menuTitle = ""
        let dict = files as! NSDictionary
        
        if (files.count > 1) {
            menuTitle = ", ".join(dict.allKeys as! [String])
        } else {
            menuTitle = dict.allValues[0]["content"] as! String
        }
        
        if (count(menuTitle) > 45) {
            menuTitle = (menuTitle as NSString).substringToIndex(45) + "..."
        }
        
        appDelegate.recentMenu?.insertItem(Util.generateRecentMenuItem(menuTitle, representedObject: str), atIndex: 0)
        
        if (NSUserDefaults.standardUserDefaults().boolForKey("DisplayNotification")) {
            let userInfo: Dictionary<String,AnyObject> = ["gistId": gistId, "gistUrl": str, "menuTitle": menuTitle]
            
            self.createNotification("Created Gist!", informativeText: str, userInfo: userInfo, hasCredentials: hasCredentials)
        } else {
            if (NSUserDefaults.standardUserDefaults().boolForKey("PlaySound")) {
                NSSound(named: "Glass")?.play()
            }
        }
        
        Util.displayNormal()
    }
    
    
    class func deleteGist(id: String, url: String) {
        Util.displayNormal()

        let pasteBoard = NSPasteboard.generalPasteboard()
        
        Util.getRequest(false).DELETE("https://api.github.com/gists/" + id, parameters: nil, completionHandler: {(response: HTTPResponse) in
            if let err = response.error {
                if (err.code == 401) {
                    Util.displayError()
                }
                return
            }

            let appDelegate = self.getAppDelegate()
            let menuItem = appDelegate.recentMenu?.itemWithTitle(url)
            
            if (menuItem != nil) {
                appDelegate.recentMenu?.removeItem(menuItem!)
            }
            
            if (NSUserDefaults.standardUserDefaults().boolForKey("CopyToClipboard")) {
                pasteBoard.clearContents()
            }

            return
        })
    }
    
    class func generateRecentMenuItem(title: String, representedObject: String) -> NSMenuItem {
        let menuItem = NSMenuItem()
        
        menuItem.title = title
        menuItem.action = Selector("pressedLatestMenu:")
        menuItem.representedObject = representedObject
        
        return menuItem
    }
    
    class func getRequest(json: Bool) -> HTTPTask {
        let credentials = Util.getCredentials()
        var request = HTTPTask()

        if (json) {
            request.requestSerializer = JSONRequestSerializer()
            request.responseSerializer = JSONResponseSerializer()
        }
        
        if (!credentials.isEmpty) {
            let credentials = "\(credentials):x-oauth-basic".dataUsingEncoding(NSUTF8StringEncoding)
            let base64String = "Basic \(credentials!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(0)))"
            
            request.requestSerializer.headers["Authorization"] = base64String
        }
        
        request.requestSerializer.headers["User-Agent"] = "Harpia/\(versionBuild())"
        
        return request
    }

    class func createNotification(message: String, informativeText: String, userInfo: [NSObject: AnyObject], hasCredentials: Bool) {
        let notification:NSUserNotification = NSUserNotification()
        notification.title = "Harpia"
        notification.subtitle = message
        notification.informativeText = informativeText
        
        if (hasCredentials) {
            notification.actionButtonTitle = "Delete"
            notification.hasActionButton = true
        } else {
            notification.hasActionButton = false
        }
        
        notification.userInfo = userInfo

        
        if (NSUserDefaults.standardUserDefaults().boolForKey("PlaySound")) {
            //notification.soundName = NSUserNotificationDefaultSoundName
            notification.soundName = "Glass"
        }
        
        NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
    }
    
    
    class func removeNotification(timer: NSTimer) {        
        let notification: NSUserNotification = timer.userInfo as! NSUserNotification
        NSUserNotificationCenter.defaultUserNotificationCenter().removeDeliveredNotification(notification)
    }
    
    class func getAppDelegate() -> AppDelegate {
        return (NSApplication.sharedApplication().delegate as! AppDelegate)
    }
    
    class func classFromType<T:NSObject>(type: T.Type) -> AnyObject! {
        return T.valueForKey("self")
    }
    
    class func loadPreferenceState(identifier: String) -> Int {
        let state = NSUserDefaults.standardUserDefaults().boolForKey(identifier) ? 1 : 0
        return state
    }
    
    
    class func getCredentials() -> String {
        let loadCredentials = SSKeychain.passwordForService("Harpia", account: "Gist")
        
        if (loadCredentials != nil) {
            return loadCredentials!
        }
        
        return ""
    }
    
    class func deleteCredentials() {
        SSKeychain.deletePasswordForService("Harpia", account: "Gist")
    }
    
    class func saveCredentials(password: String) {
        SSKeychain.setPassword(password, forService: "Harpia", account: "Gist")
    }
    
    class func appVersion() -> String {
        return NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
    }
    
    class func appBuild() -> String {
        return NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
    }
    
    class func versionBuild() -> String {
        let version = appVersion(), build = appBuild()
        
        return version == build ? "\(version)" : "\(version)b\(build)"
    }
    
    class func launchAtLogin() {
        let loginController = StartAtLoginController(identifier: "se.DMarby.HarpiaHelper")

        let isLoginItem = loginController.startAtLogin
        let shouldBeLoginItem = NSUserDefaults.standardUserDefaults().boolForKey("LaunchAtLogin")
        
        if (shouldBeLoginItem && !isLoginItem) {
            loginController.startAtLogin = true
        } else if (!shouldBeLoginItem && isLoginItem) {
            loginController.startAtLogin = false
        }
    }
    
    class func delay(delay:Double, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            dispatch_get_main_queue(), closure)
    }
}