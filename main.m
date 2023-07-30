//
//  main.m
//  CocoaFromScratch
//
//  Created by liutao on 2023/7/21.
//

#import <Cocoa/Cocoa.h>

static NSInteger kMiddleMouseButtonNumber = 2;

typedef struct  {
    NSPoint initPoint;
    NSPoint endPoint;
} MouseStroke;

MouseStroke makeMouseStroke(NSPoint start, NSPoint end) {
    MouseStroke ms;
    ms.initPoint = start;
    ms.endPoint = end;
    return ms;
}

float calculateStrokeAngle(MouseStroke stroke) {
    NSPoint pointA = stroke.endPoint;
    NSPoint pointB = stroke.initPoint;
    
    float deltaX = pointB.x - pointA.x;
    float deltaY = pointB.y - pointA.y;
    float radians = atan2(deltaY, deltaX);
    float angle = radians * (180.0 / M_PI);
    return angle;
}

@protocol StrokeMatcher <NSObject>
-(BOOL) isStokeMatchTo:(MouseStroke) stroke;
@end

@interface RightStrokeMatcher : NSObject <StrokeMatcher>
@end
@implementation RightStrokeMatcher

- (BOOL) isStokeMatchTo:(MouseStroke) stroke {
    // 向右滑动距离超过 100
    static int kMinimumDistance = 100;
    int distance = stroke.endPoint.x - stroke.initPoint.x;
    
    if (distance < kMinimumDistance) {
        return FALSE;
    }
    // 方向是向右，根据角度判断
    float angle = calculateStrokeAngle(stroke);
    NSLog(@"angle is %f", angle);
    return abs(180 - angle) <= 20;
}

+ (NSString *)description {
    return @"right";
}

@end


@interface LeftStrokeMatcher : NSObject <StrokeMatcher>
@end
@implementation LeftStrokeMatcher

- (BOOL) isStokeMatchTo:(MouseStroke) stroke {
    // 向左滑动距离超过 100
    static int kMinimumDistance = 100;
    int distance = stroke.initPoint.x - stroke.endPoint.x;
    
    if (distance < kMinimumDistance) {
        return FALSE;
    }
    // 方向是向右，根据角度判断
    float angle = calculateStrokeAngle(stroke);
    NSLog(@"angle is %f", angle);
    return abs(angle) <= 20;
}

+ (NSString *)description {
    return @"left";
}

@end

@interface UpStrokeMatcher : NSObject <StrokeMatcher>
@end
@implementation UpStrokeMatcher

- (BOOL) isStokeMatchTo:(MouseStroke) stroke {
    // 向右滑动距离超过 100
    static int kMinimumDistance = 100;
    int distance = stroke.endPoint.y - stroke.initPoint.y;
    
    if (distance < kMinimumDistance) {
        return FALSE;
    }
    // 方向是向右，根据角度判断
    float angle = calculateStrokeAngle(stroke);
    NSLog(@"angle is %f", angle);
    return abs(abs(angle)-90) <= 20;
}

+ (NSString *)description {
    return @"left";
}

@end

@protocol Action <NSObject>

-(void) doAction;

@end

@interface NextDesktopAction : NSObject<Action>
-(void) doAction;
@end
@implementation NextDesktopAction
-(void) doAction {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAppleScript *switchSpaceScript = [[NSAppleScript alloc] initWithSource:@" launch \"System Events\" \n tell application \"System Events\" \n key code 124 using {control down} \n end tell"];
        NSDictionary *dict = nil;
        NSAppleEventDescriptor *descriptor = [switchSpaceScript executeAndReturnError:&dict];
    });
}
@end

@interface PreviousDesktopAction : NSObject<Action>
-(void) doAction;
@end
@implementation PreviousDesktopAction
-(void) doAction {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAppleScript *switchSpaceScript = [[NSAppleScript alloc] initWithSource:@" launch \"System Events\" \n tell application \"System Events\" \n key code 123 using {control down} \n end tell"];
        NSDictionary *dict = nil;
        NSAppleEventDescriptor *descriptor = [switchSpaceScript executeAndReturnError:&dict];
    });
}
@end

@interface DispatchingCenterAction : NSObject<Action>
-(void) doAction;
@end
@implementation DispatchingCenterAction
-(void) doAction {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAppleScript *switchSpaceScript = [[NSAppleScript alloc] initWithSource:@" launch \"System Events\" \n tell application \"System Events\" \n key code 126 using {control down} \n end tell"];
        NSDictionary *dict = nil;
        NSAppleEventDescriptor *descriptor = [switchSpaceScript executeAndReturnError:&dict];
    });
}
@end

@interface StrokeAction : NSObject
-(StrokeAction*) initWithStroke:(id<StrokeMatcher>)matcher action:(id<Action>)strokeAction;
@property (nonatomic, strong) id<StrokeMatcher> strokeMatcher;
@property (nonatomic, strong) id<Action> strokeAction;
@end

@implementation StrokeAction

- (StrokeAction *)initWithStroke:(id<StrokeMatcher>)matcher action:(id<Action>)strokeAction {
    self = [super init];
    self.strokeMatcher = matcher;
    self.strokeAction = strokeAction;
    return self;
}

@end


@interface DemoAppdelegate : NSObject <NSApplicationDelegate>
-(bool) runOnlyOneInstance;
-(void) doInit;
-(void) initUserPref;
-(void) initStatusBar;
-(void) toggle:(nullable id)sender;
-(void) quitApp:(nullable id)sender;

