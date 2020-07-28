//
//  NabtoEdgeClientObjCTest.m
//  NabtoEdgeClientTests
//
//  Created by Ulrik Gammelby on 28/07/2020.
//  Copyright © 2020 Nabto. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <NabtoEdgeClient/NabtoEdgeClient.h>

#import "NabtoEdgeClient.h"

@interface NabtoEdgeClientObjCTest : XCTestCase

@end

@implementation NabtoEdgeClientObjCTest {
    NabtoEdgeClientObjC* sut;
}

- (void)setUp {
    sut = [[NabtoEdgeClientObjC alloc] init];
}

- (void)tearDown {
}

- (void)testVersionObjC {
    XCTAssertTrue([[sut objc_nabto_client_version] hasPrefix:@"5."]);
}

@end
