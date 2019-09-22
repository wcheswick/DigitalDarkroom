//
//  CameraController.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraController : NSObject {
//    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
}


- (CGSize) cameraVideoSizeFor: (CGSize) s;
- (void) startCamera;
- (void) stopCamera;
- (NSString *) configureForCaptureWithCaller: (id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller
                                    portrait:(BOOL)portrait;
@end

NS_ASSUME_NONNULL_END
