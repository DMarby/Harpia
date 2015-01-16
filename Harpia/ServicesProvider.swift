import Cocoa

class ServicesProvider : NSObject {
    
    func createGistFromService(pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        Util.createGistFromPasteboard(pasteboard)
    }
}