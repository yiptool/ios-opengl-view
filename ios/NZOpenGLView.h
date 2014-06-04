/* vim: set ai noet ts=4 sw=4 tw=115: */
//
// Copyright (c) 2014 Nikolay Zapolnov (zapolnov@gmail.com).
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
#import <UIKit/UIKit.h>

@interface NZOpenGLView : UIView<UIGestureRecognizerDelegate>
{
	BOOL initializedGL;
	float scaleFactor;
	GLuint framebuffer;
	GLuint colorRenderbuffer;
	GLuint depthStencilRenderbuffer;
	CGSize renderbufferSize;
	CFTimeInterval prevTime;
	UIScreen * targetScreen;
}
@property (nonatomic, assign) UIScreen * targetScreen;
@property (nonatomic, assign, readonly) CADisplayLink * displayLink;
@property (nonatomic, assign, readonly) CAEAGLLayer * eaglLayer;
@property (nonatomic, retain, readonly) EAGLContext * eaglContext;
@property (nonatomic, assign, readonly) BOOL firstFrame;
-(id)init;
-(id)initWithTargetScreen:(UIScreen *)screen;
-(id)initWithFrame:(CGRect)frame;
-(id)initWithFrame:(CGRect)frame targetScreen:(UIScreen *)screen;
-(void)dealloc;
-(void)startRendering;
-(void)stopRendering;
// Override the following methods to configure OpenGL context
-(BOOL)fullResolution;
-(BOOL)eaglDrawablePropertyRetainedBacking;
-(NSString *)eaglColorFormat;
-(EAGLContext *)newEAGLContext;
-(int)depthBits;
-(int)stencilBits;
// Override the following methods to perform OpenGL rendering
-(void)initGL;
-(void)cleanupGL;
-(void)resizeGL:(CGSize)size;
-(void)renderWidth:(CGFloat)width height:(CGFloat)height time:(CFTimeInterval)timeDelta;
-(void)didRenderFirstFrame;
-(void)handleTap:(UIGestureRecognizer *)recognizer;
-(void)handlePan:(UIGestureRecognizer *)recognizer;
-(void)handlePinch:(UIPinchGestureRecognizer *)recognizer;
-(void)handleLongPress:(UILongPressGestureRecognizer *)recognizer;
@end
