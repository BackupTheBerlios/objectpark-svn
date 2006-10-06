#import <AppKit/AppKit.h>

@interface NSSplitView (Autosave)

- (void)setAutosaveName:(NSString *)name;
- (NSString *)autosaveName;

- (void)setAutosaveDividerPosition:(BOOL)flag;
- (BOOL)autosaveDividerPosition;

@end
