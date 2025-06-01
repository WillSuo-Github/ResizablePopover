import Cocoa
import SwiftUI

// Enum to identify which edge/corner is being interacted with
enum ResizingEdge {
    case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight, none

    var cursor: NSCursor {
        switch self {
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        case .topLeft, .bottomRight:
            // \ diagonal cursor (NW-SE resize)
            if let cursor = NSCursor.value(forKey: "_windowResizeNorthWestSouthEastCursor") as? NSCursor {
                return cursor
            }
            // Try alternative approach
            if let cursor = NSCursor.perform(Selector(("_windowResizeNorthWestSouthEastCursor")))?.takeUnretainedValue() as? NSCursor {
                return cursor
            }
            return .resizeUpDown // Better fallback
        case .topRight, .bottomLeft:
            // / diagonal cursor (NE-SW resize)
            if let cursor = NSCursor.value(forKey: "_windowResizeNorthEastSouthWestCursor") as? NSCursor {
                return cursor
            }
            // Try alternative approach
            if let cursor = NSCursor.perform(Selector(("_windowResizeNorthEastSouthWestCursor")))?.takeUnretainedValue() as? NSCursor {
                return cursor
            }
            return .resizeLeftRight // Better fallback
        case .none:
            return .arrow
        }
    }
}

public class ResizablePopover: NSPopover {
    public let minSize: NSSize
    public let maxSize: NSSize
    public var resized: ((NSSize) -> Void)?

    private var userProvidedViewController: NSViewController?
    
    // Window event monitors
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    
    // Drag state
    private var currentDragEdge: ResizingEdge = .none
    private var mouseDownScreenLocation: NSPoint?
    private var initialPopoverContentSize: NSSize?
    private var initialPopoverPosition: NSPoint?
    
    private let edgeSensitivity: CGFloat = 4.0
    private let cornerSensitivity: CGFloat = 4.0

    override public var contentViewController: NSViewController? {
        get {
            return userProvidedViewController
        }
        set {
            userProvidedViewController = newValue
            super.contentViewController = newValue
            
            if let newVC = newValue {
                // Initial size setup - use reasonable defaults
                var initialSize = newVC.view.fittingSize
                initialSize.width = max(minSize.width, min(maxSize.width, initialSize.width))
                initialSize.height = max(minSize.height, min(maxSize.height, initialSize.height))
                
                self.contentSize = initialSize
            }
        }
    }

    public init(minSize: NSSize, maxSize: NSSize, resized: ((NSSize) -> Void)? = nil) {
        self.minSize = minSize
        self.maxSize = maxSize
        self.resized = resized
        super.init()
    }

    required public init?(coder: NSCoder) {
        self.minSize = NSSize(width: 50, height: 50) // Default min
        self.maxSize = NSSize(width: 800, height: 600) // Default max
        super.init(coder: coder)
    }
    
    private func edge(forPoint screenPoint: NSPoint) -> ResizingEdge {
        guard let popoverWindow = contentViewController?.view.window else { 
            return .none 
        }
        
        // Get the content rect in screen coordinates
        let windowFrame = popoverWindow.frame
        let contentRect = popoverWindow.contentRect(forFrameRect: windowFrame)
        
        // Check if point is within content bounds
        guard contentRect.contains(screenPoint) else {
            return .none
        }
        
        // Convert to content-relative coordinates
        let x = screenPoint.x - contentRect.origin.x
        let y = screenPoint.y - contentRect.origin.y
        let width = contentRect.width
        let height = contentRect.height
        
        // Check corners first (higher priority) - using content coordinates
        if x <= cornerSensitivity && y <= cornerSensitivity {
            return .bottomLeft
        }
        if x >= width - cornerSensitivity && y <= cornerSensitivity {
            return .bottomRight
        }
        if x <= cornerSensitivity && y >= height - cornerSensitivity {
            return .topLeft
        }
        if x >= width - cornerSensitivity && y >= height - cornerSensitivity {
            return .topRight
        }
        
        // Check edges
        if y <= edgeSensitivity {
            return .bottom
        }
        if y >= height - edgeSensitivity {
            return .top
        }
        if x <= edgeSensitivity {
            return .left
        }
        if x >= width - edgeSensitivity {
            return .right
        }
        
        return .none
    }
    
    private func setupEventMonitors() {
        // Clean up old monitors
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Global mouse event monitor (for mouse movement and dragging)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
            self.handleGlobalMouseEvent(event)
        }
        
