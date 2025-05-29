# ResizablePopover

A Swift package that provides resizable popover windows for macOS applications.

## Features

- 🔄 Support for resizing popover windows by dragging edges and corners
- 📏 Configurable minimum and maximum size constraints
- 🎯 Precise mouse interaction with cursor feedback
- 🎨 Perfect integration with SwiftUI
- ⚡ High performance with smooth resizing experience

## Requirements

- macOS 10.15+
- Swift 5.9+

## Quick Start

Want to see it in action immediately? Check out the example project in the `Example/` folder!

1. Open `Example/ResizablePopover.xcodeproj`
2. Build and run
3. Experience the resizable popover windows

## Installation

### Swift Package Manager

In your Xcode project:

1. Select File → Add Package Dependencies...
2. Enter the repository URL: `https://github.com/YourUsername/ResizablePopover.git`
3. Choose version or branch
4. Click Add Package

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/YourUsername/ResizablePopover.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["ResizablePopover"]
)
```

## Usage

### Basic Usage

```swift
import SwiftUI
import ResizablePopover

struct ContentView: View {
    @State private var showPopover = false
    
    var body: some View {
        Button("Show Popover") {
            showPopover.toggle()
        }
        .popover(isPresented: $showPopover) {
            // Your popover content
            Text("This is a resizable popover")
                .frame(width: 200, height: 100)
        }
    }
}
```

### Advanced Usage

```swift
import Cocoa
import ResizablePopover

class ViewController: NSViewController {
    
    func showResizablePopover() {
        // Create a resizable popover
        let popover = ResizablePopover(
            minSize: NSSize(width: 150, height: 100),
            maxSize: NSSize(width: 800, height: 600)
        )
        
        // Set up content view controller
        let contentVC = NSViewController()
        contentVC.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        contentVC.view.wantsLayer = true
        contentVC.view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        popover.contentViewController = contentVC
        
        // Listen for size changes
        popover.resized = { newSize in
            print("Popover resized to: \(newSize)")
        }
        
        // Show the popover
        popover.show(
            relativeTo: someButton.bounds,
            of: someButton,
            preferredEdge: .maxY
        )
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import ResizablePopover

struct SwiftUIPopoverContent: View {
    var body: some View {
        VStack {
            Text("Resizable SwiftUI Content")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("• Drag edges to resize width/height")
                Text("• Drag corners to resize both dimensions")
                Text("• Hover over edges for resize cursor")
            }
            .padding()
        }
        .frame(minWidth: 200, minHeight: 150)
        .padding()
    }
}

// In your view controller
func showSwiftUIPopover() {
    let popover = ResizablePopover(
        minSize: NSSize(width: 200, height: 150),
        maxSize: NSSize(width: 600, height: 400)
    )
    
    let hostingController = NSHostingController(rootView: SwiftUIPopoverContent())
    popover.contentViewController = hostingController
    
    popover.show(
        relativeTo: triggerView.bounds,
        of: triggerView,
        preferredEdge: .maxY
    )
}
```

## API Reference

### ResizablePopover

The main resizable popover class that inherits from `NSPopover`.

#### Initialization

```swift
init(minSize: NSSize, maxSize: NSSize)
```

- `minSize`: The minimum size of the popover
- `maxSize`: The maximum size of the popover

#### Properties

- `resized: ((NSSize) -> Void)?`: Callback called when the popover size changes

#### Methods

Inherits all methods from `NSPopover`, including:

- `show(relativeTo:of:preferredEdge:)`: Show the popover
- `close()`: Close the popover

## Project Structure

```
ResizablePopover/
├── Package.swift              # Swift Package configuration
├── README.md                  # Main documentation
├── Sources/
│   └── ResizablePopover/
│       └── ResizablePopover.swift  # Main implementation
└── Example/                   # Example project
    ├── README.md              # Example project documentation
    ├── ResizablePopover.xcodeproj
    ├── ResizablePopover/      # Example app source code
    ├── ResizablePopoverTests/
    └── ResizablePopoverUITests/
```

## Notes

1. This package only supports macOS platform
2. Popover resizing is achieved by detecting mouse position at edges and corners
3. It's recommended to set reasonable minimum and maximum sizes for good user experience
4. During resizing, the popover temporarily disables animations to reduce flickering

## Contributing

Issues and Pull Requests are welcome!

## License

[Add your license information here] 