//
//  tcpclient.m
//  Hello
//
//  Created by bluefish on 2019/8/12.
//  Copyright © 2019 systec. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdio.h>
//#include <error.h>
#include <errno.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <sys/time.h>

enum {
    LOG_FATAL,
    LOG_ERROR,
    LOG_WARNING,
    LOG_INFO,
    LOG_DEBUG,
    LOG_TRACE,
};

#define syslog_wrapper(level, format, arg...) \
    if(level <= LOG_ERROR) { \
        printf("[%s %d]: (%d %s) "format"\n", __FUNCTION__, __LINE__, errno, strerror(errno), ##arg); \
    } else { \
        printf("[%s %d]: "format"\n", __FUNCTION__, __LINE__, ##arg); \
    }

#define MAX_BUF_SIZE 1024

static void sig_handler(int no) {
    return;
}

int tcpclient_hello() {
    signal(SIGPIPE, sig_handler);
    const char *host = "114.116.109.114";
    const char *api = "/api/location";
    
    struct sockaddr_in s_addr;
    bzero(&s_addr, sizeof(struct sockaddr_in));
    s_addr.sin_family = AF_INET;
    s_addr.sin_port = htons(80);
    inet_pton(AF_INET, host, &s_addr.sin_addr.s_addr);
    
    fd_set wset, rset;
    struct timeval tm = {3, 0};
    
    int cfd = socket(AF_INET, SOCK_STREAM, 0);
    if(cfd < 0) {
        syslog_wrapper (LOG_ERROR, "socket");
        return -1;
    }
    
    int flag = fcntl(cfd, F_GETFL, 0);
    flag |= O_NONBLOCK | O_CLOEXEC;
    fcntl(cfd, F_SETFL, flag);
 
    FD_ZERO(&wset);
    FD_ZERO(&rset);
    FD_SET(cfd, &wset);
    FD_SET(cfd, &rset);
    
    int rc = connect(cfd, (struct sockaddr*)&s_addr, sizeof(s_addr));
    if(0 != rc) {
        if(errno != EINPROGRESS) {
            close(cfd);
            syslog_wrapper (LOG_ERROR, "connect");
            return -1;
        }
        rc = select(cfd+1, &rset, &wset, NULL, &tm);
        if(rc <= 0) {
            close(cfd);
            syslog_wrapper (LOG_ERROR, "select");
            return -1;
        }
    }
    
    flag &= ~O_NONBLOCK;
    fcntl(cfd, F_SETFL, flag);
    
    char buf[MAX_BUF_SIZE] = "";
    
    const char *body = (
        "{\"conf\":{\"image\":5},\"id\":0,\"name\":\"hh\",\"code\":0}"
    );
    
    rc = snprintf(
        buf,
        sizeof(buf)-1,
        (
            "POST %s HTTP/1.1\r\n"
            "Content-Type: application/json; charset=UTF-8\r\n"
            "Host: %s\r\n"
            "Connection: Keep-Alive\r\n"
            "User-Agent: hello/3.0\r\n"
            "Content-Length: %lu\r\n\r\n"
            "%s"
        ),
        api,
        host,
        strlen(body),
        body
    );
    
    if(rc <= 0) {
        close(cfd);
        syslog_wrapper (LOG_ERROR, "snprintf");
        return -1;
    }
    
    rc = (int)write(cfd, buf, rc);
    
    if(rc <= 0) {
        close(cfd);
        syslog_wrapper (LOG_ERROR, "write");
        return -1;
    }
    
    FD_ZERO(&wset);
    FD_ZERO(&rset);
    FD_SET(cfd, &wset);
    FD_SET(cfd, &rset);
    
    tm.tv_sec = 3;
    tm.tv_usec = 0;
    rc = select(cfd+1, &rset, &wset, NULL, &tm);
    if(rc <= 0) {
        close(cfd);
        syslog_wrapper (LOG_ERROR, "select");
        return -1;
    } else {
        rc = (int)read(cfd, buf, sizeof(buf)-1);
        if(rc > 0) {
            buf[rc] = '\0';
            syslog_wrapper (LOG_INFO, "ok: %s", buf);
        } else {
            syslog_wrapper (LOG_ERROR, "read");
        }
    }
    
    close(cfd);
    return rc;
}
