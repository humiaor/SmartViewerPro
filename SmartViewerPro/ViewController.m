//
//  ViewController.m
//  SmartViewerPro
//
//  Created by Hand-hitech-mac on 2025/4/14.
//

#import "ViewController.h"
#import "Masonry/Masonry.h"
#import "FFmpegWrapper.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

static NSString * const url = @"rtmp://liteavapp.qcloud.com/live/liteavdemoplayerstreamid";

@interface ViewController ()
@property (nonatomic,strong) UIImageView * previewView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
//    [self loadRTMP];
    [self openRTMPStream];
}

- (void)setupUI{
    UIImageView * imageView = [[UIImageView alloc] init];
    [self.view addSubview:imageView];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.centerY.equalTo(self.view);
        make.height.equalTo(@(200));
    }];
    self.previewView = imageView;
}

- (void)loadRTMP{
    FFmpegWrapper * ffmpeg = [[FFmpegWrapper alloc] initWithPreviewView:self.previewView];
    [ffmpeg openRTMPStream:url];
}


- (void)openRTMPStream{
    dispatch_async(dispatch_queue_create("com.ffmpeg.decode", DISPATCH_QUEUE_SERIAL), ^{
        
    // 全局初始化
    avformat_network_init();
    
    av_register_all();
    
    AVFormatContext *formatContext = avformat_alloc_context();
    const char *rtmpUrl = url.UTF8String;

    // 打开RTMP流
    int ret = avformat_open_input(&formatContext, rtmpUrl, NULL, NULL);
    if (ret != 0) {
        // 处理错误
        NSLog(@"open input error : %d",ret);
        return;
    }
    
    // 获取流信息
    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        // 处理错误
        avformat_close_input(&formatContext);
        return;
    }
    
    //查找视频流索引
    int videoStreamIndex = -1;
    for (int i = 0; i < formatContext->nb_streams; i++) {
//        if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
        if (formatContext->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStreamIndex = i;
            break;
        }
    }

    if (videoStreamIndex == -1) {
        // 没有找到视频流
        avformat_close_input(&formatContext);
        return;
    }
    
    // 初始化解码器
//    AVCodecParameters *codecParams = formatContext->streams[videoStreamIndex]->codecpar;
//    const AVCodec *codec = avcodec_find_decoder(codecParams->codec_id);
    AVCodecContext * codecContext = formatContext->streams[videoStreamIndex]->codec;
    const AVCodec * codec = avcodec_find_decoder(codecContext->codec_id);
    if (!codec) {
        // 解码器不支持
        avformat_close_input(&formatContext);
        return;
    }
    
//    AVCodecContext *codecContext = avcodec_alloc_context3(codec);
//    avcodec_parameters_to_context(codecContext, codecParams);
//
    if (avcodec_open2(codecContext, codec, NULL) < 0) {
        // 打开解码器失败
        avcodec_free_context(&codecContext);
        avformat_close_input(&formatContext);
        return;
    }
    
    //读取数据包并解码
    AVPacket packet;
    AVFrame *frame = av_frame_alloc();
    struct SwsContext *swsContext = NULL;

    while (1) {
        av_init_packet(&packet);
        int ret = av_read_frame(formatContext, &packet);
        if (ret < 0) {
            // 读取失败或流结束
            break;
        }

        if (packet.stream_index == videoStreamIndex) {
            // 发送数据包到解码器
//            ret = avcodec_send_packet(codecContext, &packet);
            int got_picture;
           ret = avcodec_decode_video2(codecContext, frame, &got_picture, &packet);
            if (ret < 0) {
                av_packet_unref(&packet);
                continue;
            }
            if (got_picture) {
                NSLog(@"到这了");
                // 接收解码后的帧
//                            while (avcodec_receive_frame(codecContext, frame) >= 0) {
//                while () {
                    
                    // 初始化SWSContext用于YUV转RGB（假设输出RGB）
                    if (!swsContext) {
                        swsContext = sws_getContext(
                                                    codecContext->width, codecContext->height, codecContext->pix_fmt,
                                                    codecContext->width, codecContext->height, AV_PIX_FMT_RGB24,
                                                    SWS_BILINEAR, NULL, NULL, NULL);
                    }
                
                // 转换为 RGB 数据（示例）
                AVFrame *rgb_frame = av_frame_alloc();
                rgb_frame->format = AV_PIX_FMT_RGB24;
                rgb_frame->width = frame->width;
                rgb_frame->height = frame->height;
//                av_frame_get_buffer(rgb_frame, 0);
                int buffer_size = avpicture_get_size(AV_PIX_FMT_RGB24, codecContext->width, codecContext->height);
                uint8_t *buffer = av_malloc(buffer_size);
                avpicture_fill((AVPicture *)rgb_frame, buffer, AV_PIX_FMT_RGB24, codecContext->width, codecContext->height);
                
                sws_scale(swsContext, (const uint8_t **)frame->data, frame->linesize,
                          0, frame->height, rgb_frame->data, rgb_frame->linesize);
                
                // 渲染到屏幕（通过 OpenGL ES 或 UIKit）
                [self renderFrame:rgb_frame];

                av_free(buffer);
                av_frame_free(&rgb_frame);
                
                
                
                    
                    // 转换帧数据
//                    uint8_t *rgbData[4];
//                    int rgbLinesize[4];
//                    av_image_alloc(rgbData, rgbLinesize, codecContext->width, codecContext->height, AV_PIX_FMT_RGB24, 1);
//                    
//                    sws_scale(swsContext, frame->data, frame->linesize, 0,
//                              codecContext->height, rgbData, rgbLinesize);
//                    
//                    // 回调或显示RGB数据（需处理内存和线程安全）
//                    if (self.onFrameDecoded) {
//                        NSData *frameData = [NSData dataWithBytes:rgbData[0] length:rgbLinesize[0] * codecContext->height];
//                        dispatch_async(dispatch_get_main_queue(), ^{
//                            self.onFrameDecoded(frameData, codecContext->width, codecContext->height);
//                        });
//                    }
                    
//                    av_freep(&rgbData[0]);
//                }
            }
        }

        av_packet_unref(&packet);
    }
        
    //资源释放
//    av_frame_free(&frame);
//    avcodec_free_context(&codecContext);
//    avformat_close_input(&formatContext);
//    sws_freeContext(swsContext);
//    avformat_network_deinit();
    //渲染视频帧（示例）在回调中获取 RGB 数据后，使用 CoreGraphics 或 Metal 渲染到界面：
//    线程管理：建议将 FFmpeg 操作放在后台线程，避免阻塞主线程。
//    内存管理：确保及时释放 AVPacket 和 AVFrame，避免内存泄漏。
//    错误处理：检查所有 FFmpeg API 的返回值，处理异常情况。
//    性能优化：可考虑使用硬件加速解码（如 VideoToolbox）提升效率。
    });
}

// 示例：将RGB数据转换为UIImage
- (UIImage *)imageFromRGBData:(NSData *)data width:(int)width height:(int)height {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate((void *)data.bytes, width, height,
                                                 8, width * 4, colorSpace,
                                                 kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast);
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    
    return image;
}

- (void)renderFrame:(AVFrame *)frame {
    if (frame->width <= 0 || frame->height <= 0 || !frame->data[0]) {
        // 处理无效帧
        NSLog(@"无效帧");
        return;
    }
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
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    dispatch_async(dispatch_get_main_queue(), ^{
//        if (self.previewView) {
//            if (self.previewView.image == nil) {
                self.previewView.image = image; // 假设有 UIImageView
//            }
//        }
    });
        
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
}

@end
