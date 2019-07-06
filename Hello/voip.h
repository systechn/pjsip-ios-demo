//
//  demo.h
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

#ifndef voip_h
#define voip_h

void voip_start(unsigned port);

int voip_account_update(const char *domain, const char *user, const char *passwd);
int voip_account_unregister();

void voip_hangup();
void voip_answer();
void voip_call(const char *uri);

#endif /* demo_h */
