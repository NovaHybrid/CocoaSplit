//
//  PreviewView.m
//  CocoaSplit
//
//  Created by Zakk on 11/22/12.

#import <QuartzCore/QuartzCore.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/glu.h>

#import "PreviewView.h"
#import "SourceLayout.h"
#import "CreateLayoutViewController.h"
#import "CSLayoutRecorder.h"
#import "CSPreviewCALayer.h"

//wtf apple

@interface NSCursor (CSApplePrivate)
+ (instancetype)_bottomLeftResizeCursor;
+ (instancetype)_topLeftResizeCursor;
+ (instancetype)_bottomRightResizeCursor;
+ (instancetype)_topRightResizeCursor;
+ (instancetype)_windowResizeNorthEastSouthWestCursor;
+ (instancetype)_windowResizeNorthWestSouthEastCursor;
@end







@implementation PreviewView

@synthesize sourceLayout = _sourceLayout;
@synthesize layoutRenderer = _layoutRenderer;
@synthesize mousedSource = _mousedSource;
@synthesize selectedSource = _selectedSource;


-(void)setMidiActive:(bool)midiActive
{
    _glLayer.midiActive = midiActive;
}


-(bool)midiActive
{
    return _glLayer.midiActive;
}



-(void)cursorUpdate:(NSEvent *)event
{
    return;
}

-(void)setSelectedSource:(InputSource *)selectedSource
{
    _selectedSource = selectedSource;
}

-(InputSource *)selectedSource
{
    return _selectedSource;
}


-(void)setMousedSource:(InputSource *)mousedSource
{
    _mousedSource = mousedSource;
    if (!_mousedSource)
    {
        if (_snapOverlay)
        {
            _snapOverlay.drawLines = @[];
        }
    }
}

-(InputSource *)mousedSource
{
    return _mousedSource;
}


-(void)setLayoutRenderer:(LayoutRenderer *)layoutRenderer
{
    if (_glLayer)
    {
        _glLayer.renderer = layoutRenderer;
        _glLayer.doRender = self.isEditWindow;
    }
    
   _layoutRenderer = layoutRenderer;

}



-(LayoutRenderer *)layoutRenderer
{
    return _layoutRenderer;
}


-(SourceLayout *)sourceLayout
{
    return _sourceLayout;
}

-(void) setSourceLayout:(SourceLayout *)sourceLayout
{
    
    if (_sourceLayout && !self.isEditWindow)
    {
        [NSApp unregisterMIDIResponder:_sourceLayout];
        
    }
    _sourceLayout = sourceLayout;
    [self.undoManager removeAllActions];
    sourceLayout.undoManager = self.undoManager;
    
    if (!self.isEditWindow)
    {
        [NSApp registerMIDIResponder:sourceLayout];
    }
    
    
    if (_sourceLayout.recorder)
    {
        self.layoutRenderer = _sourceLayout.recorder.renderer;
        [self disablePrimaryRender];
        
    } else {
        if (self.layoutRenderer)
        {
            self.layoutRenderer.layout = _sourceLayout;
        }
    }
    
}



-(SourceLayout *)sourceLayoutPreview
{
    return self.sourceLayout;
}





-(BOOL)acceptsFirstResponder
{
    return YES;
}

-(void)cancelOperation:(id)sender
{
    if (self.isInFullScreenMode)
    {
        [self toggleFullscreen:self];
    }
}

-(void)keyDown:(NSEvent *)theEvent
{
    if ([theEvent.charactersIgnoringModifiers isEqualToString:@"f"] && (theEvent.modifierFlags & NSEventModifierFlagCommand))
    {
        [self toggleFullscreen:self];
    }

}



-(NSRect)windowRectforWorldRect:(NSRect)worldRect
{
    
    if (_glLayer)
    {
        return [_glLayer windowRectforWorldRect:worldRect];
    }
    
    return NSZeroRect;
}


-(NSPoint)realPointforWindowPoint:(NSPoint)winPoint
{
    
    
    if (_glLayer)
    {
        return [_glLayer realPointforWindowPoint:winPoint];
    }
    
    return NSZeroPoint;
}


-(void)midiMapSource:(id)sender
{
    if (self.selectedSource)
    {

        [self.controller openMidiLearnerForResponders:@[self.selectedSource]];
    }
}


- (IBAction)addInputToLibrary:(id)sender
{
    
    InputSource *toAdd = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toAdd = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toAdd = (InputSource *)sender;
        }
    }
    
    if (!toAdd)
    {
        toAdd = self.selectedSource;
    }
    
    if (toAdd)
    {
        [self.controller addInputToLibrary:toAdd];
    }
}

