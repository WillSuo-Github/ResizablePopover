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

// Custom NSView to handle mouse events for resizing. It's an overlay.
fileprivate class ResizingHandleView: NSView {
    weak var popover: ResizablePopover?

    private var currentDragEdge: ResizingEdge = .none
    private var mouseDownScreenLocation: NSPoint?
    private var initialPopoverContentSize: NSSize?
    private var initialPopoverPosition: NSPoint?

    private let edgeSensitivity: CGFloat = 8.0
    private let cornerSensitivity: CGFloat = 20.0

    override var isFlipped: Bool { true } // Use standard coordinate system

    init(popover: ResizablePopover) {
        self.popover = popover
        super.init(frame: .zero)
        self.wantsLayer = true
        // Add semi-transparent red background for debugging
        self.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.1).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Clear all existing tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }
        
        guard bounds.width > 0 && bounds.height > 0 else { 
            return 
        }

        // Add a tracking area for the entire view to handle mouse movement
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect, .assumeInside],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func layout() {
        super.layout()
        updateTrackingAreas()
    }
    
    private func edge(forLocalPoint point: NSPoint) -> ResizingEdge {
        let x = point.x
        let y = point.y
        let width = bounds.width
        let height = bounds.height
        
        // Check corners first (higher priority)
        if x <= cornerSensitivity && y <= cornerSensitivity {
            return .topLeft
        }
        if x >= width - cornerSensitivity && y <= cornerSensitivity {
            return .topRight
        }
        if x <= cornerSensitivity && y >= height - cornerSensitivity {
            return .bottomLeft
        }
        if x >= width - cornerSensitivity && y >= height - cornerSensitivity {
            return .bottomRight
        }
        
        // Check edges
        if y <= edgeSensitivity {
            return .top
        }
        if y >= height - edgeSensitivity {
            return .bottom
        }
        if x <= edgeSensitivity {
            return .left
        }
        if x >= width - edgeSensitivity {
            return .right
        }
        
        return .none
    }

    override func mouseEntered(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        let hoverEdge = edge(forLocalPoint: locationInView)
        hoverEdge.cursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseMoved(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        let hoverEdge = edge(forLocalPoint: locationInView)
        hoverEdge.cursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let popover = self.popover else { return }
        
        let locationInView = convert(event.locationInWindow, from: nil)
        currentDragEdge = edge(forLocalPoint: locationInView)
        
        if currentDragEdge != .none {
            mouseDownScreenLocation = NSEvent.mouseLocation
            initialPopoverContentSize = popover.contentSize
            
            // Get the current position of the popover window
            if let popoverWindow = popover.contentViewController?.view.window {
                initialPopoverPosition = popoverWindow.frame.origin
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let popover = self.popover,
              let mouseDownScreenLocation = self.mouseDownScreenLocation,
              let initialSize = self.initialPopoverContentSize,
              let initialPosition = self.initialPopoverPosition,
              currentDragEdge != .none else {
            return
        }

        let currentScreenMouseLocation = NSEvent.mouseLocation
        let deltaX = currentScreenMouseLocation.x - mouseDownScreenLocation.x
        let deltaY = currentScreenMouseLocation.y - mouseDownScreenLocation.y

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
        let constrainedWidth = max(popover.minSize.width, min(popover.maxSize.width, newSize.width))
        let constrainedHeight = max(popover.minSize.height, min(popover.maxSize.height, newSize.height))
        
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
        if abs(newSize.width - popover.contentSize.width) >= 1.0 || abs(newSize.height - popover.contentSize.height) >= 1.0 {
            // Temporarily disable animation to reduce jitter
            let wasAnimating = popover.animates
            popover.animates = false
            
            popover.contentSize = newSize
            
            // Restore animation setting
            popover.animates = wasAnimating
            
            // Force immediate layout update to avoid delayed updates causing jitter
            if let popoverWindow = popover.contentViewController?.view.window {
                var windowFrame = popoverWindow.frame
                windowFrame.origin = newPosition
                windowFrame.size = newSize
                popoverWindow.setFrame(windowFrame, display: true)
            }
            
            popover.resized?(newSize)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if currentDragEdge != .none {
            popover?.resized?(popover!.contentSize)
        }
        currentDragEdge = .none
        mouseDownScreenLocation = nil
        initialPopoverContentSize = nil
        initialPopoverPosition = nil
        NSCursor.arrow.set()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if !bounds.contains(point) {
            return nil
        }
        
        let edge = edge(forLocalPoint: point)
        
        if edge != .none {
            return self
        } else {
            return nil // Let click events pass through to the underlying SwiftUI view
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Only accept first mouse click in edge areas
        if let event = event {
            let locationInView = convert(event.locationInWindow, from: nil)
            let edge = edge(forLocalPoint: locationInView)
            return edge != .none
        }
        return false
    }
}

// Container view for the popover content
fileprivate class PopoverContainerView: NSView {
    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
    }

    override func layout() {
        super.layout()
        
        // Ensure ResizingHandleView frame is correctly set and tracking areas are updated
        for subview in subviews {
            if let handleView = subview as? ResizingHandleView {
                handleView.frame = bounds
                // Ensure tracking areas are updated immediately
                handleView.needsLayout = true
                handleView.layout()
            }
        }
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        
        // Ensure all subviews are adjusted to the new size
        for subview in subviews {
            subview.frame = bounds
            if let handleView = subview as? ResizingHandleView {
                handleView.updateTrackingAreas()
            }
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        return result
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

public class ResizablePopover: NSPopover {
    public let minSize: NSSize
    public let maxSize: NSSize
    public var resized: ((NSSize) -> Void)?

    private var userProvidedViewController: NSViewController?
    private var wrapperViewController: NSViewController?
    private var resizingHandleView: ResizingHandleView?
    
    // Window event monitors
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    
    // Drag state
    private var currentDragEdge: ResizingEdge = .none
    private var mouseDownScreenLocation: NSPoint?
    private var initialPopoverContentSize: NSSize?
    private var initialPopoverPosition: NSPoint?
    
    private let edgeSensitivity: CGFloat = 8.0
    private let cornerSensitivity: CGFloat = 20.0

    override public var contentViewController: NSViewController? {
        get {
            return userProvidedViewController
        }
        set {
            guard newValue !== wrapperViewController else {
                if super.contentViewController !== newValue {
                     super.contentViewController = newValue
                }
                return
            }
            
            userProvidedViewController = newValue
            
            // Clean up old views
            resizingHandleView?.removeFromSuperview()
            wrapperViewController?.view.subviews.forEach { $0.removeFromSuperview() }

            if let newUsersVC = newValue {
                let newWrapperVC = NSViewController()
                let containerView = PopoverContainerView() 
                newWrapperVC.view = containerView

                // First add user content view (at the bottom layer)
                newUsersVC.view.translatesAutoresizingMaskIntoConstraints = false 
                containerView.addSubview(newUsersVC.view)

                // Then add resize handle view (at the top layer)
                let handleView = ResizingHandleView(popover: self)
                handleView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(handleView)
                self.resizingHandleView = handleView 
                
                // Set up constraints
                NSLayoutConstraint.activate([
                    // User content view constraints
                    newUsersVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                    newUsersVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                    newUsersVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    newUsersVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

                    // ResizingHandleView constraints (at top layer)
                    handleView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    handleView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                    handleView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    handleView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
                ])
                
                self.wrapperViewController = newWrapperVC
                super.contentViewController = newWrapperVC
                
                // Initial size setup - use reasonable defaults
                var initialSize = newUsersVC.view.fittingSize
                if initialSize == .zero || initialSize.width < 50 || initialSize.height < 50 {
                    initialSize = NSSize(width: 300, height: 200) // Reasonable default size
                }
                initialSize.width = max(minSize.width, min(maxSize.width, initialSize.width))
                initialSize.height = max(minSize.height, min(maxSize.height, initialSize.height))
                
                self.contentSize = initialSize
                
                // Force update container view frame
                containerView.frame = NSRect(origin: .zero, size: initialSize)
                handleView.frame = containerView.bounds
                
                // Perform layout immediately
                containerView.layoutSubtreeIfNeeded()

            } else {
                self.resizingHandleView = nil
                self.wrapperViewController = nil
                super.contentViewController = nil
            }
        }
    }

    public init(minSize: NSSize, maxSize: NSSize) {
        self.minSize = minSize
        self.maxSize = maxSize
        super.init()
    }

    required public init?(coder: NSCoder) {
        self.minSize = NSSize(width: 50, height: 50) // Default min
        self.maxSize = NSSize(width: 800, height: 600) // Default max
        super.init(coder: coder)
        // Potentially read min/max from coder if stored
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
            
            // Force immediate layout update to avoid delayed updates causing jitter
            if let containerView = wrapperViewController?.view {
                containerView.needsLayout = true
                containerView.layoutSubtreeIfNeeded()
            }
            
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
        
        // Force layout update immediately after showing
        DispatchQueue.main.async {
            if let containerView = self.wrapperViewController?.view {
                containerView.frame = NSRect(origin: .zero, size: self.contentSize)
                containerView.layoutSubtreeIfNeeded()
                
                // Force update ResizingHandleView frame and tracking areas
                if let handleView = self.resizingHandleView {
                    handleView.frame = containerView.bounds
                    handleView.updateTrackingAreas()
                }
            }
        }
        
        // Delayed update to ensure everything is properly set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let containerView = self.wrapperViewController?.view,
               let handleView = self.resizingHandleView {
                
                if handleView.bounds.width == 0 || handleView.bounds.height == 0 {
                    handleView.frame = containerView.bounds
                    handleView.updateTrackingAreas()
                }
            }
        }
    }
    
    override public func close() {
        removeEventMonitors()
        super.close()
    }
} 
