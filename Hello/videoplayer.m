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
    int is_restart;
    int is_stop;
    int is_open;
    char uri[256];
    int restart_count;
    NSTimeInterval time_restart;
    NSTimeInterval time_frame;
    NSTimeInterval time_start;
    
    AVPicture picture;
    AVFormatContext *format_ctx;
    AVCodecContext *codec_ctx;
    AVFrame *frame;
    AVStream *stream;
    struct SwsContext *sws_ctx;
    AVPacket packet;
    int width;
    int height;
    int stream_index;
    int frame_index;
    int frame_rate;
} Videoplayer_t;

Videoplayer_t videoplayer = {
    .is_restart = FALSE,
    .is_stop = FALSE,
    .is_open = FALSE,
    .uri = "",
    .frame_index = 0,
};

Videoplayer_t *self = &videoplayer;

static int videoplayer_callback(void *ctx) {
    NSTimeInterval current_time = [[NSDate date] timeIntervalSince1970];
    if(0 != self->time_start && current_time > self->time_start) {
        NSLog(@"videoplayer_callback timeout");
        return 1;
    }
    return 0;
}

static int videoplayer_open() {
    
    self->format_ctx = avformat_alloc_context();
    self->format_ctx->interrupt_callback.callback = videoplayer_callback;
    self->format_ctx->interrupt_callback.opaque = self;
    
    self->frame = av_frame_alloc();
    AVDictionary *opts = NULL;
    
    NSLog(@"before avformat_open_input");
    
    self->time_start = [[NSDate date] timeIntervalSince1970] + 3.0;
    int rc = avformat_open_input(&self->format_ctx, self->uri, NULL, &opts);
    self->time_start = 0;
    
    NSLog(@"after avformat_open_input");
    if (rc < 0){
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        NSLog(@"avformat_open_input fail");
        return -1;
    }
    
    self->format_ctx->max_analyze_duration = 1.0 * AV_TIME_BASE;
    
    self->time_start = [[NSDate date] timeIntervalSince1970] + 3.0;
    rc = avformat_find_stream_info(self->format_ctx, NULL);
    if (rc < 0) {
        NSLog(@"avformat_find_stream_info < 0");
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        return -1;
    }
    self->time_start = 0;
    
    NSLog(@"after avformat_find_stream_info");
    self->stream_index = -1;
    for (uint i = 0; i < self->format_ctx->nb_streams; i++) {
        if (AVMEDIA_TYPE_VIDEO == self->format_ctx->streams[i]->codec->codec_type) {
            self->stream_index = i;
            break;
        }
    }
    
    if (-1 == self->stream_index) {
        NSLog(@"-1 == stream_index");
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        return -1;
    }
    
    self->stream = self->format_ctx->streams[self->stream_index];
    if(0 != self->stream->avg_frame_rate.den) {
        self->frame_rate = self->stream->avg_frame_rate.num/self->stream->avg_frame_rate.den;
    }
    NSLog(@"frame_rate %d", self->frame_rate);
    
    self->codec_ctx = self->format_ctx->streams[self->stream_index]->codec;
    self->width = self->codec_ctx->width;
    self->height = self->codec_ctx->height;
    
    if(self->width <= 0 || self->height <= 0) {
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        NSLog(@"invalid size width: %d, height: %d", self->width, self->height);
        return -1;
    }
    
    avpicture_alloc(&self->picture, AV_PIX_FMT_RGB24, self->width, self->height);
    
    AVCodec *codec;
    
    codec = avcodec_find_decoder(self->codec_ctx->codec_id);
    self->sws_ctx = sws_getContext(self->width, self->height, AV_PIX_FMT_YUV420P, self->width, self->height, AV_PIX_FMT_RGB24, SWS_BICUBIC, 0, 0, 0);
    
    NSLog(@"after avcodec_find_decoder");
    rc = avcodec_open2(self->codec_ctx, codec, NULL);
    if (rc < 0){
        NSLog(@"avcodec_open2 < 0");
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        sws_freeContext(self->sws_ctx);
        avpicture_free(&self->picture);
        return -1;
    }
    return 0;
}

static int videoplayer_close() {
    if(self->is_open) {
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        sws_freeContext(self->sws_ctx);
        avpicture_free(&self->picture);
        self->is_open = FALSE;
    }
    return 0;
}