-(void) buildSettingsMenu
{
    
    NSInteger idx = 0;
    
    NSMenuItem *tmp;
    self.sourceSettingsMenu = [[NSMenu alloc] init];
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Move Up" action:@selector(moveInputUp:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Move Down" action:@selector(moveInputDown:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Settings" action:@selector(showInputSettings:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Clone" action:@selector(cloneInputSource:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Clone Without Cache" action:@selector(cloneInputSourceNoCache:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    tmp.alternate = YES;
    tmp.keyEquivalentModifierMask = NSEventModifierFlagOption;
    
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Make Source Private" action:@selector(privatizeSource:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    tmp.alternate = YES;
    tmp.keyEquivalentModifierMask = NSEventModifierFlagControl;
    
    NSString *freezeString = @"Freeze";
    if (self.selectedSource.isFrozen)
    {
        freezeString = @"Unfreeze";
    }
    
    
    tmp = [self.sourceSettingsMenu insertItemWithTitle:freezeString action:@selector(freezeInputSource:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;

    
    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Add to Library" action:@selector(addInputToLibrary:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;

    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Midi Mapping" action:@selector(midiMapSource:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;
    
    if (self.selectedSource.videoInput && [self.selectedSource.videoInput canProvideTiming])
    {
        
        if (self.sourceLayout.layoutTimingSource == self.selectedSource)
        {
            tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Stop using as master timing" action:@selector(removeSourceTimer:) keyEquivalent:@"" atIndex:idx++];
            tmp.target = self;

        } else {
            tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Use as master timing" action:@selector(setSourceAsTimer:) keyEquivalent:@"" atIndex:idx++];
            tmp.target = self;
        }
    }
    

    tmp = [self.sourceSettingsMenu insertItemWithTitle:@"Reset to source AR" action:@selector(resetSourceAR:) keyEquivalent:@"" atIndex:idx++];
    tmp.target = self;

}



-(void)doToggleTransitions:(id)sender
{
    if (self.controller)
    {
        self.controller.useTransitions = !self.controller.useTransitions;
    }
}


-(void)configureLayoutFilters:(id)sender
{
    if (self.sourceLayout)
    {
        self.settingsConfigWindow = [[CSSourceLayoutSettingsWindowController alloc] init];
        self.settingsConfigWindow.layout = self.sourceLayout;
        [self.settingsConfigWindow showWindow:nil];
    }
}


-(void)doLayoutMidi:(id)sender
{
    if (self.sourceLayout)
    {
        //We need to do mappings for both staging and live, so create a dummy copy that isn't in the same state as ours
        SourceLayout *layoutCopy = [self.sourceLayout copy];
        
        //Default on copy is isActive = NO, so only tweak it if we aren't the active version
        if (!self.sourceLayout.isActive)
        {
            layoutCopy.isActive = YES;
        }
        [self.controller openMidiLearnerForResponders:@[self.sourceLayout, layoutCopy]];
        layoutCopy = nil;
    }
}


-(void)menu:(NSMenu *)menu willHighlightItem:(nullable NSMenuItem *)item
{
    if (item.representedObject)
    {
        NSObject<CSInputSourceProtocol> *hInput = (NSObject<CSInputSourceProtocol> *)item.representedObject;
        if (_overlayView && hInput.isVideo)
        {
            _overlayView.parentSource = (InputSource *)hInput;
        }
    }
}



-(void)resolutionMenuAction:(NSMenuItem *)sender
{
    NSInteger tag = sender.tag;
    
    if (!self.sourceLayout)
    {
        return;
    }
    
    if (tag < 2)
    {
        [self.sourceLayout updateCanvasWidth:1280 height:720];
    } else if (tag < 4) {
        [self.sourceLayout updateCanvasWidth:1920 height:1080];
    }
    
    if ((tag % 2) == 0)
    {
        self.sourceLayout.frameRate = 60.0f;
    } else {
        self.sourceLayout.frameRate = 30.0f;
    }
}



-(NSMenu *) buildSourceMenu
{
    
    
    NSArray *sourceList = [self.sourceLayout sourceListOrdered];
    
    NSMenu *sourceListMenu = [[NSMenu alloc] init];
    sourceListMenu.delegate = self;
    
    
    NSString *resTitle = [NSString stringWithFormat:@"%dx%d@%.2f", self.sourceLayout.canvas_width, self.sourceLayout.canvas_height, self.sourceLayout.frameRate];
    
    NSMenuItem *resItem = [[NSMenuItem alloc] initWithTitle:resTitle action:nil keyEquivalent:@""];
    
    NSMenu *resSubmenu = [[NSMenu alloc] init];
    
    [LAYOUT_RESOLUTIONS enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *resOpt = obj;
        SEL menuAction = @selector(resolutionMenuAction:);
        
        if ([resOpt isEqualToString:@"Custom"])
        {
            menuAction = @selector(showLayoutSettings:);
        }
        
        
        NSMenuItem *item = [resSubmenu addItemWithTitle:resOpt action:menuAction keyEquivalent:@""];
        item.target = self;
        item.enabled = YES;
        item.tag = idx;
        
    }];

    [resItem setSubmenu:resSubmenu];
    
    
    
    [sourceListMenu insertItem:resItem atIndex:[sourceListMenu.itemArray count]];
    
    if (self.showTransitionToggle)
    {
        bool transitionState = self.controller.useTransitions;
        NSString *transitionTitle = @"Enable Transitions";
        if (transitionState)
        {
            transitionTitle = @"Disable Transitions";
        }
        
        NSMenuItem *transitionItem = [[NSMenuItem alloc] initWithTitle:transitionTitle action:@selector(doToggleTransitions:) keyEquivalent:@""];
        [transitionItem setTarget:self];
        [transitionItem setEnabled:YES];
        [sourceListMenu insertItem:transitionItem atIndex:[sourceListMenu.itemArray count]];

    }
    if (self.viewOnly)
    {
        return sourceListMenu;
    }
    
    NSMenuItem *midiItem = [[NSMenuItem alloc] initWithTitle:@"Midi Mapping" action:@selector(doLayoutMidi:) keyEquivalent:@""];
    [midiItem setTarget:self];
    [midiItem setEnabled:YES];
    
    [sourceListMenu insertItem:midiItem atIndex:[sourceListMenu.itemArray count]];

    NSMenuItem *filterItem = [[NSMenuItem alloc] initWithTitle:@"Extra Settings" action:@selector(configureLayoutFilters:) keyEquivalent:@""];
    [filterItem setTarget:self];
    [filterItem setEnabled:YES];
    [sourceListMenu insertItem:filterItem atIndex:[sourceListMenu.itemArray count]];

    [sourceListMenu insertItem:[NSMenuItem separatorItem] atIndex:[sourceListMenu.itemArray count]];
    
    for (InputSource *src in sourceList)
    {
        NSString *srcName = src.name;
        if (!srcName)
        {
            srcName = [NSString stringWithFormat:@"%@-noname", src.selectedVideoType];
            
        }
    
        NSMenuItem *srcItem = [[NSMenuItem alloc] initWithTitle:srcName action:nil keyEquivalent:@""];
        [srcItem setEnabled:YES];
        NSMenu *submenu = [[NSMenu alloc] init];
        NSMenuItem *setItem = [[NSMenuItem alloc] initWithTitle:@"Settings" action:@selector(showInputSettings:) keyEquivalent:@""];
        [setItem setEnabled:YES];
        [setItem setRepresentedObject:src];
        [setItem setTarget:self];
        [submenu addItem:setItem];
        NSMenuItem *delItem = [[NSMenuItem alloc] initWithTitle:@"Delete" action:@selector(deleteInput:) keyEquivalent:@""];
        [delItem setEnabled:YES];
        [delItem setRepresentedObject:src];
        [delItem setTarget:self];
        [submenu addItem:delItem];
        
        NSMenuItem *libraryItem = [[NSMenuItem alloc] initWithTitle:@"Add to Library" action:@selector(addInputToLibrary:) keyEquivalent:@""];
        [libraryItem setEnabled:YES];
        [libraryItem setRepresentedObject:src];
        [libraryItem setTarget:self];
        [submenu addItem:libraryItem];

        NSMenuItem *cloneItem = [[NSMenuItem alloc] initWithTitle:@"Clone" action:@selector(cloneInputSource:) keyEquivalent:@""];
        [cloneItem setEnabled:YES];
        [cloneItem setRepresentedObject:src];
        [cloneItem setTarget:self];
        [submenu addItem:cloneItem];
        
        [srcItem setSubmenu:submenu];
        [srcItem setRepresentedObject:src];

        [sourceListMenu insertItem:srcItem atIndex:[sourceListMenu.itemArray count]];
        
    }

    return sourceListMenu;
}

-(void)trackMousedSource
{
    
    if (self.selectedSource)
    {
        self.mousedSource = self.selectedSource;
        return;
    }
    
    
    NSPoint mouseLoc = [NSEvent mouseLocation];
    
    NSRect rect = NSRectFromCGRect((CGRect){mouseLoc, CGSizeZero});
    
    mouseLoc = [self.window convertRectFromScreen:rect].origin;
    mouseLoc = [self convertPoint:mouseLoc fromView:nil];
    
    if (![self mouse:mouseLoc inRect:self.bounds])
    {
        return;
    }
    
    
    NSPoint worldPoint = [self realPointforWindowPoint:mouseLoc];
    
    InputSource *newSrc = [self.sourceLayout findSource:worldPoint withExtra:2 deepParent:YES];
    

    if (!newSrc)
    {
        [NSCursor pop];
    }
    
    NSArray *resizeRects = [self resizeRectsForSource:newSrc withExtra:2];

    NSCursor *newCursor = [NSCursor openHandCursor];
    
    bool hitResize = NO;
    
    //bottom left, top left, top right, bottom right
    for(int i=0; i < resizeRects.count; i++)
    {
        NSValue *rVal = [resizeRects objectAtIndex:i];
        
        NSRect reRect = [rVal rectValue];
        if (NSPointInRect(mouseLoc, reRect))
        {
            if (i == 0 || i == 2)
            {
                newCursor = [NSCursor _windowResizeNorthEastSouthWestCursor];
            } else {
                newCursor = [NSCursor _windowResizeNorthWestSouthEastCursor];
            }
            hitResize = YES;
            break;
        }
        
        
    }
    
    if ((newSrc != self.mousedSource) || (hitResize != _in_resize_rect))
    {
        [NSCursor pop];
        [newCursor push];
    }
 
    if (self.mousedSource != newSrc)
    {
        self.mousedSource = newSrc;
    }
    _in_resize_rect = hitResize;
}



-(NSMenu *)menuForEvent:(NSEvent *)event
{
    NSPoint tmp;
    
    tmp = [self convertPoint:event.locationInWindow fromView:nil];

    
    if (self.viewOnly)
    {
        return [self buildSourceMenu];
    }
    
    bool doDeep = YES;
    
    if (event.modifierFlags & NSEventModifierFlagControl)
    {
        doDeep = NO;
    }
    NSPoint worldPoint = [self realPointforWindowPoint:tmp];
    self.selectedSource = [self.sourceLayout findSource:worldPoint deepParent:doDeep];
    
    if (self.selectedSource)
    {
        [self buildSettingsMenu];
        return self.sourceSettingsMenu;
    } else {
        
        NSMenu *srcListMenu = [self buildSourceMenu];
        return srcListMenu;
    }
    
    return nil;
}


//bottom left, top left, top right, bottom right

-(NSArray *)resizeRectsForSource:(InputSource *)inputSource withExtra:(float)withExtra
{
    
    NSRect layoutRect = inputSource.globalLayoutPosition;
    
    
    NSRect extraRect = NSInsetRect(layoutRect, -withExtra, -withExtra);
    
    NSRect viewRect = [self windowRectforWorldRect:extraRect];
    
    
    NSRect bottomLeftRect = NSMakeRect(viewRect.origin.x, viewRect.origin.y, 10.0f, 10.0f);
    NSRect bottomRightRect = NSMakeRect(viewRect.origin.x+viewRect.size.width-10.0f, viewRect.origin.y, 10.0f, 10.0f);
    
    NSRect topLeftRect = NSMakeRect(viewRect.origin.x, viewRect.origin.y+viewRect.size.height-10.0f, 10.0f, 10.0f);
    
    NSRect topRightRect = NSMakeRect(viewRect.origin.x+viewRect.size.width-10.0f, viewRect.origin.y+viewRect.size.height-10.0f, 10.0f, 10.0f);
    
    
    return @[[NSValue valueWithRect:bottomLeftRect], [NSValue valueWithRect:topLeftRect], [NSValue valueWithRect:topRightRect],[NSValue valueWithRect:bottomRightRect]];
    
}


- (void)mouseDown:(NSEvent *)theEvent
{
    
    if (self.viewOnly)
    {
        return;
    }
    
    
    NSPoint tmp;
    
    tmp = [self convertPoint:theEvent.locationInWindow fromView:nil];
    
    NSPoint worldPoint = [self realPointforWindowPoint:tmp];
    
    InputSource *oldSource = self.selectedSource;
    
    InputSource *topSource = [self.sourceLayout findSource:worldPoint deepParent:NO];

    InputSource *deepSource = [self.sourceLayout findSource:worldPoint deepParent:YES];
;
    
    if (theEvent.modifierFlags & NSEventModifierFlagControl)
    {
        self.selectedSource = topSource;
    } else {
        self.selectedSource = deepSource;
    }
    
    if (!self.selectedSource)
    {
        return;
    }
    
    
    self.selectedSource.is_selected = YES;
    if (oldSource)
    {
        oldSource.is_selected = NO;
    }
    
    
    NSArray *resizeRects = [self resizeRectsForSource:self.selectedSource withExtra:2];
    
    //bottom left, top left, top right, bottom right

    
    NSRect bottomLeftRect = [[resizeRects objectAtIndex:0] rectValue];
    NSRect topLeftRect = [[resizeRects objectAtIndex:1] rectValue];
    NSRect topRightRect = [[resizeRects objectAtIndex:2] rectValue];
    NSRect bottomRightRect = [[resizeRects objectAtIndex:3] rectValue];
    
    self.resizeType = kResizeNone;
    
    if (NSPointInRect(tmp, topLeftRect))
    {
        self.resizeType = kResizeLeft | kResizeTop;
    } else if (NSPointInRect(tmp, bottomLeftRect)) {
        self.resizeType = kResizeLeft | kResizeBottom;

    } else if (NSPointInRect(tmp, topRightRect)) {
        self.resizeType = kResizeRight | kResizeTop;
    } else if (NSPointInRect(tmp, bottomRightRect)) {
        self.resizeType = kResizeRight | kResizeBottom;
    }
    
    
    self.isResizing = self.resizeType != kResizeNone;
    
    if (self.isResizing)
    {
        self.selectedSource = deepSource;
    }
    
    
    self.selectedOriginDistance = worldPoint;
    
    if (self.isResizing)
    {
        if (theEvent.modifierFlags & NSEventModifierFlagOption)
        {
            self.resizeType |= kResizeCenter;
        }
        
        if (theEvent.modifierFlags & NSEventModifierFlagControl)
        {
            self.resizeType |= kResizeFree;
        }
        
        if (theEvent.modifierFlags & NSEventModifierFlagShift)
        {
            self.resizeType |= kResizeCrop;
        }


    }
    self.selectedSource.resizeType = self.resizeType;

    
}



- (void)mouseDragged:(NSEvent *)theEvent
{
    
    NSPoint tmp;
    
    
    NSPoint worldPoint;
    if (self.selectedSource)
    {
        
        if (!_inDrag)
        {
            NSRect curFrame = self.selectedSource.layoutPosition;
            
            [[self.sourceLayout.undoManager prepareWithInvocationTarget:self.sourceLayout] modifyUUID:self.selectedSource.uuid withBlock:^(NSObject <CSInputSourceProtocol> *input) {
                if (input)
                {
                    InputSource *vinput = (InputSource *)input;
                    [vinput updateSize:curFrame.size.width height:curFrame.size.height];
                    [vinput positionOrigin:curFrame.origin.x y:curFrame.origin.y];
                }

                
            }];
        }
        
        _inDrag = YES;
        tmp = [self convertPoint:theEvent.locationInWindow fromView:nil];
        
        
        worldPoint = [self realPointforWindowPoint:tmp];
        
        
        NSRect worldRect = NSIntegralRect(NSMakeRect(worldPoint.x, worldPoint.y , self.selectedSource.globalLayoutPosition.size.width, self.selectedSource.globalLayoutPosition.size.height));
        
        worldPoint = worldRect.origin;
        
        
        
        CGFloat dx, dy;
        dx = (worldPoint.x - self.selectedOriginDistance.x);
        dy = (worldPoint.y - self.selectedOriginDistance.y);
        
        
        
        [self adjustDeltas:&dx dy:&dy];

        
        self.selectedOriginDistance = worldPoint;
        

        if (self.isResizing)
        {
            
            if (theEvent.modifierFlags & NSEventModifierFlagOption)
                {
                    self.resizeType |= kResizeCenter;
                } else {
                    self.resizeType &= ~kResizeCenter;
                }
                
                CGFloat new_width, new_height;
                
            NSRect sPosition = self.selectedSource.globalLayoutPosition;
                
                new_width = sPosition.size.width;
                new_height = sPosition.size.height;
                
                if (self.resizeType & kResizeRight && dx)
                {
                    new_width = worldPoint.x - sPosition.origin.x;
                    
                    
                }
                
                if (self.resizeType & kResizeLeft && dx)
                {
                    new_width = (sPosition.origin.x+sPosition.size.width) - worldPoint.x;
                }
                
                
                if (self.resizeType & kResizeTop && dy)
                {
                    
                    new_height = worldPoint.y - sPosition.origin.y;
                }
                
                if (self.resizeType & kResizeBottom && dy)
                {
                    
                    new_height = NSMaxY(sPosition) - worldPoint.y;
                }
            
            
            
            
            
                [self.selectedSource updateSize:new_width height:new_height];

            
        } else {
            
            [self.selectedSource updateOrigin:dx y:dy];
            if (_overlayView)
            {

                NSRect newRect = [self windowRectforWorldRect:self.selectedSource.globalLayoutPosition];
                _overlayView.frame = newRect;
            }
        }
    }
    
    if (_overlayView)
    {
        [_overlayView updatePosition];
    }
}


-(void)adjustDeltas:(CGFloat *)dx dy:(CGFloat *)dy
{
    
    InputSource *superInput = self.selectedSource.parentInput;
    
    NSPoint c_lb_snap;
    NSPoint c_rt_snap;
    NSPoint c_center_snap;
    
    NSPoint *c_snaps;
    int c_snap_size = 0;
    
    
    if (!self.selectedSource)
    {
        return;
    }

    if (superInput)
    {
        NSRect super_rect = superInput.globalLayoutPosition;
        
        c_lb_snap = super_rect.origin;
        c_rt_snap = NSMakePoint(NSMaxX(super_rect), NSMaxY(super_rect));
        c_center_snap = NSMakePoint(NSMidX(super_rect), NSMidY(super_rect));
        c_snaps = malloc(sizeof(NSPoint) * 3);
        c_snaps[0] = c_lb_snap;
        c_snaps[1] = c_rt_snap;
        c_snaps[2] = c_center_snap;
        c_snap_size = 3;
    } else {
    //define snap points. basically edges and the center of the canvas
        c_lb_snap = NSMakePoint(0, 0);
        c_rt_snap = NSMakePoint(self.sourceLayout.canvas_width, self.sourceLayout.canvas_height);
        c_center_snap = NSMakePoint(self.sourceLayout.canvas_width/2, self.sourceLayout.canvas_height/2);
        c_snap_size = 3;

        NSArray *srcs = self.sourceLayout.topLevelSourceList;
        
        
        c_snap_size += srcs.count*3;
        
        c_snaps = malloc(sizeof(NSPoint) * c_snap_size);
        c_snaps[0] = c_lb_snap;
        c_snaps[1] = c_rt_snap;
        c_snaps[2] = c_center_snap;
        
        int snap_idx = 3;
        for (NSObject<CSInputSourceProtocol> *psrc in srcs)
        {
            if (psrc == self.selectedSource || !psrc.isVideo)
            {
                continue;
            }
            
            InputSource *src = (InputSource *)psrc;
            
            NSRect srect = src.globalLayoutPosition;
            c_snaps[snap_idx++] = srect.origin;
            c_snaps[snap_idx++] = NSMakePoint(NSMaxX(srect), NSMaxY(srect));
            c_snaps[snap_idx++] = NSMakePoint(NSMidX(srect), NSMidY(srect));
            
        }
    }
    
    

    
    //selected source snap points. edges, and center
    
    
    NSRect src_rect = self.selectedSource.globalLayoutPosition;

    NSPoint s_lb_snap = src_rect.origin;
    NSPoint s_rt_snap = NSMakePoint(src_rect.origin.x+src_rect.size.width, src_rect.origin.y+src_rect.size.height);
    NSPoint s_center_snap = NSMakePoint(src_rect.origin.x+roundf(src_rect.size.width/2), src_rect.origin.y+roundf(src_rect.size.height/2));
    
    
    NSPoint dist;
    
    NSPoint s_snaps[3] = {s_lb_snap, s_rt_snap, s_center_snap};
    
    bool did_snap_x = NO;
    bool did_snap_y = NO;
    
    //Check if we're already snapped. If we are, check if it's time to break the magnetism.
    if (_snap_x != -1)
    {
        _snap_x_accum += *dx;
        if (fabs(_snap_x_accum) > SNAP_THRESHOLD*2)
        {
            _snap_x = -1;
            *dx = _snap_x_accum;
            _snap_x_accum = 0;
        } else {
            *dx = 0;
        }
        did_snap_x = YES;
    }
    
    if (_snap_y != -1)
    {
        _snap_y_accum += *dy;
        if (fabs(_snap_y_accum) > SNAP_THRESHOLD*2)
        {
            _snap_y = -1;
            *dy = _snap_y_accum;
            _snap_y_accum = 0;
        } else {
            *dy = 0;
        }
        did_snap_y = YES;
    }

    for(int i=0; i < sizeof(s_snaps)/sizeof(NSPoint); i++)
    {
        NSPoint s_snap = s_snaps[i];
        for(int j=0; j < c_snap_size; j++)
        {
            
            NSPoint c_snap = c_snaps[j];
            dist = [self pointDistance:s_snap b:c_snap];
            if (*dx && !did_snap_x && (copysignf(dist.x, *dx) != dist.x) && (fabs(dist.x) < SNAP_THRESHOLD))
            {
                if ((s_snap.x != c_snap.x) && (_snap_x == -1))
                {
                    
                    *dx = -dist.x;
                    _snap_x = c_snap.x;
                    _snap_x_accum = 0;
                    did_snap_x = YES;
                }
            }
            
            if (*dy && !did_snap_y && (copysignf(dist.y, *dy) != dist.y) && (fabs(dist.y) < SNAP_THRESHOLD))
            {

                if ((s_snap.y != c_snap.y) && (_snap_y == -1))
                {
                    *dy = -dist.y;
                    _snap_y = c_snap.y;
                    _snap_y_accum = 0;
                    did_snap_y = YES;

                }
            }
        }
    }
    
    if (_snapOverlay)
    {
        NSMutableArray *snapRects = [NSMutableArray array];
        if (_snap_x > -1)
        {
            NSRect snapXRect = NSMakeRect(_snap_x, 0, 0, self.sourceLayout.canvas_height);
            NSRect translatedRect = [self windowRectforWorldRect:snapXRect];
            [snapRects addObject:[NSValue valueWithRect:translatedRect]];
        }
        
        if (_snap_y > -1)
        {
            NSRect snapYRect = NSMakeRect(0, _snap_y, self.sourceLayout.canvas_width, 0);
            NSRect translatedRect = [self windowRectforWorldRect:snapYRect];
            [snapRects addObject:[NSValue valueWithRect:translatedRect]];
        }
        _snapOverlay.drawLines = snapRects;
    }
    
    
    if (_glLayer)
    {
        //_glLayer.snap_x = _snap_x;
        //_glLayer.snap_y  = _snap_y;
    }
    
    if (c_snaps)
    {
        free(c_snaps);
    }
}


-(NSPoint)pointDistance:(NSPoint )a b:(NSPoint )b
{
    NSPoint ret;
    
    ret.x = a.x - b.x;
    ret.y = a.y - b.y;
    return ret;
}


-(void) mouseUp:(NSEvent *)theEvent
{
    _snap_x = -1;
    _snap_y = -1;
    _snap_x_accum = 0;
    _snap_y_accum  = 0;
    
    self.isResizing = NO;
    self.selectedSource.resizeType = kResizeNone;
    self.selectedSource = nil;
    _inDrag = NO;
}


-(void)mouseExited:(NSEvent *)event
{
    if (self.mousedSource)
    {
        [self stopHighlightingSource:self.mousedSource];
        _overlayView.parentSource = nil;
    }
    
    self.mousedSource = nil;
}


-(void) mouseMoved:(NSEvent *)theEvent
{
    
    if (!self.viewOnly)
    {
        [self trackMousedSource];
        if (!_overlayView)
        {
            _overlayView = [[CSPreviewOverlayView alloc] init];
            _overlayView.previewView = self;
        }
        
        _overlayView.parentSource = self.mousedSource;
        
        if (self.mousedSource)
        {
            [self stopHighlightingSource:self.mousedSource];
 
        }
    }
}




-(void) highlightSource:(InputSource *)source
{
    if (!_highlightedSourceMap)
    {
        _highlightedSourceMap = [[NSMutableDictionary alloc] init];
    }
    
    
    NSString *srcUUID = source.uuid;
    
    NSObject<CSInputSourceProtocol> *realSrc = (InputSource *)[self.sourceLayout inputForUUID:srcUUID];
    if (!_highlightedSourceMap[srcUUID] && realSrc && realSrc.isVideo)
    {
        CSPreviewOverlayView *oview = [[CSPreviewOverlayView alloc] init];
        oview.renderControls = NO;
        oview.previewView = self;
        oview.parentSource = (InputSource *)realSrc;
        _highlightedSourceMap[srcUUID] = oview;
    }
}


-(void)stopHighlightingSource:(InputSource *)source
{
    if (!_highlightedSourceMap)
    {
        _highlightedSourceMap = [[NSMutableDictionary alloc] init];
    }

    NSString *srcUUID = source.uuid;
    
    if (_highlightedSourceMap[srcUUID])
    {
        CSPreviewOverlayView *oview = _highlightedSourceMap[srcUUID];
        [oview removeFromSuperview];
        [_highlightedSourceMap removeObjectForKey:srcUUID];
    }
}

-(void)stopHighlightingAllSources
{
    if (!_highlightedSourceMap)
    {
        _highlightedSourceMap = [[NSMutableDictionary alloc] init];
    }
    for (NSString *key in _highlightedSourceMap)
    {
        CSPreviewOverlayView *oview = _highlightedSourceMap[key];
        if (oview)
        {
            [oview removeFromSuperview];
        }
    }
    [_highlightedSourceMap removeAllObjects];
}


- (IBAction)moveInputUp:(id)sender
{
    InputSource *toMove = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toMove = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toMove = (InputSource *)sender;
        } else if ([sender isKindOfClass:[NSString class]]) {
            toMove = (InputSource *)[self.sourceLayout inputForUUID:sender];
        }
    }
    
    if (!toMove)
    {
        toMove = self.selectedSource;
    }

    if (toMove)
    {

        toMove.depth += 150;
        

        [[self.undoManager prepareWithInvocationTarget:self] moveInputDown:toMove.uuid];
        
    }
}


- (IBAction)moveInputDown:(id)sender
{
    InputSource *toMove = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toMove = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toMove = (InputSource *)sender;
        } else if ([sender isKindOfClass:[NSString class]]) {
            toMove = (InputSource *)[self.sourceLayout inputForUUID:sender];
        }
    }
    
    if (!toMove)
    {
        toMove = self.selectedSource;
    }
    
    if (toMove)
    {
        toMove.depth -= 150;

        
        [[self.undoManager prepareWithInvocationTarget:self] moveInputUp:toMove.uuid];
        
    }
}


