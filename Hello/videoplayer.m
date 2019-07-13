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
    int is_restart;
    int is_stop;
    int is_open;
    char uri[256];
    int restart_count;
    NSTimeInterval time_restart;
    NSTimeInterval time_frame;
    NSTimeInterval time_start;
    NSTimeInterval time_frame_start;
    
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
    NSObject<VideoPlayerHandler> *handler;
} Videoplayer_t;

static void videoplayer_send_message(Videoplayer_t *self, const char *data) {
    __block NSString *label = [[NSString alloc] initWithUTF8String: data];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_sync(queue, ^{
        [self->handler videoPlayerMessageHandler: label];
    });
}

static int videoplayer_callback(void *player) {
    Videoplayer_t *self = (Videoplayer_t *)player;
    NSTimeInterval current_time = [[NSDate date] timeIntervalSince1970];
    if(0 != self->time_start && current_time > self->time_start) {
        NSLog(@"videoplayer_callback timeout");
        return 1;
    }
    return 0;
}

static int videoplayer_open(Videoplayer_t *self) {
    
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

static int videoplayer_close(Videoplayer_t *self) {
    if(self->is_open) {
        avformat_free_context(self->format_ctx);
        av_frame_free(&self->frame);
        sws_freeContext(self->sws_ctx);
        avpicture_free(&self->picture);
        self->is_open = FALSE;
    }
    return 0;
}

static void videoplayer_rendering(Videoplayer_t *self) {
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
                
                double video_timebase = av_q2d(self->stream->time_base);
                double timestamp = self->packet.pts * video_timebase;
                if(self->time_frame_start+timestamp+2.0 < current_time) {
                    interval = 0;
                }
                NSLog(@"frame index: %d %f %f", self->frame_index, current_time-self->time_frame_start-timestamp, interval);
                
                if(interval > 0) {
                    [NSThread sleepForTimeInterval:interval];
                }
                
                dispatch_queue_t queue = dispatch_get_main_queue();
                dispatch_async(queue, ^{
                    if(!self->is_stop) {
                        [self->handler videoPlayerHandler: image];
                    }
//                    [self->handler messageHandlerWithData: @"hello"];
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

static void videoplayer_handler(Videoplayer_t *self) {
    NSTimeInterval current_time = [[NSDate date] timeIntervalSince1970];
    self->time_restart = current_time;
    self->time_frame_start = current_time;
    self->time_frame = 0;
    self->restart_count = 0;
    self->frame_index = 0;
    self->frame_rate = 1.0;
    
    videoplayer_send_message(self, "videoplayer play");
    
    while(!self->is_stop) {
        if(!self->is_open) {
            if(0 == videoplayer_open(self)) {
                self->time_frame_start = [[NSDate date] timeIntervalSince1970];
                self->is_open = TRUE;
                NSLog(@"videoplayer_open %s ok", self->uri);
                videoplayer_send_message(self, "videoplayer open ok");
            } else {
                NSLog(@"videoplayer_open %s fail", self->uri);
                videoplayer_send_message(self, "videoplayer open fail");
            }
            if(0 != self->time_frame) {
                sleep(1.0);
            }
            continue;
        } else if(self->is_restart) {
            videoplayer_close(self);
            self->is_restart = TRUE;
            if(0 != self->time_frame) {
                sleep(1.0);
            }
            continue;
        }
        videoplayer_rendering(self);
    }
    videoplayer_close(self);
    NSLog(@"videoplayer_stop %s ok", self->uri);
    videoplayer_send_message(self, "videoplayer stop ok");
    free(self);
}

void videoplayer_stop(void *player) {
    Videoplayer_t *self = (Videoplayer_t *)player;
    self->is_stop = TRUE;
}

void *videoplayer_play(NSObject *handler, const char *uri) {
    Videoplayer_t *self = calloc(1, sizeof(Videoplayer_t));
    self->is_restart = FALSE;
    self->is_stop = FALSE;
    self->is_open = FALSE;
    self->uri[0] = '\0';
    self->frame_index = 0;
    self->handler = (NSObject<VideoPlayerHandler> *)handler;
    
    sprintf(self->uri, "%s", uri);
    dispatch_queue_t queue = dispatch_queue_create("systec.Hello.videoplayer", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        NSLog(@"videoplayer_play %s", self->uri);
        videoplayer_handler(self);
    });
    return (void *)self;
}
