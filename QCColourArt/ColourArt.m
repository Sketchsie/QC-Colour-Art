//
//  ColourArt.m
//  QCColourArt
//
//  Created by Jonathan Hammond on 09/04/2013.
//  Copyright (c) 2013 Jonathan Hammond. All rights reserved.
//

#import "ColourArt.h"
#import "NSImage+bitmapRep.h"
@implementation ColourArt


-(void)setImage:(NSImage *)image
{
    [self analizeImage:image];
}



- (void)analizeImage:(NSImage*)anImage
{
	NSCountedSet *imageColors = nil;
	NSColor *backgroundColor = [self findEdgeColor:anImage imageColors:&imageColors];
	NSColor *primaryColor = nil;
	NSColor *secondaryColor = nil;
	NSColor *detailColor = nil;
	BOOL darkBackground = [backgroundColor pc_isDarkColor];
	
	[self findTextColors:imageColors primaryColor:&primaryColor secondaryColor:&secondaryColor detailColor:&detailColor backgroundColor:backgroundColor];
	
	if ( primaryColor == nil )
	{
		NSLog(@"missed primary");
		if ( darkBackground )
			primaryColor = [NSColor whiteColor];
		else
			primaryColor = [NSColor blackColor];
	}
	
	if ( secondaryColor == nil )
	{
		NSLog(@"missed secondary");
		if ( darkBackground )
			secondaryColor = [NSColor whiteColor];
		else
			secondaryColor = [NSColor blackColor];
	}
	
	if ( detailColor == nil )
	{
		NSLog(@"missed detail");
		if ( darkBackground )
			detailColor = [NSColor whiteColor];
		else
			detailColor = [NSColor blackColor];
	}
	
    if ( backgroundColor == nil )
	{
		NSLog(@"missed background");
		if ( darkBackground )
			backgroundColor = [NSColor whiteColor];
		else
			backgroundColor = [NSColor blackColor];
	}
    
    //now set properties
    _primaryColor = [self colorWithFullAlpha:primaryColor];
    _secondaryColor = [self colorWithFullAlpha:secondaryColor];
    _detailColor = [self colorWithFullAlpha:detailColor];
    _backgroundColor = [self colorWithFullAlpha:backgroundColor];
    
//	

}

-(NSColor*)colorWithFullAlpha:(NSColor*)colour
{
    NSLog(@"%@",colour);
    return colour;//[NSColor colorWithSRGBRed:colour.redComponent green:colour.greenComponent blue:colour.blueComponent alpha:1];
}


- (NSColor*)findEdgeColor:(NSImage*)image imageColors:(NSCountedSet**)colors
{
    NSArray* reps = [image representations];
	NSBitmapImageRep *imageRep = [reps lastObject];
	
	if ( ![imageRep isKindOfClass:[NSBitmapImageRep class]] ) // sanity check
    {
        imageRep = [image bitmapImageRepresentation];
    }
	
	NSInteger pixelsWide = [imageRep pixelsWide];
	NSInteger pixelsHigh = [imageRep pixelsHigh];
    
	NSCountedSet *imageColors = [[NSCountedSet alloc] initWithCapacity:pixelsWide * pixelsHigh];
	NSCountedSet *leftEdgeColors = [[NSCountedSet alloc] initWithCapacity:pixelsHigh];
    
	for ( NSUInteger x = 0; x < pixelsWide; x++ )
	{
		for ( NSUInteger y = 0; y < pixelsHigh; y++ )
		{
			NSColor *color = [imageRep colorAtX:x y:y];
            
			if ( x == 0 )
			{
				[leftEdgeColors addObject:color];
			}
			
			[imageColors addObject:color];
		}
	}
    
	*colors = imageColors;
    
    
	NSEnumerator *enumerator = [leftEdgeColors objectEnumerator];
	NSColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[leftEdgeColors count]];
    
	while ( (curColor = [enumerator nextObject]) != nil )
	{
		NSUInteger colorCount = [leftEdgeColors countForObject:curColor];
        
		if ( colorCount <= 2 ) // prevent using random colors, threshold should be based on input image size
			continue;
		
		PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];
		
		[sortedColors addObject:container];
			}
    
	[sortedColors sortUsingSelector:@selector(compare:)];
	
    
	PCCountedColor *proposedEdgeColor = nil;
	
	if ( [sortedColors count] > 0 )
	{
		proposedEdgeColor = [sortedColors objectAtIndex:0];
        
		if ( [proposedEdgeColor.color pc_isBlackOrWhite] ) // want to choose color over black/white so we keep looking
		{
			for ( NSInteger i = 1; i < [sortedColors count]; i++ )
			{
				PCCountedColor *nextProposedColor = [sortedColors objectAtIndex:i];
				
				if (((double)nextProposedColor.count / (double)proposedEdgeColor.count) > .3 ) // make sure the second choice color is 30% as common as the first choice
				{
					if ( ![nextProposedColor.color pc_isBlackOrWhite] )
					{
						proposedEdgeColor = nextProposedColor;
						break;
					}
				}
				else
				{
					// reached color threshold less than 30% of the original proposed edge color so bail
					break;
				}
			}
		}
	}
	
	return proposedEdgeColor.color;
}


