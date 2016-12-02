package openfl._internal.renderer; #if (!display && !flash)


import lime.graphics.CairoRenderContext;
import lime.graphics.CanvasRenderContext;
import lime.graphics.DOMRenderContext;
import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLFramebuffer;
//import openfl._internal.renderer.opengl.utils.BlendModeManager;
//import openfl._internal.renderer.opengl.utils.FilterManager;
//import openfl._internal.renderer.opengl.utils.ShaderManager;
//import openfl._internal.renderer.opengl.utils.SpriteBatch;
//import openfl._internal.renderer.opengl.utils.StencilManager;
import openfl._internal.renderer.cairo.CairoGraphics;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BitmapDataChannel;
import openfl.display.Sprite;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)


class RenderSession {
	
	private static var IDENTITY:Matrix = new Matrix();
	
	public var allowSmoothing:Bool;
	public var cairo:CairoRenderContext;
	public var context:CanvasRenderContext;
	public var element:DOMRenderContext;
	public var gl:GLRenderContext;
	public var renderer:AbstractRenderer;
	public var roundPixels:Bool;
	public var transformProperty:String;
	public var transformOriginProperty:String;
	public var upscaled:Bool;
	public var vendorPrefix:String;
	public var z:Int;
	public var projectionMatrix:Matrix;
	
	public var drawCount:Int;
	public var currentBlendMode:BlendMode;
	public var activeTextures:Int = 0;
	
	//public var shaderManager:ShaderManager;
	public var blendModeManager:AbstractBlendModeManager;
	public var filterManager:AbstractFilterManager;
	public var maskManager:AbstractMaskManager;
	public var shaderManager:AbstractShaderManager;
	//public var filterManager:FilterManager;
	//public var blendModeManager:BlendModeManager;
	//public var spriteBatch:SpriteBatch;
	//public var stencilManager:StencilManager;
	//public var defaultFramebuffer:GLFramebuffer;

	private var minBounds:Point;
	private var maxBounds:Point;
	
	
	public function new () {
		
		allowSmoothing = true;
		//maskManager = new MaskManager (this);
		
	}
	

	private var done:Bool = false;
	private var stop:Bool = false;
	public function updateCachedBitmap( shape:DisplayObject ) {

		var dirty = (shape.__cachedShapeBounds == null) || hierarchyDirty( shape );

		if (!done)
			trace("CachedBitmaps:"+shape.name+" type:"+Type.getClassName(Type.getClass( shape )));

		if (dirty) {

			shape.__cacheAsBitmapMatrix = null;
			shape.__updateTransforms();
			shape.__minCacheAsBitmapBounds = new Point( Math.POSITIVE_INFINITY,  Math.POSITIVE_INFINITY );
			shape.__maxCacheAsBitmapBounds = new Point( Math.NEGATIVE_INFINITY,  Math.NEGATIVE_INFINITY );

			getCachedBitmapBounds( shape, shape );

			var bounds =  new Rectangle();
			bounds.x = shape.__minCacheAsBitmapBounds.x;
			bounds.y = shape.__minCacheAsBitmapBounds.y;
			bounds.width = shape.__maxCacheAsBitmapBounds.x - shape.__minCacheAsBitmapBounds.x;
			bounds.height = shape.__maxCacheAsBitmapBounds.y - shape.__minCacheAsBitmapBounds.y;

			var offset = new Point( bounds.x, bounds.y );
			if (shape.__cachedShapeBounds == null) {
				trace("THIS IS NULL");
				var aa = 1;
				aa++;
			}
			offset.x -= shape.__cachedShapeBounds.x;
			offset.y -= shape.__cachedShapeBounds.y;

			if (!done) {
				trace("MAXBOUNDS:"+bounds);
				trace(" - offset:"+offset);
			}

			offsetCachedBitmapBounds( shape, offset );

			shape.__cachedBitmap = new BitmapData( Std.int(bounds.width), Std.int(bounds.height), true, 0x0 );

			flatten( shape, shape.__cachedBitmap );
			
			if (!done) {
				// Test1.ADD( shape.__cachedBitmap );
				done = true;
				stop = true;
			}
			ctr++;
		}
	}


