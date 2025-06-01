//
//  AppDelegate.swift
//  ResizablePopover
//
//  Created by will Suo on 2025/5/29.
//

import Cocoa

@main
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
        let result = ResizablePopover(minSize: NSMakeSize(300, 300), maxSize: NSMakeSize(600, 600)) { newSize in
            print("Popover resized to: \(newSize)")
        }
        result.contentViewController = contentViewController
        return result
    }()


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


    @IBAction func showPopover(_ sender: NSButton) {
        popoverController.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
}

