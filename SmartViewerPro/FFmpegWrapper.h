//
//  FFmpegWrapper.h
//  SmartViewerPro
//
//  Created by Hand-hitech-mac on 2025/4/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIImageView;

@interface FFmpegWrapper : NSObject

- (instancetype)initWithPreviewView:(UIImageView *)previewView;

- (void)openRTMPStream:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