static void videoplayer_rendering() {
    int frame_finished = FALSE;
    
    NSDate *date = [NSDate date];
    NSTimeInterval current_time = [date timeIntervalSince1970];
    
    self->time_start = [[NSDate date] timeIntervalSince1970] + 3.0;
    
    if (av_read_frame(self->format_ctx, &self->packet) >= 0){
        if(self->packet.stream_index == self->stream_index){
            avcodec_decode_video2(self->codec_ctx, self->frame, &frame_finished, &self->packet);
            if (frame_finished){
                sws_scale(self->sws_ctx, (const uint8_t* const *)self->frame->data, self->frame->linesize, 0, self->height, self->picture.data,self->picture.linesize);
                CGBitmapInfo bitmap_info = kCGBitmapByteOrderDefault;
                CFDataRef data = CFDataCreate(kCFAllocatorDefault, self->picture.data[0], self->picture.linesize[0] * self->height);
                
                CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
                CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
                CGImageRef cg_image = CGImageCreate(self->width,
                                                   self->height,
                                                   8,
                                                   24,
                                                   self->picture.linesize[0],
                                                   color_space,
                                                   bitmap_info,
                                                   provider,
                                                   NULL,
                                                   NO,
                                                   kCGRenderingIntentDefault);
                
                UIImage *image = [UIImage imageWithCGImage:cg_image];
                CGImageRelease(cg_image);
                CGColorSpaceRelease(color_space);
                CGDataProviderRelease(provider);
                CFRelease(data);
                
                NSTimeInterval current_time = [[NSDate date] timeIntervalSince1970];
                NSTimeInterval interval = self->time_frame+1.0/self->frame_rate-current_time;
                
//                AVStream *stream = self->format_ctx->streams[self->stream_index];
                double video_timebase = av_q2d(self->stream->time_base);
                double timestamp = self->packet.pts * video_timebase;
                NSLog(@"frame index: %d %f %f", self->frame_index, timestamp, current_time);
                
//                if(self->time_frame == 0 || self->time_frame+(0.9/self->frame_rate) > current_time) {
//                    NSLog(@"fast frame index: %d", self->frame_index);
//                } else {
//                    interval = 0.9/self->frame_rate;
//                    interval = self->time_frame+1.0/self->frame_rate-current_time;
//                    NSLog(@"normal frame index: %d", self->frame_index);
//                }
                
                if(interval > 0) {
                    [NSThread sleepForTimeInterval:interval];
                }
                
                dispatch_queue_t queue = dispatch_get_main_queue();
                dispatch_async(queue, ^{
                    [ViewController image: image];
                });
                ++self->frame_index;
                self->time_frame = [[NSDate date] timeIntervalSince1970];
            }
        }
        self->time_restart = current_time;
    } else {
        if(self->time_restart + 5.0 < current_time) {
            self->is_restart = TRUE;
            self->time_restart = current_time;
            ++self->restart_count;
            NSLog(@"self->restart_count %d", self->restart_count);
        }
    }
    av_free_packet(&self->packet);
    self->time_start = 0;
}

static void videoplayer_handler() {
    NSDate *date = [NSDate date];
    NSTimeInterval current_time = [date timeIntervalSince1970];
    self->time_restart = current_time;
    self->time_frame = 0;
    self->restart_count = 0;
    self->frame_index = 0;
    self->frame_rate = 1.0;
    
    while(!self->is_stop) {
        if(!self->is_open) {
            NSLog(@"videoplayer is not open %s", self->uri);
            if(0 == videoplayer_open()) {
                self->is_open = TRUE;
                NSLog(@"videoplayer_open %s ok", self->uri);
            } else {
                NSLog(@"videoplayer_open %s fail", self->uri);
            }
            if(0 != self->time_frame) {
                sleep(1.0);
            }
            continue;
        } else if(self->is_restart) {
            videoplayer_close();
            self->is_restart = TRUE;
            if(0 != self->time_frame) {
                sleep(1.0);
            }
            continue;
        }
        videoplayer_rendering();
    }
    videoplayer_close();
}

void videoplayer_init() {
    self->queue = dispatch_queue_create("systec.Hello.videoplayer", DISPATCH_QUEUE_SERIAL);
}

void videoplayer_stop() {
    self->is_stop = TRUE;
}

void videoplayer_play(const char *uri) {
    if(strlen(uri) < 4) {
        return;
    }
    self->is_stop = TRUE;
    sprintf(self->uri, "%s", uri);
    dispatch_async(self->queue, ^{
        NSLog(@"videoplayer_play %s", self->uri);
        self->is_stop = FALSE;
        videoplayer_handler();
    });
}
