//
//  FFmpegWrapper.m
//  SmartViewerPro
//
//  Created by Hand-hitech-mac on 2025/4/18.
//

#import "FFmpegWrapper.h"
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

@interface FFmpegWrapper ()

@property (nonatomic,strong) UIImageView * previewView;

@end

@implementation FFmpegWrapper{
    AVFormatContext *_fmt_ctx;
    AVCodecContext *_codec_ctx;
    AVFrame *_yuv_frame;
    struct SwsContext *_sws_ctx;
    int _video_stream_idx;
    dispatch_queue_t _decode_queue;
}

- (instancetype)initWithPreviewView:(UIImageView *)previewView {
    self = [super init];
    if (self) {
        _previewView = previewView;
        _decode_queue = dispatch_queue_create("com.ffmpeg.decode", DISPATCH_QUEUE_SERIAL);
        av_register_all();
        avformat_network_init();
    }
    return self;
}

- (void)openRTMPStream:(NSString *)url{
    dispatch_async(_decode_queue, ^{
        const char *rtmp_url = [url UTF8String];
        
        // 打开输入流
        if (avformat_open_input(&self->_fmt_ctx, rtmp_url, NULL, NULL) < 0) {
            NSLog(@"无法打开流");
            return;
        }
        
        // 查找流信息
        if (avformat_find_stream_info(self->_fmt_ctx, NULL) < 0) {
            NSLog(@"无法获取流信息");
            avformat_close_input(&self->_fmt_ctx);
            return;
        }
        
        // 查找视频流索引
        self->_video_stream_idx = -1;
        for (int i = 0; i < self->_fmt_ctx->nb_streams; i++) {
            if (self->_fmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
                self->_video_stream_idx = i;
                        break;
                    }
                }
                
            if (self->_video_stream_idx == -1) {
                NSLog(@"未找到视频流");
                avformat_close_input(&self->_fmt_ctx);
                return;
            }
        
        // 初始化解码器
//                AVCodecParameters *codec_params = _fmt_ctx->streams[_video_stream_idx]->codecpar;
//                AVCodec *codec = avcodec_find_decoder(codec_params->codec_id);
//                if (!codec) {
//                    NSLog(@"未找到解码器");
//                    avformat_close_input(&_fmt_ctx);
//                    return;
//                }
        
        AVCodecContext * codecContext = self->_fmt_ctx->streams[self->_video_stream_idx]->codec;
        const AVCodec * codec = avcodec_find_decoder(codecContext->codec_id);
        if (!codec) {
            // 解码器不支持
            avformat_close_input(&self->_fmt_ctx);
            return;
        }
        
//        _codec_ctx = avcodec_alloc_context3(codec);
//                avcodec_parameters_to_context(_codec_ctx, codec_params);
//                if (avcodec_open2(_codec_ctx, codec, NULL) < 0) {
//                    NSLog(@"无法打开解码器");
//                    avcodec_free_context(&_codec_ctx);
//                    avformat_close_input(&_fmt_ctx);
//                    return;
//                }
        
        self->_codec_ctx = codecContext;
        if (avcodec_open2(codecContext, codec, NULL) < 0) {
            // 打开解码器失败
            avcodec_free_context(&codecContext);
            avformat_close_input(&self->_fmt_ctx);
            return;
        }
        
        // 初始化 YUV 帧和 SwsContext
        self->_yuv_frame = av_frame_alloc();
//        self->_sws_ctx = sws_getContext(self->_codec_ctx->width, self->_codec_ctx->height,self->_codec_ctx->pix_fmt,self->_codec_ctx->width, self->_codec_ctx->height, AV_PIX_FMT_YUV420P,SWS_BILINEAR, NULL, NULL, NULL);
//               
//               [self startDecoding];
//           });
        self->_sws_ctx = sws_getContext(self->_codec_ctx->width, self->_codec_ctx->height,self->_codec_ctx->pix_fmt,self->_codec_ctx->width, self->_codec_ctx->height, AV_PIX_FMT_RGB24,SWS_BILINEAR, NULL, NULL, NULL);
               
               [self startDecoding];
           });
}

- (void)startDecoding {
    AVPacket packet;
    av_init_packet(&packet);
    
    while (av_read_frame(_fmt_ctx, &packet) >= 0) {
        if (packet.stream_index == _video_stream_idx) {
            int got_frame = 0;
            int len = avcodec_decode_video2(self->_codec_ctx, _yuv_frame, &got_frame, &packet);
            if (len < 0) {
                NSLog(@"解码错误");
                break;
            }
            
            if (got_frame) {
                // 转换为 RGB 数据（示例）
                AVFrame *rgb_frame = av_frame_alloc();
                int buffer_size = avpicture_get_size(AV_PIX_FMT_RGB24, self->_codec_ctx->width, self->_codec_ctx->height);
                uint8_t *buffer = av_malloc(buffer_size);
                avpicture_fill((AVPicture *)rgb_frame, buffer, AV_PIX_FMT_RGB24, self->_codec_ctx->width, self->_codec_ctx->height);
                
                sws_scale(_sws_ctx, (const uint8_t **)_yuv_frame->data, _yuv_frame->linesize,
                          0, self->_codec_ctx->height, rgb_frame->data, rgb_frame->linesize);
                
                // 渲染到屏幕（通过 OpenGL ES 或 UIKit）
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self renderFrame:rgb_frame];
                });
                
                av_free(buffer);
                av_frame_free(&rgb_frame);
            }
        }
        av_packet_unref(&packet);
    }
    
    // 清理资源
    av_frame_free(&_yuv_frame);
    sws_freeContext(_sws_ctx);
    avcodec_close(self->_codec_ctx);
    avformat_close_input(&_fmt_ctx);
}

- (void)renderFrame:(AVFrame *)frame {
    // 将 RGB 数据转换为 UIImage（性能较低，仅作演示）
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, frame->data[0], frame->linesize[0] * frame->height, kCFAllocatorNull);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(
        frame->width, frame->height,
        8, 24, frame->linesize[0], colorSpace,
        bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault
    );
    
    if (self.previewView) {
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        self.previewView.image = image; // 假设有 UIImageView
    }
        
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
}

- (void)uploadYUVToTextureWithY:(uint8_t *)Y U:(uint8_t *)U V:(uint8_t *)V width:(int)width height:(int)height {
    // 创建 YUV 纹理
//    glActiveTexture(GL_TEXTURE0);
//    glBindTexture(GL_TEXTURE_2D, _yTexture);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, Y);
//    
//    glActiveTexture(GL_TEXTURE1);
//    glBindTexture(GL_TEXTURE_2D, _uTexture);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, U);
//    
//    glActiveTexture(GL_TEXTURE2);
//    glBindTexture(GL_TEXTURE_2D, _vTexture);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, V);
}


@end
