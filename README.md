# ResizablePopover

A Swift package that provides resizable popover windows for macOS applications.

## Features

- 🔄 Support for resizing popover windows by dragging edges and corners
- 📏 Configurable minimum and maximum size constraints
- 🎯 Precise mouse interaction with cursor feedback
- ⚡ High performance with smooth resizing experience

## Requirements

- macOS 14.0+
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

```swift
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    
    private lazy var contentViewController: NSViewController = {
        let contentView = NSView()
        let textField = NSTextField(labelWithString: "This is a resizable popover example.")
        contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        let result = NSViewController()
        result.view = contentView
        return result
    }()
    
    private lazy var popoverController: ResizablePopover = {
        let result = ResizablePopover(minSize: NSMakeSize(300, 300), maxSize: NSMakeSize(600, 600))
        result.contentViewController = contentViewController
        return result
    }()

    @IBAction func showPopover(_ sender: NSButton) {
        popoverController.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
}

```

## Contributing

Issues and Pull Requests are welcome!

## License

[Add your license information here] 