        // Local mouse event monitor (for mouse down and up)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .mouseMoved, .leftMouseDragged]) { event in
            return self.handleLocalMouseEvent(event) ?? event
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
    }
    
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        guard isShown else { return }
        
        let screenLocation = NSEvent.mouseLocation
        let edge = edge(forPoint: screenLocation)
        
        if event.type == .mouseMoved {
            edge.cursor.set()
        } else if event.type == .leftMouseDragged && currentDragEdge != .none {
            handleMouseDrag(screenLocation)
        }
    }
    
    private func handleLocalMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard isShown else { return event }
        
        let screenLocation = NSEvent.mouseLocation
        let edge = edge(forPoint: screenLocation)
        
        switch event.type {
        case .leftMouseDown:
            if edge != .none {
                currentDragEdge = edge
                mouseDownScreenLocation = screenLocation
                initialPopoverContentSize = contentSize
                if let popoverWindow = contentViewController?.view.window {
                    initialPopoverPosition = popoverWindow.frame.origin
                }
                return nil // Consume event
            }
            
        case .leftMouseUp:
            if currentDragEdge != .none {
                currentDragEdge = .none
                mouseDownScreenLocation = nil
                initialPopoverContentSize = nil
                initialPopoverPosition = nil
                NSCursor.arrow.set()
                resized?(contentSize)
                return nil // Consume event
            }
            
        case .mouseMoved:
            edge.cursor.set()
            
        case .leftMouseDragged:
            if currentDragEdge != .none {
                handleMouseDrag(screenLocation)
                return nil // Consume event
            }
            
        default:
            break
        }
        
        return event
    }
    
    private func handleMouseDrag(_ currentScreenLocation: NSPoint) {
        guard let mouseDownScreenLocation = self.mouseDownScreenLocation,
              let initialSize = self.initialPopoverContentSize,
              let initialPosition = self.initialPopoverPosition,
              currentDragEdge != .none else {
            return
        }

        let deltaX = currentScreenLocation.x - mouseDownScreenLocation.x
        let deltaY = currentScreenLocation.y - mouseDownScreenLocation.y
        
        // Add minimum movement threshold to reduce jitter
        let minDelta: CGFloat = 2.0
        if abs(deltaX) < minDelta && abs(deltaY) < minDelta {
            return
        }

        var newSize = initialSize
        var newPosition = initialPosition

        switch currentDragEdge {
        case .top:
            newSize.height += deltaY
        case .bottom:
            newSize.height -= deltaY
            newPosition.y += deltaY
        case .left:
            newSize.width -= deltaX
            newPosition.x += deltaX
        case .right:
            newSize.width += deltaX
        case .topLeft:
            newSize.height += deltaY
            newSize.width -= deltaX
            newPosition.x += deltaX
        case .topRight:
            newSize.height += deltaY
            newSize.width += deltaX
        case .bottomLeft:
            newSize.height -= deltaY
            newSize.width -= deltaX
            newPosition.y += deltaY
            newPosition.x += deltaX
        case .bottomRight:
            newSize.height -= deltaY
            newSize.width += deltaX
            newPosition.y += deltaY
        case .none:
            return
        }

        // Apply minimum/maximum size constraints
        let constrainedWidth = max(minSize.width, min(maxSize.width, newSize.width))
        let constrainedHeight = max(minSize.height, min(maxSize.height, newSize.height))
        
        // Round to integer pixels to avoid sub-pixel rendering issues
        newSize.width = round(constrainedWidth)
        newSize.height = round(constrainedHeight)
        newPosition.x = round(newPosition.x)
        newPosition.y = round(newPosition.y)
        
        // If size was constrained, adjust position
        if constrainedWidth != newSize.width {
            if currentDragEdge == .left || currentDragEdge == .topLeft || currentDragEdge == .bottomLeft {
                newPosition.x = round(initialPosition.x + (initialSize.width - newSize.width))
            }
        }
        if constrainedHeight != newSize.height {
            if currentDragEdge == .bottom || currentDragEdge == .bottomLeft || currentDragEdge == .bottomRight {
                newPosition.y = round(initialPosition.y + (initialSize.height - newSize.height))
            }
        }

        // Only update when size actually changes
        if abs(newSize.width - contentSize.width) >= 1.0 || abs(newSize.height - contentSize.height) >= 1.0 {
            // Temporarily disable animation to reduce jitter
            let wasAnimating = animates
            animates = false
            
            contentSize = newSize
            
            // Restore animation setting
            animates = wasAnimating
            
            resized?(newSize)
        }
    }
    
    override public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge edge: NSRectEdge) {
        // Ensure contentSize complies with min/max limits before showing
        var currentSize = self.contentSize
        currentSize.width = max(minSize.width, min(maxSize.width, currentSize.width))
        currentSize.height = max(minSize.height, min(maxSize.height, currentSize.height))
        if self.contentSize != currentSize {
            self.contentSize = currentSize
        }

        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: edge)
        
        // Set up event monitors
        setupEventMonitors()
    }
    
    override public func close() {
        removeEventMonitors()
        super.close()
    }
} 
