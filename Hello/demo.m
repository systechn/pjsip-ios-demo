//
//  demo.m
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Hello-Swift.h"

#import "demo.h"

#import <pjsua.h>

#define THIS_FILE "demo"

#define SIP_DOMAIN "hk.systec-pbx.net"
#define SIP_USER "00000000000001E3"
#define SIP_PASSWD "748964"

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    
    pjsua_call_get_info(call_id, &ci);
    
    PJ_LOG(3,(THIS_FILE, "Incoming call from %.*s!!", (int)ci.remote_info.slen, ci.remote_info.ptr));
    
    /* Automatically answer incoming calls with 200/OK */
    pjsua_call_answer(call_id, 200, NULL, NULL);
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [ViewController name: @"on_incoming_call" dir: @"huhu"];
    });
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(e);
    
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,(THIS_FILE, "Call %d state=%.*s", call_id, (int)ci.state_text.slen, ci.state_text.ptr));
    
//    char buf[512] = "";
//    sprintf(buf, "Call %d state=%.*s", (int)ci.state_text.slen, ci.state_text.ptr);
    NSString *hehe =[NSString stringWithFormat:@"%d %s", (int)ci.state_text.slen, ci.state_text.ptr];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [ViewController name: hehe dir: @"huhu"];
    });
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id) {
    pjsua_call_info ci;
    
    pjsua_call_get_info(call_id, &ci);
    
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

void demo_test(const char *path) {
    printf("demo_test %s\n", path);
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        printf("main main main\n");
        [ViewController name: @"hello+++++++++" dir: @"huhu"];
    });
}

void demo_test2(char *path) {
    printf("demo_test2 %s\n", path);
//    [ViewController name: @"hello+++++++++" dir: @"huhu"];
}

char *demo_test3(char *path) {
    printf("demo_test3 %s\n", path);
    const char *hehe = "12121212";
    return (char*)hehe;
}

int add_account(const char *domain, const char *user, const char *passwd) {
    pjsua_acc_id acc_id;
    pjsua_acc_config cfg;
    pjsua_acc_config_default(&cfg);
    char id[128] = "";
    sprintf(id, "sip:%s@%s", user, domain);
    cfg.id = pj_str(id);
    char uri[128] = "";
    sprintf(uri, "sip:%s", domain);
    cfg.reg_uri = pj_str(uri);
    cfg.cred_count = 1;
    cfg.cred_info[0].realm = pj_str("*");
    cfg.cred_info[0].scheme = pj_str("digest");
    cfg.cred_info[0].username = pj_str(user);
    cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    cfg.cred_info[0].data = pj_str(passwd);
    pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
    return 0;
}

void demo() {
    pjsua_acc_id acc_id;
    pj_status_t status;
    
    pjsua_create();
    
    pjsua_config ua_cfg;
    pjsua_logging_config log_cfg;
    pjsua_media_config media_cfg;
    
    pjsua_config_default(&ua_cfg);
    ua_cfg.cb.on_incoming_call = &on_incoming_call;
    ua_cfg.cb.on_call_media_state = &on_call_media_state;
    ua_cfg.cb.on_call_state = &on_call_state;
    
//    ua_cfg.cb.on
    
    pjsua_logging_config_default(&log_cfg);
    log_cfg.console_level = 3; /* better */
    pjsua_media_config_default(&media_cfg);
    
    pjsua_init(&ua_cfg, &log_cfg, &media_cfg);
    
    pjsua_transport_config transportConfig;
    
    pjsua_transport_config_default(&transportConfig);
    
    transportConfig.port = 5062;
    
    pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transportConfig, NULL);
    // pjsua_transport_create(PJSIP_TRANSPORT_TCP, &transportConfig, NULL);
    
    pjsua_start();
    
    pjsua_acc_config cfg;
    
#if 0
    pjsua_acc_config_default(&cfg);
    cfg.id = pj_str("sip:" SIP_USER "@" SIP_DOMAIN);
    cfg.reg_uri = pj_str("sip:" SIP_DOMAIN);
    cfg.cred_count = 1;
    cfg.cred_info[0].realm = pj_str("*");
    cfg.cred_info[0].scheme = pj_str("digest");
    cfg.cred_info[0].username = pj_str(SIP_USER);
    cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    cfg.cred_info[0].data = pj_str(SIP_PASSWD);
#else
    pjsua_acc_config_default(&cfg);
    //    cfg.id = pj_str("sip:" SIP_USER "@" SIP_DOMAIN);
    cfg.id = pj_str("sip:0@127.0.0.1");
    //    cfg.id = pj_str("sip:0@0.0.0.0");
    //    cfg.id = pj_str("sip:0@192.168.1.105");
    //    cfg.reg_uri = pj_str("sip:" SIP_DOMAIN);
    //    cfg.cred_count = 1;
    //    cfg.cred_info[0].realm = pj_str("*");
    //    cfg.cred_info[0].scheme = pj_str("digest");
    //    cfg.cred_info[0].username = pj_str(SIP_USER);
    //    cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    //    cfg.cred_info[0].data = pj_str(SIP_PASSWD);
#endif
    //
    status = pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
    //    if (status != PJ_SUCCESS) error_exit("Error adding account", status);
}