-(void)removeSourceTimer:(id)sender
{
    self.sourceLayout.layoutTimingSource = nil;
    
}


-(void)setSourceAsTimer:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    InputSource *useSrc;
    
    if (item.representedObject)
    {
        useSrc = (InputSource *)item.representedObject;
    } else {
        useSrc = self.selectedSource;
    }

    if (useSrc.videoInput && [useSrc.videoInput canProvideTiming])
    {
        self.sourceLayout.layoutTimingSource = useSrc;
    }
}



-(void)resetSourceAR:(id)sender
{
    InputSource *toReset = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toReset = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toReset = (InputSource *)sender;
        }
    }
    
    if (!toReset)
    {
        toReset = self.selectedSource;
    }
    
    if (toReset)
    {
        [((InputSource *)toReset) resetAspectRatio];
    }
}


-(void)detachSource:(id)sender
{
    InputSource *toDetach = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toDetach = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toDetach = (InputSource *)sender;
        }
    }
    
    if (!toDetach)
    {
        toDetach = self.selectedSource;
    }
    
    if (toDetach && toDetach.parentInput)
    {
        [((InputSource *)toDetach.parentInput) detachInput:toDetach];
        [[self.undoManager prepareWithInvocationTarget:self] attachByUUUID:toDetach.uuid toUUID:toDetach.parentInput.uuid];
    }
}


