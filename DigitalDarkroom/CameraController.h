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


- (void) startCamera:(NSString *_Nullable* _Nullable)errStr
              detail:(NSString *_Nullable* _Nullable)detailStr
              caller:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)caller;
- (CGSize) cameraVideoSizeFor: (CGSize) s;
- (void) stopCamera;

@end

NS_ASSUME_NONNULL_END
