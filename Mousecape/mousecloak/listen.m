//
//  listen.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "listen.h"
#import "apply.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "MCPrefs.h"
#import "CGSCursor.h"
#import <Cocoa/Cocoa.h>
#import "scale.h"

NSString *appliedCapePathForUser(NSString *user) {
    // Validate user - must not be empty or contain path separators
    if (!user || user.length == 0 || [user containsString:@"/"] || [user containsString:@".."]) {
        MMLog(BOLD RED "Invalid username" RESET);
        return nil;
    }

    NSString *home = NSHomeDirectoryForUser(user);
    if (!home) {
        MMLog(BOLD RED "Could not get home directory for user" RESET);
        return nil;
    }

    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, (NSString *)kCFPreferencesCurrentHost);

    // Validate identifier - remove any path traversal attempts
    if (ident && ([ident containsString:@"/"] || [ident containsString:@".."])) {
        MMLog(BOLD RED "Invalid cape identifier" RESET);
        return nil;
    }

    if (!ident || ident.length == 0) {
        return nil;
    }

    NSString *appSupport = [home stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *capePath = [[[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByAppendingPathComponent:ident] stringByAppendingPathExtension:@"cape"];

    // Ensure the final path is within the expected directory
    NSString *standardPath = [capePath stringByStandardizingPath];
    NSString *expectedPrefix = [[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByStandardizingPath];
    if (![standardPath hasPrefix:expectedPrefix]) {
        MMLog(BOLD RED "Path traversal detected" RESET);
        return nil;
    }

    return capePath;
}

static void UserSpaceChanged(SCDynamicStoreRef	store, CFArrayRef changedKeys, void *info) {
    CFStringRef currentConsoleUser = SCDynamicStoreCopyConsoleUser(store, NULL, NULL);

    MMLog("Current user is %s", [(__bridge NSString *)currentConsoleUser UTF8String]);

    if (!currentConsoleUser || CFEqual(currentConsoleUser, CFSTR("loginwindow"))) {
        return;
    }

    NSString *appliedPath = appliedCapePathForUser((__bridge NSString *)currentConsoleUser);
    MMLog(BOLD GREEN "User Space Changed to %s, applying cape..." RESET, [(__bridge NSString *)currentConsoleUser UTF8String]);

    // Only attempt to apply if there's a valid cape path
    if (appliedPath) {
        if (!applyCapeAtPath(appliedPath)) {
            MMLog(BOLD RED "Application of cape failed" RESET);
        }
    } else {
        MMLog("No cape configured for user");
    }

    setCursorScale(defaultCursorScale());

    CFRelease(currentConsoleUser);
}

void reconfigurationCallback(CGDirectDisplayID display,
    	CGDisplayChangeSummaryFlags flags,
    	void *userInfo) {
    MMLog("Reconfigure user space");
    NSString *capePath = appliedCapePathForUser(NSUserName());
    if (capePath) {
        applyCapeAtPath(capePath);
    }
    float scale;
    CGSGetCursorScale(CGSMainConnectionID(), &scale);
    CGSSetCursorScale(CGSMainConnectionID(), scale + .3);
    CGSSetCursorScale(CGSMainConnectionID(), scale);
}


void listener(void) {
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    assert(store != NULL);
    
    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    assert(key != NULL);
    
    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    assert(keys != NULL);
    
    Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
    assert(success);
    
    NSApplicationLoad();
    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);
    
    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    assert(rls != NULL);
    MMLog(BOLD CYAN "Listening for User changes" RESET);
    
    // Apply the cape for the user on load (if configured)
    NSString *initialCapePath = appliedCapePathForUser(NSUserName());
    if (initialCapePath) {
        applyCapeAtPath(initialCapePath);
    } else {
        MMLog("No cape configured - running in standby mode");
    }
    setCursorScale(defaultCursorScale());
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
    CFRunLoopRun();

    // Cleanup
    CFRunLoopSourceInvalidate(rls);
    CFRelease(rls);
    CFRelease(keys);
    CFRelease(key);
    CFRelease(store);
}