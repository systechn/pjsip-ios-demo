//
//  videoplayer.m
//  Hello
//
//  Created by bluefish on 2019/7/6.
//  Copyright © 2019 systec. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Hello-Swift.h"

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavfilter/avfilter.h"
#include "libswscale/swscale.h"
#include "libavutil/frame.h"

typedef struct Videoplayer_t {
    dispatch_queue_t queue;
    int restart;
    int stop;
    int isopen;
    char uri[256];
    AVPicture  pAVPicture;
    AVFormatContext *pAVFormatContext;
    AVCodecContext *pAVCodecContext;
    AVFrame *pAVFrame;
    struct SwsContext *pSwsContext;
    AVPacket pAVPacket;
    int videoWidth;
    int videoHeight;
    int videoStreamIndex;
    NSTimeInterval time0;
    int restart_count;
} Videoplayer_t;

Videoplayer_t videoplayer = {
    .restart = 0,
    .stop = 0,
    .isopen = 0,
    .uri = "",
};

static int videoplayer_open() {
    videoplayer.pAVFormatContext = avformat_alloc_context();
    videoplayer.pAVFrame = av_frame_alloc();
    AVDictionary *opts = NULL;
    av_dict_set(&opts, "stimeout", "6000000", 0);
    
    int result = avformat_open_input(&videoplayer.pAVFormatContext, videoplayer.uri, NULL, &opts);
    
    if (result < 0){
        avformat_free_context(videoplayer.pAVFormatContext);
        av_frame_free(&videoplayer.pAVFrame);
        printf("avformat_open_input fail\n");
        return -1;
    }
    
    result = avformat_find_stream_info(videoplayer.pAVFormatContext, NULL);
    if (result < 0) {
        printf("avformat_find_stream_info < 0\n");
        avformat_free_context(videoplayer.pAVFormatContext);
        av_frame_free(&videoplayer.pAVFrame);
        return -1;
    }
    
    videoplayer.videoStreamIndex = -1;
    for (uint i = 0; i < videoplayer.pAVFormatContext->nb_streams; i++) {
        if (AVMEDIA_TYPE_VIDEO == videoplayer.pAVFormatContext->streams[i]->codec->codec_type) {
            videoplayer.videoStreamIndex = i;
            break;
        }
    }
    
    if (-1 == videoplayer.videoStreamIndex) {
        printf("-1 == videoStreamIndex\n");
        avformat_free_context(videoplayer.pAVFormatContext);
        av_frame_free(&videoplayer.pAVFrame);
        return -1;
    }
    
    videoplayer.pAVCodecContext = videoplayer.pAVFormatContext->streams[videoplayer.videoStreamIndex]->codec;
    videoplayer.videoWidth = videoplayer.pAVCodecContext->width;
    videoplayer.videoHeight = videoplayer.pAVCodecContext->height;
    
    avpicture_alloc(&videoplayer.pAVPicture, AV_PIX_FMT_RGB24, videoplayer.videoWidth, videoplayer.videoHeight);
    
    AVCodec *pAVCodec;
    
    pAVCodec = avcodec_find_decoder(videoplayer.pAVCodecContext->codec_id);
    videoplayer.pSwsContext = sws_getContext(videoplayer.videoWidth, videoplayer.videoHeight, AV_PIX_FMT_YUV420P, videoplayer.videoWidth, videoplayer.videoHeight, AV_PIX_FMT_RGB24,
                                 SWS_BICUBIC, 0, 0, 0);
    
    result = avcodec_open2(videoplayer.pAVCodecContext, pAVCodec, NULL);
    if (result<0){
        printf("avcodec_open2 < 0\n");
        avformat_free_context(videoplayer.pAVFormatContext);
        av_frame_free(&videoplayer.pAVFrame);
        sws_freeContext(videoplayer.pSwsContext);
        avpicture_free(&videoplayer.pAVPicture);
        return -1;
    }
    return 0;
}

