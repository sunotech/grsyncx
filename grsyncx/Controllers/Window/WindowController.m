//
//  WindowController.m
//  grsyncx
//
//  Created by Michal Zelinka on 13/01/2020.
//  Copyright © 2020 Michal Zelinka. All rights reserved.
//

#import "WindowController.h"
#import "WindowActionsResponder.h"


@interface WindowController () <NSToolbarDelegate>

@property (nonatomic, weak) id<WindowActionsResponder> actionsResponder;

@end


@implementation WindowController

- (void)windowDidLoad
{
	[super windowDidLoad];

	self.window.toolbar = nil;

	// Enable window resizing and configure size boundaries
	self.window.styleMask |= NSWindowStyleMaskResizable;
	// Keep all profile options and the action bar visible without an internal scroll area.
	self.window.minSize = NSMakeSize(1050, 760);
	[self.window setContentSize:NSMakeSize(1120, 800)];

	NSViewController *vc = self.contentViewController;

	if ([vc conformsToProtocol:@protocol(WindowActionsResponder)])
		_actionsResponder = (id)vc;
	else @throw @"Invalid Window actions responder";
}

- (IBAction)simulateButton:(__unused id)sender
{
	const id<WindowActionsResponder> resp = _actionsResponder;
	[resp didReceiveSimulateAction];
}

- (IBAction)executeButton:(__unused id)sender
{
	const id<WindowActionsResponder> resp = _actionsResponder;
	[resp didReceiveExecuteAction];
}

@end
