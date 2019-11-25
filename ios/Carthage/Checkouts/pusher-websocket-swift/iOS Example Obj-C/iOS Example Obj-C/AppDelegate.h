//
//  AppDelegate.h
//  iOS Example Obj-C
//
//  Created by Hamilton Chapman on 09/09/2016.
//  Copyright © 2016 Pusher. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PusherSwift/PusherSwift-Swift.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong, readwrite) Pusher *pusher;


@end