static int videoplayer_close() {
    if(videoplayer.isopen) {
        avformat_free_context(videoplayer.pAVFormatContext);
        av_frame_free(&videoplayer.pAVFrame);
        sws_freeContext(videoplayer.pSwsContext);
        avpicture_free(&videoplayer.pAVPicture);
        videoplayer.isopen = 0;
    }
    return 0;
}

static void videoplayer_rendering() {
    int frameFinished = 0;
    
    NSDate *date = [NSDate date];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    
    if (av_read_frame(videoplayer.pAVFormatContext, &videoplayer.pAVPacket) >= 0){
        if(videoplayer.pAVPacket.stream_index == videoplayer.videoStreamIndex){
            avcodec_decode_video2(videoplayer.pAVCodecContext, videoplayer.pAVFrame, &frameFinished, &videoplayer.pAVPacket);
            if (frameFinished){
                sws_scale(videoplayer.pSwsContext,(const uint8_t* const *)videoplayer.pAVFrame->data,videoplayer.pAVFrame->linesize,0,videoplayer.videoHeight,videoplayer.pAVPicture.data,videoplayer.pAVPicture.linesize);
                CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
                CFDataRef data = CFDataCreate(kCFAllocatorDefault, videoplayer.pAVPicture.data[0], videoplayer.pAVPicture.linesize[0] * videoplayer.videoHeight);
                
                CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                CGImageRef cgImage = CGImageCreate(videoplayer.videoWidth,
                                                   videoplayer.videoHeight,
                                                   8,
                                                   24,
                                                   videoplayer.pAVPicture.linesize[0],
                                                   colorSpace,
                                                   bitmapInfo,
                                                   provider,
                                                   NULL,
                                                   NO,
                                                   kCGRenderingIntentDefault);
                
                UIImage *image = [UIImage imageWithCGImage:cgImage];
                CGImageRelease(cgImage);
                CGColorSpaceRelease(colorSpace);
                CGDataProviderRelease(provider);
                CFRelease(data);
                
                dispatch_queue_t queue = dispatch_get_main_queue();
                dispatch_async(queue, ^{
                    [ViewController image: image];
                });
            }
        }
        videoplayer.time0 = currentTime;
    } else {
        if(videoplayer.time0 + 5.0 < currentTime) {
            videoplayer.restart = 1;
            videoplayer.time0 = currentTime;
            ++videoplayer.restart_count;
            printf("videoplayer.restart_count %d\n", videoplayer.restart_count);
        }
    }
    av_free_packet(&videoplayer.pAVPacket);
}

static void videoplayer_handler() {
    NSDate *date = [NSDate date];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    videoplayer.time0 = currentTime;
    videoplayer.restart_count = 0;
    
    while(!videoplayer.stop) {
        if(!videoplayer.isopen) {
            if(0 == videoplayer_open()) {
                videoplayer.isopen = 1;
                printf("videoplayer_open %s ok\n", videoplayer.uri);
            } else {
                printf("videoplayer_open %s fail\n", videoplayer.uri);
            }
            sleep(1.0);
            continue;
        } else if(videoplayer.restart) {
            videoplayer_close();
            videoplayer.restart = 0;
            sleep(1.0);
            continue;
        }
        videoplayer_rendering();
    }
    videoplayer_close();
}

void videoplayer_init() {
    videoplayer.queue = dispatch_queue_create("systec.Hello.videoplayer", DISPATCH_QUEUE_SERIAL);
}

void videoplayer_stop() {
    videoplayer.stop = 1;
}

void videoplayer_play(const char *uri) {
    if(strlen(uri) < 4) {
        return;
    }
    videoplayer.stop = 1;
    sprintf(videoplayer.uri, "%s", uri);
    dispatch_async(videoplayer.queue, ^{
        videoplayer.stop = 0;
        videoplayer_handler();
    });
}