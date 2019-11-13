//
//  discovery.m
//  Hello
//
//  Created by systec on 2019/11/13.
//  Copyright © 2019 systec. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
//#include <bits/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <regex.h>

#include <errno.h>

#include <sys/socket.h>
#include <sys/time.h>

enum {
    LOG_FATAL,
    LOG_ERROR,
    LOG_WARNING,
    LOG_INFO,
    LOG_DEBUG,
    LOG_TRACE,
};
#define MAX_BUF_SIZE         4096

#define syslog_wrapper(level, format, arg...) \
    if(level <= LOG_ERROR) { \
        printf("[%s %d]: (%d %s) "format"\n", __FUNCTION__, __LINE__, errno, strerror(errno), ##arg); \
    } else { \
        printf("[%s %d]: "format"\n", __FUNCTION__, __LINE__, ##arg); \
    }

static const char *msg_d = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:SOAP-ENC=\"http://www.w3.org/2003/05/soap-encoding\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:wsa=\"http://schemas.xmlsoap.org/ws/2004/08/addressing\" xmlns:wsdd=\"http://schemas.xmlsoap.org/ws/2005/04/discovery\" xmlns:tdn=\"http://www.onvif.org/ver10/network/wsdl\">\n\
    <SOAP-ENV:Header>\n\
        <wsa:MessageID>urn:uuid:1234567890</wsa:MessageID>\n\
        <wsa:To SOAP-ENV:mustUnderstand=\"true\">urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To>\n\
        <wsa:Action SOAP-ENV:mustUnderstand=\"true\">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</wsa:Action>\n\
    </SOAP-ENV:Header>\n\
    <SOAP-ENV:Body>\n\
        <wsdd:Probe>\n\
            <wsdd:Types>tdn:00</wsdd:Types>\n\
            <wsdd:Scopes></wsdd:Scopes>\n\
        </wsdd:Probe>\n\
    </SOAP-ENV:Body>\n\
</SOAP-ENV:Envelope>\n";

static int udp_s_addr(struct sockaddr_in *addr, int port) {
    bzero(addr,sizeof(struct sockaddr_in));
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = htonl(INADDR_ANY);
    addr->sin_port = htons(port);
    return 0;
}

static int udp_c_addr(struct sockaddr_in *addr, const char *ip, int port) {
    bzero(addr,sizeof(struct sockaddr_in));
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = inet_addr(ip);
    addr->sin_port = htons(port);
    return 0;
}

static int udp_socket(struct sockaddr_in *addr, const char *mip) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if(-1 == fd) {
        perror("-1 == socket");
        return -1;
    }
    int opt = 1; /*turn on*/
/*  if(setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &opt, sizeof(int)) != 0) {
      perror("setsockopt SOL_SOCKET != 0");
      return -1;
    }*/
    if(NULL != mip) {
        struct ip_mreq mreq;
        mreq.imr_multiaddr.s_addr = inet_addr(mip);
        mreq.imr_interface.s_addr = htonl(INADDR_ANY);

        if(setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(struct ip_mreq)) != 0) {
            perror("setsockopt IPPROTO_IP != 0");
            return -1;
        }
    }

    opt = 1;
    if(setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(int)) != 0) {
        perror("setsockopt SO_REUSEADDR != 0");
        return -1;
    }

    if(0 != addr->sin_port) {
        if(bind(fd ,(struct sockaddr *)addr, sizeof(struct sockaddr)) == -1) {
            perror("bind == -1");
            return -1;
        }
    }

    return fd;
}

static int discovery_poll(int argc, char *argv[]) {
    char *ip = "0.0.0.0";
    char *mip = "239.255.255.240";
    int port = 3702;
    socklen_t iplen =  sizeof(struct sockaddr);
    struct sockaddr_in c_addr;
    char buf[MAX_BUF_SIZE];
    if(argc > 1) {
        ip = argv[1];
    }
    if(argc > 2) {
        port = atoi(argv[2]);
    }

    struct sockaddr_in addr;
    udp_s_addr(&addr, 0);
    int fd = udp_socket(&addr, mip);
    if(-1 == fd) {
        perror("-1 == udp_socket");
        return -1;
    }
    printf("fd %d\n", fd);

    fd_set rset;
    
    int len;
    
    udp_c_addr(&c_addr, mip, port);
    len = (int)strlen(msg_d);
    len = (int)sendto(fd, msg_d, len, 0, (struct sockaddr *)&c_addr, sizeof(struct sockaddr));
//    printf("%s\n", msg_d);
    if(len < 0) {
        perror("sendto");
    }
    printf("sendto len %d\n", len);
    
    while(1) {
        FD_ZERO(&rset);
        FD_SET(fd, &rset);
        struct timeval tm = {3, 0};
        int rc = select(fd+1, &rset, NULL, NULL, &tm);
        if(rc <= 0) {
            break;
        }
        int len = (int)recvfrom(fd, buf, MAX_BUF_SIZE-1, 0, (struct sockaddr *)&c_addr, &iplen);
        if(len > 0) {
            buf[len] = '\0';
//            printf("len %d %s\n", len, buf);
            regmatch_t pmatch[2];
            const size_t nmatch = 2;
            regex_t reg;
            const char *pattern = "<wsdd:Scopes>(.+)</wsdd:Scopes>";
            regcomp(&reg, pattern, REG_EXTENDED);
            int status = regexec(&reg, buf, nmatch, pmatch, 0);
            if (0 == status) {
                char data[MAX_BUF_SIZE] = "";
                snprintf(data, pmatch[1].rm_eo-pmatch[1].rm_so+1, "%s", buf + pmatch[1].rm_so);
                printf("%s\n", data);
            }
            regfree(&reg);
        } else {
            printf("len %d\n", len);
        }
    }
    close(fd);
    return 0;
}

int discovery_test(int argc, char *argv[]) {
  discovery_poll(argc, argv);
  return 0;
}
