import Cocoa

class NotificationCenterDelegate : NSObject, NSUserNotificationCenterDelegate {
    
    func userNotificationCenter(center: NSUserNotificationCenter!, shouldPresentNotification notification: NSUserNotification!) -> Bool {
        return true
    }
    
    func removeNotification(timer: NSTimer) {
        Util.removeNotification(timer)
    }
    
    func userNotificationCenter(center: NSUserNotificationCenter!, didDeliverNotification notification: NSUserNotification!) {
        NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: "removeNotification:", userInfo: notification, repeats: false)
    }

    func userNotificationCenter(center: NSUserNotificationCenter!, didActivateNotification notification: NSUserNotification!) {
        let userInfo:Dictionary<String,String!> = notification.userInfo as Dictionary<String,String!>
        
        if (notification.activationType == NSUserNotificationActivationType.ActionButtonClicked) {
            Util.deleteGist(userInfo["gistId"]!, url: userInfo["menuTitle"]!)
        } else if (notification.activationType == NSUserNotificationActivationType.ContentsClicked) {
            let url = userInfo["gistUrl"]! as String
            NSWorkspace.sharedWorkspace().openURL(NSURL(string: url)!)
        }
        
        center.removeDeliveredNotification(notification)
    }    
}