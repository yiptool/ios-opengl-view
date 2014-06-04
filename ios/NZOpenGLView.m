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
#import <QuartzCore/QuartzCore.h>
#import <yip-imports/cxx-util/macros.h>
#import "NZOpenGLView.h"

@implementation NZOpenGLView

@synthesize displayLink;
@synthesize eaglLayer;
@synthesize eaglContext;
@synthesize firstFrame;

+(Class)layerClass
{
	return [CAEAGLLayer class];
}

-(id)init
{
	return [[super initWithFrame:CGRectZero] createOpenGLContext:nil];
}

-(id)initWithTargetScreen:(UIScreen *)screen
{
	return [[super initWithFrame:screen.applicationFrame] createOpenGLContext:screen];
}

-(id)initWithFrame:(CGRect)frame
{
	return [[super initWithFrame:frame] createOpenGLContext:nil];
}

-(id)initWithFrame:(CGRect)frame targetScreen:(UIScreen *)screen
{
	return [[super initWithFrame:frame] createOpenGLContext:screen];
}

-(id)createOpenGLContext:(UIScreen *)screen
{
	firstFrame = YES;

	scaleFactor = 1.0f;
	if ([self fullResolution] && [self respondsToSelector:@selector(contentScaleFactor)])
	{
		scaleFactor = [[UIScreen mainScreen] scale];
		self.contentScaleFactor = scaleFactor;
	}

	eaglLayer = (CAEAGLLayer *)self.layer;
	eaglLayer.opaque = YES;
	eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:[self eaglDrawablePropertyRetainedBacking]], kEAGLDrawablePropertyRetainedBacking,
		[self eaglColorFormat], kEAGLDrawablePropertyColorFormat,
		nil
	];

	eaglContext = [self newEAGLContext];
	if (!eaglContext)
		NSLog(@"Unable to create OpenGL context.");

	if (![EAGLContext setCurrentContext:eaglContext])
		NSLog(@"Unable to make OpenGL context current.");

	targetScreen = screen;
	[self startRendering];

	UITapGestureRecognizer * tapGestureRecognizer = [[[UITapGestureRecognizer alloc]
		initWithTarget:self action:@selector(handleTap:)] autorelease];
	[tapGestureRecognizer setNumberOfTapsRequired:1];
	[tapGestureRecognizer setNumberOfTouchesRequired:1];
	[self addGestureRecognizer:tapGestureRecognizer];

	UIPanGestureRecognizer * panGestureRecognizer = [[[UIPanGestureRecognizer alloc]
		initWithTarget:self action:@selector(handlePan:)] autorelease];
	[self addGestureRecognizer:panGestureRecognizer];

	UIPinchGestureRecognizer * pinchGestureRecognizer = [[[UIPinchGestureRecognizer alloc]
		initWithTarget:self action:@selector(handlePinch:)] autorelease];
	[self addGestureRecognizer:pinchGestureRecognizer];

	UILongPressGestureRecognizer * longPressGestureRecognizer = [[[UILongPressGestureRecognizer alloc]
		initWithTarget:self action:@selector(handleLongPress:)] autorelease];
	[self addGestureRecognizer:longPressGestureRecognizer];

	self.userInteractionEnabled = YES;

	return self;
}

-(void)dealloc
{
	if (initializedGL)
	{
		if ([EAGLContext setCurrentContext:eaglContext])
			[self cleanupGL];
		initializedGL = NO;
	}

	[EAGLContext setCurrentContext:nil];

	[eaglContext release];
	eaglContext = nil;

	[super dealloc];
}

-(UIScreen *)targetScreen
{
	return targetScreen;
}

-(void)setTargetScreen:(UIScreen *)screen
{
	if (targetScreen != screen)
	{
		[self stopRendering];
		targetScreen = screen;
		[self startRendering];
	}
}

-(BOOL)fullResolution
{
	return YES;
}

-(BOOL)eaglDrawablePropertyRetainedBacking
{
	return NO;
}

-(NSString *)eaglColorFormat
{
	return kEAGLColorFormatRGB565;
}

