//
//  InputPopupControllerViewController.h
//  CocoaSplit
//
//  Created by Zakk on 7/26/14.
//  Copyright (c) 2014 Zakk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class InputSource;

@interface InputPopupControllerViewController : NSViewController <NSPopoverDelegate, NSWindowDelegate>

@property (strong) IBOutlet NSWindow *popupWIndow;

@property (strong) NSPopover *myPopover;
@property (strong) NSWindow *transitionFilterWindow;
@property (strong) NSWindow *userFilterWindow;
@property (strong) NSWindow *screenCropWindow;
@property (weak) InputSource *inputSource;


- (IBAction)deleteMultiSource:(id)sender;
-(void)openTransitionFilterPanel:(CIFilter *)forFilter;
-(void)openUserFilterPanel:(CIFilter *)forFilter;


@property (weak) IBOutlet NSArrayController *multiSourceController;
@property (weak) IBOutlet NSArrayController *currentEffectsController;
@property (weak) IBOutlet NSWindow *cropSelectionWindow;
@property (weak) IBOutlet NSView *sourceConfigView;

@end