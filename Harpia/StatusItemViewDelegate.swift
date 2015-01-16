import Cocoa

class StatusItemViewDelegate : NSObject, NSWindowDelegate, NSDraggingDestination {
    
    func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.Copy
    }
    
    func performDragOperation(sender: NSDraggingInfo) -> Bool {
        Util.createGistFromPasteboard(sender.draggingPasteboard())
        return true
    }
}