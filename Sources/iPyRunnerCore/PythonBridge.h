#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PythonBridge : NSObject
+ (BOOL)isAvailable;
+ (void)startWithPythonHome:(NSString *)pythonHome pythonPath:(NSString *)pythonPath NS_SWIFT_NAME(start(pythonHome:pythonPath:));
+ (NSDictionary *)runCode:(NSString *)code filename:(NSString *)filename NS_SWIFT_NAME(runCode(_:filename:));
@end

NS_ASSUME_NONNULL_END
