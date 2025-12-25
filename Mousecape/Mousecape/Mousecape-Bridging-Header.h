//
//  Mousecape-Bridging-Header.h
//  Mousecape
//
//  Bridging header for SwiftUI migration
//  This file exposes Objective-C classes to Swift
//

#ifndef Mousecape_Bridging_Header_h
#define Mousecape_Bridging_Header_h

// System frameworks (must be imported first)
#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

// Core Data Models
#import "MCCursor.h"
#import "MCCursorLibrary.h"

// Controllers
#import "MCLibraryController.h"

// Scale utilities (private CoreGraphics API)
#import "scale.h"

#endif /* Mousecape_Bridging_Header_h */