-(void)attachSource:(InputSource *)src toSource:(InputSource *)toSource
{
    if (src && toSource)
    {
        [toSource attachInput:src];

    }
}


-(void)attachByUUUID:(NSString *)srcUUID toUUID:(NSString *)toUUID
{
    SourceLayout *sourceLayout = self.sourceLayout;
    if (!srcUUID || !toUUID) //??
    {
        return;
    }
    
    InputSource *src = (InputSource *)[sourceLayout inputForUUID:srcUUID];
    InputSource *parent = (InputSource *)[sourceLayout inputForUUID:toUUID];
    if (src && parent)
    {
        [parent attachInput:src];
        [[self.undoManager prepareWithInvocationTarget:self] detachSourcesByUUID:@[src.uuid]];
    }
}

-(void)detachSourcesByUUID:(NSArray *)uuids
{
    SourceLayout *sourceLayout = self.sourceLayout;
    
    for (NSString *uuid in uuids)
    {
        InputSource *src = (InputSource *)[sourceLayout inputForUUID:uuid];
        InputSource *parent = src.parentInput;
        if (parent)
        {
            [parent detachInput:src];
            [[self.undoManager prepareWithInvocationTarget:self] attachByUUUID:src.uuid toUUID:parent.uuid];
        }
    }
}


