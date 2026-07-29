#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

static CFMachPortRef gEventTap = NULL;
static bool gShiftDown = false;
static bool gPivotLocked = false;

static NSString *resetSocketPath(void) {
    return [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"com.sean.CursorOrbit.reset.sock"];
}

static void helperLog(NSString *message) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"CursorOrbitHelper.log"];
    NSFileManager *files = [NSFileManager defaultManager];

    if (![files fileExistsAtPath:path]) {
        [data writeToFile:path atomically:YES];
        return;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

static bool fusionIsFrontmost(void) {
    NSRunningApplication *frontmost =
        [[NSWorkspace sharedWorkspace] frontmostApplication];
    NSString *bundleIdentifier = [frontmost bundleIdentifier];
    return bundleIdentifier != nil &&
           [bundleIdentifier isEqualToString:@"com.autodesk.fusion360"];
}

static void sendResetRequest(void) {
    int socketFd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (socketFd < 0) {
        helperLog(@"Could not create reset socket");
        return;
    }

    struct sockaddr_un address = {0};
    address.sun_family = AF_UNIX;
    const char *socketPath = [resetSocketPath() fileSystemRepresentation];
    if (strlcpy(address.sun_path, socketPath, sizeof(address.sun_path)) >=
        sizeof(address.sun_path)) {
        helperLog(@"Reset socket path is too long");
        close(socketFd);
        return;
    }

    ssize_t sent = sendto(
        socketFd,
        "reset",
        5,
        0,
        (const struct sockaddr *)&address,
        SUN_LEN(&address)
    );
    close(socketFd);

    if (sent == 5) {
        helperLog(@"Reset requested");
    } else {
        helperLog(@"Fusion reset listener unavailable");
    }
}

static bool postNativePivotClick(void) {
    CGEventRef probe = CGEventCreate(NULL);
    if (probe == NULL) {
        return false;
    }
    CGPoint cursor = CGEventGetLocation(probe);
    CFRelease(probe);

    CGEventRef down = CGEventCreateMouseEvent(
        NULL,
        kCGEventOtherMouseDown,
        cursor,
        kCGMouseButtonCenter
    );
    CGEventRef up = CGEventCreateMouseEvent(
        NULL,
        kCGEventOtherMouseUp,
        cursor,
        kCGMouseButtonCenter
    );
    if (down == NULL || up == NULL) {
        if (down != NULL) {
            CFRelease(down);
        }
        if (up != NULL) {
            CFRelease(up);
        }
        return false;
    }

    CGEventSetFlags(down, kCGEventFlagMaskShift);
    CGEventSetFlags(up, kCGEventFlagMaskShift);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    return true;
}

static CGEventRef eventTapCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *userInfo
) {
    (void)proxy;
    (void)userInfo;

    if (type == kCGEventTapDisabledByTimeout ||
        type == kCGEventTapDisabledByUserInput) {
        if (gEventTap != NULL) {
            CGEventTapEnable(gEventTap, true);
        }
        return event;
    }

    if (type != kCGEventFlagsChanged) {
        return event;
    }

    bool shiftDown = (CGEventGetFlags(event) & kCGEventFlagMaskShift) != 0;

    if (!gShiftDown && shiftDown && fusionIsFrontmost()) {
        if (postNativePivotClick()) {
            gPivotLocked = true;
            helperLog(@"Native HID pivot click posted");
        } else {
            helperLog(@"Failed to create native pivot click");
        }
    } else if (gShiftDown && !shiftDown && gPivotLocked) {
        sendResetRequest();
        gPivotLocked = false;
    }

    gShiftDown = shiftDown;
    return event;
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

        NSDictionary *accessibilityOptions = @{
            (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
        };
        AXIsProcessTrustedWithOptions(
            (__bridge CFDictionaryRef)accessibilityOptions
        );

        if (!AXIsProcessTrusted()) {
            helperLog(@"Waiting for Accessibility permission");
        }
        while (!AXIsProcessTrusted()) {
            [[NSRunLoop currentRunLoop]
                runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }

        CGEventMask eventMask = CGEventMaskBit(kCGEventFlagsChanged);
        gEventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionDefault,
            eventMask,
            eventTapCallback,
            NULL
        );
        if (gEventTap == NULL) {
            helperLog(@"Could not create event tap");
            return 2;
        }

        CFRunLoopSourceRef runLoopSource =
            CFMachPortCreateRunLoopSource(NULL, gEventTap, 0);
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            runLoopSource,
            kCFRunLoopCommonModes
        );
        CGEventTapEnable(gEventTap, true);

        gShiftDown = CGEventSourceKeyState(
            kCGEventSourceStateCombinedSessionState,
            (CGKeyCode)56
        ) || CGEventSourceKeyState(
            kCGEventSourceStateCombinedSessionState,
            (CGKeyCode)60
        );

        helperLog(@"Ready");
        CFRunLoopRun();

        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            runLoopSource,
            kCFRunLoopCommonModes
        );
        CFRelease(runLoopSource);
        CFRelease(gEventTap);
        gEventTap = NULL;
    }
    return 0;
}