	private function hierarchyDirty( shape:DisplayObject ):Bool {
		
		if (Std.is(shape, DisplayObjectContainer)) {
			var cont:DisplayObjectContainer = cast shape;
			for (i in 0...cont.numChildren) {
				if (hierarchyDirty( cont.getChildAt( i ) )) 
					return true;
			}
		}

		if (!done)
			trace("  - shape:"+shape.name+" mask:"+shape.__mask+" scrollRect:"+shape.__scrollRect);

		if (!done && shape.__mask != null) {
			com.geepers.DebugUtils.debugSprite( cast shape.__mask );
			var a = 1;
			a++;
		}

		if (shape.__filterDirty) {
			shape.__filterDirty = false;
			return true;
		}

		if (shape.__transformDirty) {
			shape.__transformDirty = false;
			return true;
		}

		if (shape.__renderDirty) {
			shape.__renderDirty = false;
			return true;
		}

		if (shape.__graphics != null && shape.__graphics.__dirty) {
			shape.__graphics.__dirty = false;
			return true;
		}

		var bitmap:Bitmap = cast shape;
		if (bitmap == null || !bitmap.__renderable || bitmap.__worldAlpha <= 0 || bitmap.bitmapData == null) 
			return false;

		if (bitmap.bitmapData != null && bitmap.bitmapData.image.dirty) {
			bitmap.bitmapData.image.dirty = false;
			return true;
		}

		return false;
	}