-(void) initOberverMouseEventWithNSvent;
-(void) handleMouseEvent:(NSEvent*)event;
-(void) setupAction;
-(void) matchThenDoAction:(MouseStroke)stroke;
@property (nonatomic, assign) BOOL isMiddleMouseDown; // 记录中建是否被按下
@property (nonatomic, assign) NSPoint initialMousePosition; // 记录中建按下时的鼠标位置
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, strong) NSMutableArray *strokeActionArray; // 存储 stroke -> action

@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation DemoAppdelegate

-(void) applicationDidFinishLaunching:(NSNotification *)notification {
    // 同时只能运行一个
    if (![self runOnlyOneInstance]) {
        [NSApp terminate:nil];
        return;
    }
    self.enable = TRUE;
    
    // 初始化程序
    [self doInit];
}

-(void) initStatusBar {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *statusImage = [NSImage imageNamed:@"Icon"]; // 替换为你的状态栏图标
    statusImage.template = YES; // 使图标在暗色菜单栏下也显示为白色（仅在 macOS 10.10 及更高版本有效）
    self.statusItem.button.image = statusImage;

    // 创建状态栏菜单
    NSMenu *statusMenu = [[NSMenu alloc] init];
    [statusMenu addItemWithTitle:@"Disable" action:@selector(toggle:) keyEquivalent:@""];
    [statusMenu addItemWithTitle:@"Quit" action:@selector(quitApp:) keyEquivalent:@"q"];
    self.statusItem.menu = statusMenu;
}

-(void) toggle:(nullable id)sender {
    self.enable = !self.enable;
    NSMenuItem * toggleItem = [self.statusItem.menu itemAtIndex:0];
    if (self.enable) {
        [toggleItem setTitle: @"Disable"];
    } else {
        [toggleItem setTitle: @"Enable"];
    }
}

-(void) quitApp:(nullable id)sender {
    [NSApp terminate:nil];
}

-(bool) runOnlyOneInstance {
    NSArray* apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    NSLog(@"%@", [[NSBundle mainBundle] bundleIdentifier]);
    if ([apps count] > 1) {
        return FALSE;
    }
    return TRUE;
}

-(void) doInit {
    [self initStatusBar];
    // 1. 初始化用户配置
    [self initUserPref];
    // 2. 监听鼠标事件
    [self initOberverMouseEventWithNSvent];
    [self setupAction];
}

-(void) initUserPref {
    
}

-(void) initOberverMouseEventWithNSvent {
    // 添加全局鼠标事件监听
    NSEventMask eventMask = NSEventMaskOtherMouseDown | NSEventMaskOtherMouseUp;
    [NSEvent addGlobalMonitorForEventsMatchingMask:eventMask handler:^(NSEvent* event) {
        [self handleMouseEvent:event];
    }];
}

-(void) handleMouseEvent:(NSEvent*)event {
    if (!self.enable) {
        return;
    }
    
    if (event.buttonNumber != kMiddleMouseButtonNumber) {
        return;
    }
    
    NSPoint eventLocation = [NSEvent mouseLocation];
    
    if (event.type == NSEventTypeOtherMouseDown) {
        self.isMiddleMouseDown = TRUE;
        self.initialMousePosition = eventLocation;
    } else if (event.type == NSEventTypeOtherMouseUp) {
        self.isMiddleMouseDown = FALSE;
        MouseStroke s = makeMouseStroke(self.initialMousePosition, eventLocation);
        [self matchThenDoAction:s];
    }
}

-(void) setupAction {
    // 创建一个空的可变数组
    self.strokeActionArray = [NSMutableArray array];
    
    // 右
    RightStrokeMatcher* rm = [[RightStrokeMatcher alloc] init];
    NextDesktopAction* action = [[NextDesktopAction alloc] init];
    StrokeAction* sa1 = [[StrokeAction alloc] initWithStroke:rm action:action];
    [_strokeActionArray addObject: sa1];
    
    // 左
    LeftStrokeMatcher* lsm = [[LeftStrokeMatcher alloc] init];
    PreviousDesktopAction* pda = [[PreviousDesktopAction alloc] init];
    StrokeAction* sa2 = [[StrokeAction alloc] initWithStroke:lsm action:pda];
    [_strokeActionArray addObject: sa2];
    
    // 上
    UpStrokeMatcher* usm = [[UpStrokeMatcher alloc] init];
    DispatchingCenterAction* dca = [[DispatchingCenterAction alloc] init];
    StrokeAction* sa3 = [[StrokeAction alloc] initWithStroke:usm action:dca];
    [_strokeActionArray addObject: sa3];
}

- (void)matchThenDoAction:(MouseStroke)stroke {
    for (StrokeAction* sa in _strokeActionArray) {
        if ([sa.strokeMatcher isStokeMatchTo:stroke]) {
            NSLog(@"matched name: %@", [sa.strokeMatcher description]);
            [sa.strokeAction doAction];
        }
    }
}
@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        DemoAppdelegate* appDelegate = nil;
        appDelegate = [[DemoAppdelegate alloc] init];
        NSApp = [NSApplication sharedApplication];
        [NSApp setDelegate:appDelegate];
        [NSApp run];
    }
    
    return EXIT_SUCCESS;
}
