//
// Created by Ulrik Gammelby on 28/07/2020.
// Copyright (c) 2020 Nabto. All rights reserved.
//

#import "NabtoEdgeClientObjC.h"
#import "NabtoEdgeClientApi/nabto_client.h"

@implementation NabtoEdgeClientObjC {
}

- (NSString*)objc_nabto_client_version {
    return [NSString stringWithCString:nabto_client_version() encoding:NSUTF8StringEncoding];
}


@end