-(void)subLayerInputSource:(id)sender
{
    InputSource *toSub = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toSub = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toSub = (InputSource *)sender;
        }
    }

    if (!toSub)
    {
        toSub = self.selectedSource;
    }
    
    if (toSub)
    {
        InputSource *underSource = [self.sourceLayout sourceUnder:toSub];
        if (underSource)
        {
            [underSource attachInput:toSub];
            [[self.undoManager prepareWithInvocationTarget:self] detachSourcesByUUID:@[toSub.uuid]];
        }
    }
}


-(void)undoCloneInput:(NSString *)inputUUID parentUUID:(NSString *)parentUUID
{
    

    if (inputUUID)
    {
        NSObject<CSInputSourceProtocol> *clonedSource = [self.sourceLayout inputForUUID:inputUUID];
        if (clonedSource)
        {
            [self.sourceLayout deleteSource:clonedSource];

        }
    }
    if (parentUUID)
    {
        NSObject<CSInputSourceProtocol> *parentSource = [self.sourceLayout inputForUUID:parentUUID];
        if (parentSource)
        {
            [[self.undoManager prepareWithInvocationTarget:self] cloneInputSourceByUUID:parentUUID];
        }
    }
}


-(void)freezeInputSource:(id)sender
{
    InputSource *toFreeze = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toFreeze = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toFreeze = (InputSource *)sender;
        }
    }
    
    if (!toFreeze)
    {
        toFreeze = self.selectedSource;
    }
    
    if (toFreeze)
    {
        toFreeze.isFrozen = !toFreeze.isFrozen;
    }
}


