//
//  MainViewController.m
//  grsyncx
//

#import "MainViewController.h"
#import "WindowActionsResponder.h"

@interface MainViewController () <WindowActionsResponder>

@end

@implementation MainViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

	Class factoryClass = NSClassFromString(@"SwiftUIFactory");
	if (factoryClass) {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		SEL createSel = NSSelectorFromString(@"createMainView");
		if ([factoryClass respondsToSelector:createSel]) {
			NSView *swiftView = [factoryClass performSelector:createSel];
			if (swiftView) {
				// Remove old storyboard-defined subviews
				[self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

				swiftView.translatesAutoresizingMaskIntoConstraints = NO;
				[self.view addSubview:swiftView];

				[NSLayoutConstraint activateConstraints:@[
					[swiftView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
					[swiftView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
					[swiftView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
					[swiftView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
				]];
			}
		}
		#pragma clang diagnostic pop
	} else {
		NSLog(@"[Grsyncx] Error: SwiftUIFactory class not found in Objective-C runtime!");
	}
}

#pragma mark - Window actions responder

- (void)didReceiveSimulateAction
{
	// Managed within SwiftUI interface
}

- (void)didReceiveExecuteAction
{
	// Managed within SwiftUI interface
}

@end