-(EAGLContext *)newEAGLContext
{
	EAGLContext * context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
	if (!context)
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	return context;
}

-(int)depthBits
{
	return 16;
}

-(int)stencilBits
{
	return 0;
}

-(void)startRendering
{
	if (targetScreen)
		displayLink = [targetScreen displayLinkWithTarget:self selector:@selector(render:)];
	else
		displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
	[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

-(void)stopRendering
{
	[displayLink invalidate];
	displayLink = nil;
}

-(void)createFramebuffer:(CGSize)size
{
	int width = (int)size.width;
	int height = (int)size.height;

	NSLog(@"Creating framebuffer with size %dx%d.", width, height);

	glGenFramebuffers(1, &framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

	glGenRenderbuffers(1, &colorRenderbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
	[eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, 0);

	if ([self depthBits] > 0 || [self stencilBits] > 0)
	{
		glGenRenderbuffers(1, &depthStencilRenderbuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, depthStencilRenderbuffer);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, width, height);
		if ([self depthBits] > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthStencilRenderbuffer);
		if ([self stencilBits] > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthStencilRenderbuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, 0);
	}

	renderbufferSize = size;
}

-(void)destroyFramebuffer
{
	if (framebuffer)
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glDeleteFramebuffers(1, &framebuffer);
		framebuffer = 0;
	}

	if (colorRenderbuffer)
	{
		glBindRenderbuffer(GL_RENDERBUFFER, 0);
		glDeleteRenderbuffers(1, &colorRenderbuffer);
		colorRenderbuffer = 0;
	}

	if (depthStencilRenderbuffer)
	{
		glBindRenderbuffer(GL_RENDERBUFFER, 0);
		glDeleteRenderbuffers(1, &depthStencilRenderbuffer);
		depthStencilRenderbuffer = 0;
	}
}

-(void)render:(CADisplayLink *)dispLink
{
	[EAGLContext setCurrentContext:eaglContext];

	// Update time counters

	CFTimeInterval curTime = dispLink.timestamp;
	CFTimeInterval timeDelta;
	if (LIKELY(!firstFrame))
		timeDelta = curTime - prevTime;
	else
		timeDelta = 0;
	prevTime = curTime;

	if (UNLIKELY(timeDelta < 0.0))
		timeDelta = 0.0;
	else if (UNLIKELY(timeDelta > 1.0f / 24.0f))
		timeDelta = 1.0f / 24.0f;

	// Initialize OpenGL

	if (UNLIKELY(firstFrame))
	{
			[self initGL];
		initializedGL = YES;
	}

	// Adjust for viewport size

	CGSize size = self.bounds.size;
	size.width *= scaleFactor;
	size.height *= scaleFactor;

	if (UNLIKELY(!framebuffer || !colorRenderbuffer ||
		size.width != renderbufferSize.width || size.height != renderbufferSize.height))
	{
		[self destroyFramebuffer];
		[self createFramebuffer:size];
		[self resizeGL:size];
	}

	// Render a frame

	[self renderWidth:size.width height:size.height time:timeDelta];

	// Present framebuffer to the screen

	glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
	[eaglContext presentRenderbuffer:GL_RENDERBUFFER];

	// Dismiss splash if it is still displayed

	if (UNLIKELY(firstFrame))
	{
		firstFrame = NO;
		[self didRenderFirstFrame];
	}
}

-(void)initGL
{
	glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
}

-(void)cleanupGL
{
}

-(void)resizeGL:(CGSize)size
{
}

-(void)renderWidth:(CGFloat)width height:(CGFloat)height time:(CFTimeInterval)timeDelta
{
	glViewport(0, 0, (GLsizei)width, (GLsizei)height);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

-(void)didRenderFirstFrame
{
}

-(void)handleTap:(UIGestureRecognizer *)recognizer
{
}

-(void)handlePan:(UIGestureRecognizer *)recognizer
{
}

-(void)handlePinch:(UIPinchGestureRecognizer *)recognizer
{
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
}

@end