-(void)cloneInputSourceByUUID:(NSString *)uuid
{
    InputSource *src = (InputSource *)[self.sourceLayout inputForUUID:uuid];
    if (src)
    {
        [self cloneInputSource:src];
    }
}



-(void) privatizeSource:(id)sender //RIP ronpaulblimp.com

{
    InputSource *toClone = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toClone = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toClone = (InputSource *)sender;
        }
    }
    
    if (!toClone)
    {
        toClone = self.selectedSource;
    }
    
    if (toClone)
    {
        [toClone makeSourcePrivate];
    }
}


-(IBAction)cloneInputSourceNoCache:(id)sender
{
    InputSource *toClone = nil;
    
    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toClone = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toClone = (InputSource *)sender;
        }
    }
    
    if (!toClone)
    {
        toClone = self.selectedSource;
    }
    
    if (toClone)
    {
        InputSource *newSource = [toClone cloneInputNoCache];
        [self.sourceLayout addSource:newSource];
        
        [[self.undoManager prepareWithInvocationTarget:self] undoCloneInput:newSource.uuid parentUUID:toClone.uuid];
    }
}


- (IBAction)cloneInputSource:(id)sender
{
    
    InputSource *toClone = nil;

    if (sender)
    {
        if ([sender isKindOfClass:[NSMenuItem class]])
        {
            NSMenuItem *item = (NSMenuItem *)sender;
            toClone = (InputSource *)item.representedObject;
        } else if ([sender isKindOfClass:[InputSource class]]) {
            toClone = (InputSource *)sender;
        }
    }
    
    if (!toClone)
    {
        toClone = self.selectedSource;
    }

    if (toClone)
    {
        InputSource *newSource = [toClone cloneInput];
        [self.sourceLayout addSource:newSource];
        
        [[self.undoManager prepareWithInvocationTarget:self] undoCloneInput:newSource.uuid parentUUID:toClone.uuid];
    }
}


-(void)undoAddInput:(NSString *)uuid
{
    NSObject <CSInputSourceProtocol> *toDelete = [self.sourceLayout inputForUUID:uuid];
    if (toDelete)
    {
        [self deleteInput:toDelete];
    }
}


-(void)addInputSourceWithInput:(NSObject<CSInputSourceProtocol> *)source
{
    if (self.sourceLayout)
    {
        if (source.isVideo)
        {
            InputSource *vSrc = (InputSource *)source;
            vSrc.autoPlaceOnFrameUpdate = YES;
        }
        
        source.depth = FLT_MAX;
        [self.sourceLayout addSource:source];
        [[self.undoManager prepareWithInvocationTarget:self] undoAddInput:source.uuid];
    }
}



-(void)undoEditsource:(NSData *)withData
{
    
    
    InputSource *restoredSource = [NSKeyedUnarchiver unarchiveObjectWithData:withData];
    NSObject<CSInputSourceProtocol> *currentSource = [self.sourceLayout inputForUUID:restoredSource.uuid];
    if (currentSource)
    {
        [self.sourceLayout deleteSource:currentSource];
        NSData *curData = [NSKeyedArchiver archivedDataWithRootObject:currentSource];
        [[self.undoManager prepareWithInvocationTarget:self] undoEditsource:curData];
    }
    
    [self.sourceLayout addSource:restoredSource];
    
}


-(void)undoDeleteInput:(NSData *)withData parentUUID:(NSString *)parentUUID
{
    InputSource *restoredSource = [NSKeyedUnarchiver unarchiveObjectWithData:withData];
    

    [self.sourceLayout addSource:restoredSource];
    if (parentUUID)
    {
        NSObject<CSInputSourceProtocol> *parentSource = [self.sourceLayout inputForUUID:parentUUID];
        if (parentSource && parentSource.isVideo)
        {
            InputSource *vParent = (InputSource *)parentSource;
            [self attachSource:restoredSource toSource:vParent];
        }
    }
    [[self.undoManager prepareWithInvocationTarget:self] deleteInputByUUID:restoredSource.uuid];
}


-(void)deleteInputByUUID:(NSString *)uuid
{
    InputSource *src = (InputSource *)[self.sourceLayout inputForUUID:uuid];
    if (src)
    {
        [self deleteInput:src];
    }
}