- (void)findTextColors:(NSCountedSet*)colors primaryColor:(NSColor**)primaryColor secondaryColor:(NSColor**)secondaryColor detailColor:(NSColor**)detailColor backgroundColor:(NSColor*)backgroundColor
{
	NSEnumerator *enumerator = [colors objectEnumerator];
	NSColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[colors count]];
	BOOL findDarkTextColor = ![backgroundColor pc_isDarkColor];
	
	while ( (curColor = [enumerator nextObject]) != nil )
	{
		curColor = [curColor pc_colorWithMinimumSaturation:.15]; // make sure color isn't too pale or washed out
        
		if ( [curColor pc_isDarkColor] == findDarkTextColor )
		{
			NSUInteger colorCount = [colors countForObject:curColor];
			
			//if ( colorCount <= 2 ) // prevent using random colors, threshold should be based on input image size
			//	continue;
			
			PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];
			
			[sortedColors addObject:container];
			
		}
	}
	
	[sortedColors sortUsingSelector:@selector(compare:)];
	
	for ( PCCountedColor *curContainer in sortedColors )
	{
		curColor = curContainer.color;
        
		if ( *primaryColor == nil )
		{
			if ( [curColor pc_isContrastingColor:backgroundColor] )
				*primaryColor = curColor;
		}
		else if ( *secondaryColor == nil )
		{
			if ( ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;
            
			*secondaryColor = curColor;
		}
		else if ( *detailColor == nil )
		{
			if ( ![*secondaryColor pc_isDistinct:curColor] || ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;
            
			*detailColor = curColor;
			break;
		}
	}
}


@end


@implementation NSColor (DarkAddition)

- (BOOL)pc_isDarkColor
{
	NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat r, g, b, a;
    
	[convertedColor getRed:&r green:&g blue:&b alpha:&a];
	
	CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    
	if ( lum < .5 )
	{
		return YES;
	}
	
	return NO;
}


- (BOOL)pc_isDistinct:(NSColor*)compareColor
{
	NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *convertedCompareColor = [compareColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat r, g, b, a;
	CGFloat r1, g1, b1, a1;
    
	[convertedColor getRed:&r green:&g blue:&b alpha:&a];
	[convertedCompareColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    
	CGFloat threshold = .25; //.15
    
	if ( fabs(r - r1) > threshold ||
		fabs(g - g1) > threshold ||
		fabs(b - b1) > threshold ||
		fabs(a - a1) > threshold )
    {
        // check for grays, prevent multiple gray colors
        
        if ( fabs(r - g) < .03 && fabs(r - b) < .03 )
        {
            if ( fabs(r1 - g1) < .03 && fabs(r1 - b1) < .03 )
                return NO;
        }
        
        return YES;
    }
    
	return NO;
}


- (NSColor*)pc_colorWithMinimumSaturation:(CGFloat)minSaturation
{
	NSColor *tempColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if ( tempColor != nil )
	{
		CGFloat hue = 0.0;
		CGFloat saturation = 0.0;
		CGFloat brightness = 0.0;
		CGFloat alpha = 0.0;
        
		[tempColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
		
		if ( saturation < minSaturation )
		{
			return [NSColor colorWithCalibratedHue:hue saturation:minSaturation brightness:brightness alpha:alpha];
		}
	}
	
	return self;
}


- (BOOL)pc_isBlackOrWhite
{
	NSColor *tempColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if ( tempColor != nil )
	{
		CGFloat r, g, b, a;
        
		[tempColor getRed:&r green:&g blue:&b alpha:&a];
		
		if ( r > .91 && g > .91 && b > .91 )
			return YES; // white
        
		if ( r < .09 && g < .09 && b < .09 )
			return YES; // black
	}
	
	return NO;
}


- (BOOL)pc_isContrastingColor:(NSColor*)color
{
	NSColor *backgroundColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *foregroundColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if ( backgroundColor != nil && foregroundColor != nil )
	{
		CGFloat br, bg, bb, ba;
		CGFloat fr, fg, fb, fa;
		
		[backgroundColor getRed:&br green:&bg blue:&bb alpha:&ba];
		[foregroundColor getRed:&fr green:&fg blue:&fb alpha:&fa];
        
		CGFloat bLum = 0.2126 * br + 0.7152 * bg + 0.0722 * bb;
		CGFloat fLum = 0.2126 * fr + 0.7152 * fg + 0.0722 * fb;
        
		CGFloat contrast = 0.;
		
		if ( bLum > fLum )
			contrast = (bLum + 0.05) / (fLum + 0.05);
		else
			contrast = (fLum + 0.05) / (bLum + 0.05);
        
		//return contrast > 3.0; //3-4.5 W3C recommends a minimum ratio of 3:1
		return contrast > 1.6;
	}
	
	return YES;
}


@end


@implementation PCCountedColor

- (id)initWithColor:(NSColor*)color count:(NSUInteger)count
{
	self = [super init];
	
	if ( self )
	{
		self.color = color;
		self.count = count;
	}
	
	return self;
}

- (void)dealloc
{

}


- (NSComparisonResult)compare:(PCCountedColor*)object
{
	if ( [object isKindOfClass:[PCCountedColor class]] )
	{
		if ( self.count < object.count )
		{
			return NSOrderedDescending;
		}
		else if ( self.count == object.count )
		{
			return NSOrderedSame;
		}
	}
    
	return NSOrderedAscending;
}


@end
