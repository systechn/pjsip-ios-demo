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
#include <regex.h>

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

NSString *tcpclient_hello(const char *host, const char *path, const char *body) {
    signal(SIGPIPE, SIG_IGN);
//    signal(SIGPIPE, SIG_DFL);
    NSString *label;
    
    struct sockaddr_in s_addr;
    bzero(&s_addr, sizeof(struct sockaddr_in));
    s_addr.sin_family = AF_INET;
    s_addr.sin_port = htons(80);
    inet_pton(AF_INET, host, &s_addr.sin_addr.s_addr);
    
    fd_set wset, rset;
    struct timeval tm = {3, 0};
    
    int cfd = socket(AF_INET, SOCK_STREAM, 0);
    if(cfd < 0) {
        syslog_wrapper (LOG_ERROR, "socket create fail");
        return label;
    }
    
    int flag = fcntl(cfd, F_GETFL, 0);
    flag |= O_NONBLOCK | O_CLOEXEC;
    fcntl(cfd, F_SETFL, flag);
 
    FD_ZERO(&rset);
    FD_SET(cfd, &rset);
    FD_ZERO(&wset);
    FD_SET(cfd, &wset);
    
    int rc = connect(cfd, (struct sockaddr*)&s_addr, sizeof(s_addr));
    if(0 != rc) {
        if(errno != EINPROGRESS) {
            close(cfd);
            syslog_wrapper (LOG_ERROR, "connect fail");
            return label;
        }
        rc = select(cfd+1, &rset, &wset, NULL, &tm);
        if(rc <= 0) {
            close(cfd);
            syslog_wrapper (LOG_ERROR, "connect timeout");
            return label;
        }
    }
    
    flag &= ~O_NONBLOCK;
    fcntl(cfd, F_SETFL, flag);
    
    char buf[MAX_BUF_SIZE] = "";
    
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
        path,
        host,
        strlen(body),
        body
    );
    
    if(rc <= 0) {
        close(cfd);
        syslog_wrapper (LOG_ERROR, "snprintf");
        return label;
    }
    
//    FD_ZERO(&wset);
//    FD_SET(cfd, &wset);
//
//    tm.tv_sec = 3;
//    tm.tv_usec = 0;
//    rc = select(cfd+1, NULL, &wset, NULL, &tm);
//    if(rc <= 0) {
//        close(cfd);
//        syslog_wrapper (LOG_ERROR, "write timeout");
//        return label;
//    } else {
//        rc = (int)write(cfd, buf, rc);
//        if(rc <= 0) {
//            close(cfd);
//            syslog_wrapper (LOG_ERROR, "write fail");
//            return label;
//        }
//    }
    
    rc = (int)write(cfd, buf, rc);
    
    FD_ZERO(&rset);
    FD_SET(cfd, &rset);
    FD_ZERO(&wset);
    FD_SET(cfd, &wset);
    
    tm.tv_sec = 3;
    tm.tv_usec = 0;
    rc = select(cfd+1, &rset, NULL, NULL, &tm);
    if(rc <= 0) {
        close(cfd);
        syslog_wrapper (LOG_ERROR, "read timeout");
        return label;
    } else {
        rc = (int)read(cfd, buf, sizeof(buf)-1);
        if(rc > 0) {
            buf[rc] = '\0';
//            syslog_wrapper (LOG_INFO, "ok: %s", buf);
            regmatch_t pmatch[2];
            const size_t nmatch = 2;
            regex_t reg;
            const char *pattern = "\r\n\r\n(.+)";
            regcomp(&reg, pattern, REG_EXTENDED);
            int status = regexec(&reg, buf, nmatch, pmatch, 0);
            if (0 == status) {
                char data[MAX_BUF_SIZE] = "";
                snprintf(data, pmatch[1].rm_eo-pmatch[1].rm_so+1, "%s", buf + pmatch[1].rm_so);
                label = [[NSString alloc] initWithUTF8String: data];
            }
            regfree(&reg);
        } else {
            syslog_wrapper (LOG_ERROR, "read fail");
        }
    }
    
    close(cfd);
    return label;
}

// Demo
//@IBAction func onTcpClient(_ sender: Any) {
//    class Message: HandyJSON {
//        required init() {}
//        var code: Int!
//        var message: String!
//        var device_code: String!
//    }
//    let host: String = self.tcpClientHost.text ?? "10.19.11.144"
//    let queue = DispatchQueue(label: "com.systec.tcpclient")
//    queue.async {
//        let data: String = tcpclient_hello(
//                                           "\(host)",
//                                           "/api/code",
//                                           "{\"user_id\":\"0000000000000001\",\"server\":\"sg.systec-pbx.net\"}"
//                                           ) ?? ""
//        DispatchQueue.main.async {
//            let a_data = Message.deserialize(from: data)
//            if(nil != a_data) {
//                Logger.info.cat("\(a_data?.code ?? -1), \(a_data?.message ?? "nil"), \(a_data?.device_code ?? "nil")")
//                self.tcpClientData.text.append("\(data)\n")
//                self.tcpClientData.scrollRangeToVisible(NSRange.init(location: self.tcpClientData.text.count, length: 1))
//            }
//        }
//    }
//}