- (IBAction)deleteInput:(id)sender
{
    NSObject<CSInputSourceProtocol> *toDelete = nil;

    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSMenuItem *item = (NSMenuItem *)sender;
        if (item && item.representedObject)
        {
            toDelete = item.representedObject;
        }
    } else if ([sender conformsToProtocol:@protocol(CSInputSourceProtocol)]) {
        toDelete = (NSObject<CSInputSourceProtocol> *)sender;
    }

    if (!toDelete)
    {
        toDelete = self.selectedSource ? self.selectedSource : self.mousedSource;
    }
    
    if (toDelete)
    {
        
        self.selectedSource = nil;
        self.mousedSource = nil;

        NSString *pUUID = nil;
        if (toDelete.isVideo)
        {
            InputSource *cInput = (InputSource *)toDelete;
            if (cInput.parentInput)
            {
                pUUID = cInput.parentInput.uuid;
                [cInput.parentInput detachInput:cInput];
            }
        }

        NSData *saveData = [NSKeyedArchiver archivedDataWithRootObject:toDelete];
        
        [[self.undoManager prepareWithInvocationTarget:self] undoDeleteInput:saveData parentUUID:pUUID];
        [self.sourceLayout deleteSource:toDelete];
        if (_overlayView)
        {
            _overlayView.parentSource = nil;
        }
    }
}




-(IBAction) autoFitInput:(id)sender
{
    InputSource *autoFitSource = nil;
    
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSMenuItem *item = (NSMenuItem *)sender;
        if (item && item.representedObject)
        {
            autoFitSource = item.representedObject;
        }
    } else if ([sender isKindOfClass:[InputSource class]]) {
        autoFitSource = (InputSource *)sender;
    }
    
    if (!autoFitSource)
    {
        autoFitSource = self.selectedSource;
    }

    if (autoFitSource)
    {
        [autoFitSource autoFit];
        [self.undoManager setActionName:@"Auto Fit"];
    }
}


- (void)showLayoutSettings:(id)sender
{
    
    
    NSPoint tmp = [self convertPoint:[self.window mouseLocationOutsideOfEventStream] fromView:nil];
    
    NSRect spawnRect = NSMakeRect(tmp.x, tmp.y, 1.0f, 1.0f);
    
    if (!NSPointInRect(NSMakePoint(tmp.x, 0), self.bounds))
    {
        spawnRect = NSMakeRect(self.bounds.size.width-5, tmp.y, 1.0f, 1.0f);
    } else if (!NSPointInRect(NSMakePoint(0, tmp.y), self.bounds)) {
        spawnRect = NSMakeRect(tmp.x, 5.0f, 1.0f, 1.0f);
    }
    
    [self.controller openBuiltinLayoutPopover:self spawnRect:spawnRect forLayout:self.sourceLayout];
}


- (IBAction)showInputSettings:(id)sender
{
    
    
    InputSource *configSource;
    
    NSMenuItem *menuSender = (NSMenuItem *)sender;
    
    
    
    configSource = self.selectedSource;
    if (menuSender.representedObject)
    {
        configSource = (InputSource *)menuSender.representedObject;
    }
    
    
    [self openInputConfigWindow:configSource.uuid];

}


-(void)goFullscreen:(NSScreen *)onScreen
{
    
    if (self.isInFullScreenMode)
    {
        [self exitFullScreenModeWithOptions:nil];
        return;
    }
    
    
    _fullScreenView = [[PreviewView alloc] init];
    [_fullScreenView awakeFromNib];
    _fullScreenView.isEditWindow = self.isEditWindow;
    _fullScreenView.layoutRenderer = self.layoutRenderer;
    
    
    _fullScreenView.sourceLayout = self.sourceLayout;
    NSNumber *fullscreenOptions = @(NSApplicationPresentationAutoHideMenuBar|NSApplicationPresentationAutoHideDock);
    [_fullScreenView enterFullScreenMode:onScreen withOptions:@{NSFullScreenModeAllScreens: @NO, NSFullScreenModeApplicationPresentationOptions: fullscreenOptions}];
    /*
     if (self.isInFullScreenMode)
     {
     [self exitFullScreenModeWithOptions:nil];
     self.hidden = NO;
     } else {
     if ([self.superview isKindOfClass:NSStackView.class])
     {
     NSLog(@"DO HIDE");
     self.superview.hidden = YES;
     }
     NSNumber *fullscreenOptions = @(NSApplicationPresentationAutoHideMenuBar|NSApplicationPresentationAutoHideDock);
     [self enterFullScreenMode:onScreen withOptions:@{NSFullScreenModeAllScreens: @NO, NSFullScreenModeApplicationPresentationOptions: fullscreenOptions}];
     
     }*/
}


- (IBAction)toggleFullscreen:(id)sender;
{
    [self goFullscreen:[NSScreen mainScreen]];
    
    
}

-(void)viewDidHide
{
    if (_glLayer)
    {
        _glLayer.doDisplay = NO;
    }
}

-(void)viewDidUnhide
{
    if (_glLayer)
    {
        _glLayer.doDisplay = YES;
    }
}

-(void)windowOcclusionStateChanged
{
    if (_glLayer)
    {
        if (self.window.occlusionState & NSWindowOcclusionStateVisible)
        {
            _glLayer.doDisplay = YES;
        } else {
            _glLayer.doDisplay = NO;
        }
    }
}
-(void)awakeFromNib
{
    
    self.activeConfigWindows = [NSMutableDictionary dictionary];
    self.activeConfigControllers = [NSMutableDictionary dictionary];
    _snapOverlay = [[CSSnapOverlayView alloc] init];
    _snapOverlay.autoresizingMask = NSViewHeightSizable|NSViewWidthSizable;
    _snapOverlay.frame = self.bounds;
    
    [self addSubview:_snapOverlay];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceWasDeleted:) name:CSNotificationInputDeleted object:nil];
    

    _configWindowCascadePoint = NSZeroPoint;
    
    _snap_x = _snap_y = -1;
    
    int opts = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited);
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                 options:opts
                                                   owner:self
                                                userInfo:nil];
    
    [self addTrackingArea:_trackingArea];

    [self setWantsLayer:YES];
    
    CGColorRef tmpColor = CGColorCreateGenericRGB(0.184314f, 0.309804f, 0.309804f, 1);
    self.layer.backgroundColor = tmpColor;
    CGColorRelease(tmpColor);
    
    [self registerForDraggedTypes:@[@"cocoasplit.library.item",NSSoundPboardType,NSFilenamesPboardType, NSFilesPromisePboardType, NSFileContentsPboardType, @"cocoasplit.input.uuids", @"cocoasplit.audio.item", @"cocoasplit.layout"]];
    self.undoManager.levelsOfUndo = 1;
    
    
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    
    if (self.viewOnly)
    {
        return NSDragOperationNone;
    }
    
    return NSDragOperationCopy;
    /*
    NSPasteboard *pboard;
    pboard = [sender draggingPasteboard];
    if ([pboard.types containsObject:@"cocoasplit.library.item"] && !self.viewOnly)
    {
        return NSDragOperationGeneric;
    }
    return NSDragOperationNone;
     */
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    
    pboard = [sender draggingPasteboard];
    
    if ([pboard canReadItemWithDataConformingToTypes:@[@"cocoasplit.layout"]])
    {
        NSData *indexSave = [pboard dataForType:@"cocoasplit.layout"];
        NSIndexSet *indexes = [NSKeyedUnarchiver unarchiveObjectWithData:indexSave];
        
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            SourceLayout *useLayout = [[CaptureController sharedCaptureController].sourceLayouts objectAtIndex:idx];
            if (useLayout)
            {
                [[CaptureController sharedCaptureController] switchToLayout:useLayout usingLayout:self.sourceLayout];
            }
        }];
        return YES;
    }
    
    if ([pboard canReadItemWithDataConformingToTypes:@[@"cocoasplit.library.item"]])
    {
        
        NSArray *classes = @[[CSInputLibraryItem class]];
        NSArray *draggedObjects = [pboard readObjectsForClasses:classes options:@{}];
        
        for (CSInputLibraryItem *item in draggedObjects)
        {
            NSData *iData = item.inputData;
            
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:iData];
            
            
            InputSource *iSrc = [unarchiver decodeObjectForKey:@"root"];
            [unarchiver finishDecoding];

            NSPoint mouseLoc = [NSEvent mouseLocation];
            
            NSRect rect = NSRectFromCGRect((CGRect){mouseLoc, CGSizeZero});
            
            mouseLoc = [self.window convertRectFromScreen:rect].origin;
            mouseLoc = [self convertPoint:mouseLoc fromView:nil];
            
            if (![self mouse:mouseLoc inRect:self.bounds])
            {
                return NO;
            }
            
            
            NSPoint worldPoint = [self realPointforWindowPoint:mouseLoc];


            [iSrc createUUID];

            iSrc.depth = FLT_MAX;
            [self.sourceLayout addSource:iSrc];
            //[iSrc positionOrigin:worldPoint.x y:worldPoint.y];
            iSrc.x_pos = worldPoint.x;
            iSrc.y_pos = worldPoint.y;
            if (item.autoFit)
            {
                iSrc.autoPlaceOnFrameUpdate = YES;
            }
        }
        return YES;
    }
    
    bool retVal = NO;
    for(NSPasteboardItem *item in pboard.pasteboardItems)
    {
        
        NSObject<CSInputSourceProtocol> *itemSrc = [CaptureController.sharedCaptureController inputSourceForPasteboardItem:item];
        if (itemSrc)
        {
            
            [self addInputSourceWithInput:itemSrc];
            if (itemSrc.isVideo)
            {
                InputSource *lsrc = (InputSource *)itemSrc;
                
                [lsrc autoCenter];
            }
            retVal = YES;
        }
    }

    return retVal;
}