	private function getCachedBitmapBounds (shape:DisplayObject, cacheAsBitmapShape:DisplayObject, point:Point = null ) {

		var graphics = shape.__graphics;
		
		if (graphics!=null) {
			
			var textField:TextField = cast shape;
			if ( textField != null && textField.__dirty && !done) {
				trace("About to update TextField:"+shape.name);
				cast( shape, TextField ).__renderGL( this );
			}

			// CanvasGraphics.render (graphics, this, null, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#if (js && html5)
			CanvasGraphics.render (graphics, this, null, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#elseif lime_cairo
			CairoGraphics.render (graphics, this, null, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#end
			
			if (graphics.__bitmap != null) {

				shape.__cacheAsBitmapMatrix = shape.__graphics.__worldTransform.clone();

				if (point == null)
					point = new Point( shape.__graphics.__worldTransform.tx,  shape.__graphics.__worldTransform.ty );
				
				if (!stop) {
					trace("Setting CAB:"+shape.name+" - "+shape.__cacheAsBitmapMatrix);
					trace(" - point:"+point);
				}
				shape.__cacheAsBitmapMatrix.tx -= point.x;
				shape.__cacheAsBitmapMatrix.ty -= point.y;
				
				if (!stop) {
					trace(" - new TX:"+shape.__cacheAsBitmapMatrix.tx+"/"+shape.__cacheAsBitmapMatrix.ty);
					
					// var b = graphics.__bitmap;
					// b.fillRect( new Rectangle( 0,0,10,10), 0xffff0000);
					// b.fillRect( new Rectangle( 0,0,b.width,b.height), 0x1000ff00);
					trace("getCachedBitmapBounds:name="+shape.name);
					trace(" - wt:"+shape.__worldTransform);
					trace(" - rt:"+shape.__renderTransform);
					trace(" - t:"+shape.__transform);
					trace(" - gwt:"+shape.__graphics.__worldTransform);
					trace(" - grt:"+shape.__graphics.__renderTransform);
					trace(" - CABM:"+shape.__cacheAsBitmapMatrix);
					var a = 1;
					a++;
				}
					
				updateBoundsRectangle( shape, graphics.__bitmap, cacheAsBitmapShape, point );

			}
		}

		if (point == null) {
			point = new Point( shape.__worldTransform.tx,  shape.__worldTransform.ty );

			if (cacheAsBitmapShape.__cachedShapeBounds == null) {
				cacheAsBitmapShape.__cachedShapeBounds = new Rectangle( point.x, point.y, 0, 0 );
			}

			if (!stop) {
				trace("Setting CAB - was NULL after graphics:"+shape.name+" - "+shape.__cacheAsBitmapMatrix);
				trace(" - point:"+point);
			}
		}

		var bitmap:Bitmap = cast shape;
		if (Std.is( shape, Bitmap )) {

			var bitmap:Bitmap = cast shape;
			if (bitmap != null && (bitmap.__renderable || bitmap.__worldAlpha > 0) && bitmap.bitmapData != null) {

				bitmap.__cacheAsBitmapMatrix = bitmap.__worldTransform.clone();
				bitmap.__cacheAsBitmapMatrix.tx -= point.x;
				bitmap.__cacheAsBitmapMatrix.ty -= point.y;

				if (!stop) 
					trace(" - new TX:"+shape.__cacheAsBitmapMatrix.tx+"/"+shape.__cacheAsBitmapMatrix.ty);

				updateBoundsRectangle( bitmap, bitmap.bitmapData, cacheAsBitmapShape, point );
			}
		}

		if ( shape.__cacheAsBitmapMatrix == null ) {
			shape.__cacheAsBitmapMatrix = shape.__worldTransform.clone();
			// shape.__cacheAsBitmapMatrix.tx = shape.__cacheAsBitmapMatrix.ty = 0;
			shape.__cacheAsBitmapMatrix.tx -= point.x;
			shape.__cacheAsBitmapMatrix.ty -= point.y;
		}

		// if (bitmap != null && (bitmap.__renderable || bitmap.__worldAlpha > 0) && bitmap.bitmapData != null) {
		// 	if (!done) {
		// 		trace("   - using bitmap:"+bitmap.bitmapData.width+"/"+bitmap.bitmapData.height);
		// 	}

		// 	updateBoundsRectangle( bitmap, bitmap.bitmapData, cacheAsBitmapShape, point );
		// }
		
		if (Std.is(shape, DisplayObjectContainer)) {
			var cont:DisplayObjectContainer = cast shape;
			for (i in 0...cont.numChildren) {

				var child = cont.getChildAt( i );

				getCachedBitmapBounds( child, cacheAsBitmapShape, point );
			}
		}
				

	}

	var objCtr:Int = 0;
	private function updateBoundsRectangle( shape:DisplayObject, bmd:BitmapData, cacheAsBitmapShape:DisplayObject, point:Point ) {

		var transform = shape.__graphics != null ? shape.__graphics.__worldTransform : shape.__worldTransform;
		var topLeft = transform.transformPoint( new Point( 0, 0 ) );
		var topRight = transform.transformPoint( new Point( bmd.width, 0 ) );
		var bottomLeft = transform.transformPoint( new Point( 0, bmd.height ) );
		var bottomRight = transform.transformPoint( new Point( bmd.width,  bmd.height ) );
		
		var top = Math.min( topLeft.y,  Math.min( topRight.y,  Math.min( bottomLeft.y, bottomRight.y ) ) );
		var bottom = Math.max( topLeft.y,  Math.max( topRight.y,  Math.max( bottomLeft.y, bottomRight.y ) ) );
		var left = Math.min( topLeft.x,  Math.min( topRight.x,  Math.min( bottomLeft.x, bottomRight.x ) ) );
		var right = Math.max( topLeft.x,  Math.max( topRight.x,  Math.max( bottomLeft.x, bottomRight.x ) ) );

		shape.__cachedShapeBounds = new Rectangle( topLeft.x, topLeft.y, right - left, bottom - top );
		
		cacheAsBitmapShape.__minCacheAsBitmapBounds.x = Math.min( cacheAsBitmapShape.__minCacheAsBitmapBounds.x, left);
		cacheAsBitmapShape.__minCacheAsBitmapBounds.y = Math.min( cacheAsBitmapShape.__minCacheAsBitmapBounds.y, top);
		cacheAsBitmapShape.__maxCacheAsBitmapBounds.x = Math.max( cacheAsBitmapShape.__maxCacheAsBitmapBounds.x, right);
		cacheAsBitmapShape.__maxCacheAsBitmapBounds.y = Math.max( cacheAsBitmapShape.__maxCacheAsBitmapBounds.y, bottom);

		if (!done) {
			var colA:Array<UInt> = [ 0x0, 0x880000, 0x00aa00, 0x0000aa, 0x880088, 0x888800, 0x008888 ];
			var c = colA[ objCtr++ ];
			Test1.DRAW( topLeft, topRight, c );
			Test1.DRAW( topRight, bottomRight, c );
			Test1.DRAW( bottomRight, bottomLeft, c );
			Test1.DRAW( bottomLeft, topLeft, c );

			trace(" - updateBoundsRectangle:");
			trace("   - shape:"+shape.name);
			trace("   - cab:"+shape.__cacheAsBitmapMatrix);
			trace("   - bitmap:"+bmd.width+"/"+bmd.height);
			trace("   - topL/R:"+topLeft+"/"+topRight+" bottomL/R:"+bottomLeft+"/"+bottomRight);
			trace("   - cachedShapeBounds:"+shape.__cachedShapeBounds);
			trace("   - minCABBounds:"+cacheAsBitmapShape.__minCacheAsBitmapBounds);
			trace("   - maxCABBounds:"+cacheAsBitmapShape.__maxCacheAsBitmapBounds);
		}
	}

	private function offsetCachedBitmapBounds (shape:DisplayObject, boundsOffset:Point ) {

		if (!stop) {
			trace("offsetCachedBitmapBounds:"+shape.name);
			trace(" - cachedShapeBounds:"+shape.__cachedShapeBounds);
			trace(" - boundsOffset:"+boundsOffset);
		}

		shape.__cacheAsBitmapMatrix.tx += -boundsOffset.x;	
		shape.__cacheAsBitmapMatrix.ty += -boundsOffset.y;
	
		if (!stop)
			trace(" - new :"+shape.__cacheAsBitmapMatrix.tx+"/"+shape.__cacheAsBitmapMatrix.ty);
		
		if (Std.is(shape, DisplayObjectContainer)) {
			
			var cont:DisplayObjectContainer = cast shape;
			for (i in 0...cont.numChildren) {

				var child = cont.getChildAt( i );

				offsetCachedBitmapBounds( child, boundsOffset );

			}

		}
	
	}


	private static var ctr:Int = 0;
	private static var ctr2:Int = 0;
	private function flatten (shape:DisplayObject, bmd:BitmapData  ) {

		if (!shape.__renderable || !shape.__visible || shape.__worldAlpha <= 0) return;

		if (!done) {
			trace("flatten:"+shape.name);
			trace(" - cabm:"+shape.__cacheAsBitmapMatrix);
			trace(" - cachedShapeBounds:"+shape.__cachedShapeBounds);
		}	
		var graphics = shape.__graphics;
		if (graphics!=null) {
			CanvasGraphics.render (graphics, this, null, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			
			if (graphics.__bitmap!=null) {
				// var b = graphics.__bitmap;
				// b.fillRect( new Rectangle( 0,0,10,10), 0xffff0000);
				// b.fillRect( new Rectangle( 0,0,b.width,b.height), 0x1000ff00);

				bmd.draw( graphics.__bitmap, shape.__cacheAsBitmapMatrix, null, null, null, true );

				if (shape.__mask != null) {
					if (!done)
						trace("Attempting to draw the alpha channel as a mask over the bitmap");
					var maskBitmap = new BitmapData( bmd.width, bmd.height, true, 0x0 );
					maskBitmap.draw( shape.__mask.__graphics.__bitmap,  shape.__mask.__cacheAsBitmapMatrix, null, null, null, true );
					bmd.copyChannel( maskBitmap, maskBitmap.rect, new Point(), BitmapDataChannel.ALPHA, BitmapDataChannel.ALPHA );
					// bmd.draw( shape.__mask.__graphics.__bitmap,  shape.__mask.__cacheAsBitmapMatrix, null, null, null, true );
				}
			}
		}

		var bitmap:Bitmap = cast shape;
		if (bitmap != null && (bitmap.__renderable || bitmap.__worldAlpha > 0) && bitmap.bitmapData != null) {
			bmd.draw( bitmap.bitmapData, shape.__cacheAsBitmapMatrix, null, null, null, true );
		}
				
		if (Std.is(shape, DisplayObjectContainer)) {
			var cont:DisplayObjectContainer = cast shape;
			for (i in 0...cont.numChildren) {
				flatten( cont.getChildAt( i ), bmd );
			}
		}

	}	
	
}


#end