-(CALayer *)makeBackingLayer
{
    
    if (CaptureController.sharedCaptureController.useMetalIfAvailable)
    {
        NSLog(@"CA LAYER");
        _glLayer = [CSPreviewCALayer layer];
    } else {
        NSLog(@"GL LAYER");
        _glLayer = [CSPreviewGLLayer layer];

    }
    _glLayer.doRender = self.isEditWindow;
    return _glLayer;
}


-(void)disablePrimaryRender
{
    _glLayer.doRender = NO;
}

-(void)enablePrimaryRender
{
    _glLayer.doRender = YES;
}


-(void)sourceWasDeleted:(NSNotification *)notification
{

    InputSource *toDel = notification.object;
    [self purgeConfigForInput:toDel];
}


-(void)purgeConfigForInput:(NSObject<CSInputSourceProtocol> *)src
{
    NSString *uuid = src.uuid;
    
    if (src.isVideo)
    {
        [self stopHighlightingSource:(InputSource *)src];
    }
    
    NSWindow *cWindow = [self.activeConfigWindows objectForKey:uuid];
    NSViewController *cController = [self.activeConfigControllers objectForKey:uuid];
    
    
    if (cController)
    {
        //cController.inputSource = nil;
        [self.activeConfigControllers removeObjectForKey:uuid];
    }
    
    if (cWindow)
    {
        [cWindow close];
        [self.activeConfigWindows removeObjectForKey:uuid];
    }
}


- (BOOL)popoverShouldDetach:(NSPopover *)popover
{
    return YES;
}


-(NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return self.undoManager;
}

-(void)openInputConfigWindows:(NSArray *)uuids
{
    _configWindowCascadePoint = NSZeroPoint;
    for (NSString *uuid in uuids)
    {
        [self openInputConfigWindow:uuid];
    }
}


-(void)openInputConfigWindow:(NSString *)uuid
{
    
    
    NSObject<CSInputSourceProtocol> *configSrc = [self.sourceLayout inputForUUID:uuid];
    
    if (!configSrc)
    {
        return;
    }
    
    NSViewController *newViewController = [configSrc configurationViewController];
    
    
    
    NSWindow *configWindow = [[NSWindow alloc] init];    
    NSRect newFrame = [configWindow frameRectForContentRect:NSMakeRect(0.0f, 0.0f, newViewController.view.frame.size.width, newViewController.view.frame.size.height)];
    
    
    
    [configWindow setFrame:newFrame display:NO];
    if (NSEqualPoints(_configWindowCascadePoint, NSZeroPoint))
    {
        [configWindow center];
        
        _configWindowCascadePoint = NSMakePoint(NSMinX(configWindow.frame), NSMaxY(configWindow.frame));
    } else {
        _configWindowCascadePoint = [configWindow cascadeTopLeftFromPoint:_configWindowCascadePoint];
    }

    [configWindow setReleasedWhenClosed:NO];
    
    
    [configWindow.contentView addSubview:newViewController.view];
    configWindow.title = [NSString stringWithFormat:@"CocoaSplit Input (%@)", configSrc.name];
    configWindow.delegate = self;
    
    configWindow.styleMask =  NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable;

    NSWindow *cWindow = [self.activeConfigWindows objectForKey:uuid];
    NSViewController *cController = [self.activeConfigControllers objectForKey:uuid];
    
    if (cController)
    {
        //cController.inputSource = nil;
        [self.activeConfigControllers removeObjectForKey:uuid];
    }
    
    if (cWindow)
    {
        [self.activeConfigWindows removeObjectForKey:uuid];
    }
    
    
    [self.activeConfigWindows setObject:configWindow forKey:uuid];
    [self.activeConfigControllers setObject:newViewController forKey:uuid];

    configWindow.identifier = uuid;
    
    [configWindow makeKeyAndOrderFront:nil];
}


-(void)windowWillClose:(NSNotification *)notification
{
    NSWindow *closedWindow = notification.object;
    
    if (closedWindow)
    {
        if (closedWindow == self.settingsConfigWindow.window)
        {
            self.settingsConfigWindow = nil;
            return;
        }
        
        
        NSString *uuid = closedWindow.identifier;
        NSWindow *cWindow = [self.activeConfigWindows objectForKey:uuid];
        NSViewController *cController = [self.activeConfigControllers objectForKey:uuid];
        
        
        if (cController)
        {
            [cController commitEditing];
            [self.activeConfigControllers removeObjectForKey:uuid];
        }
        
        if (cWindow)
        {
           [self.activeConfigWindows removeObjectForKey:uuid];
        }
        
    }
    
}

-(void)dealloc
{
    for(NSString *windowuuid in self.activeConfigWindows)
    {
        NSWindow *toClose = self.activeConfigWindows[windowuuid];
        [toClose close];
    }
    
    [self.activeConfigWindows removeAllObjects];
}



@end

