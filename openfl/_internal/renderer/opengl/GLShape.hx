package openfl._internal.renderer.opengl;


import openfl.geom.Point;
import openfl.geom.Rectangle;
import lime.utils.Float32Array;
import openfl._internal.renderer.cairo.CairoGraphics;
import openfl._internal.renderer.cairo.CairoRenderer;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.renderer.canvas.CanvasRenderer;
import openfl._internal.renderer.RenderSession;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.filters.ShaderFilter;
import openfl.geom.Matrix;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.display.DisplayObject)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Graphics)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.Matrix)


class GLShape {
	
	private static var ctr:Int = 0;
	public static var DEBUG:Bool = false;
	public static inline function render (shape:DisplayObject, renderSession:RenderSession):Void {
		
		if (!shape.__renderable || shape.__worldAlpha <= 0 || shape.__renderedAsCachedBitmap) return;
		
		var graphics = shape.__graphics;

		var mask:DisplayObject;
		var maskGraphics:Graphics = null;
		var gl = renderSession.gl;

		// Render mask
		if (shape.mask != null) {
			mask = shape.__mask;
			maskGraphics = shape.__mask.__graphics;
			
			#if (js && html5)
			CanvasGraphics.render (maskGraphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#elseif lime_cairo
			CairoGraphics.render (maskGraphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#end
		}

		if (graphics != null) {
			
			#if (js && html5)
			CanvasGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#elseif lime_cairo
			CairoGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#end
		
			if (graphics.__bitmap != null && graphics.__visible) {
				
				var renderer:GLRenderer = cast renderSession.renderer;
				var gl = renderSession.gl;
				
				var shader;
				
				if (shape.mask != null || shape.parent.__renderedMask != null) {

					shader = renderSession.shaderManager.defaultMaskingShader;
					
				} else {
					
					shader = renderSession.filterManager.pushObject (shape);
					
					shader.data.uImage0.input = graphics.__bitmap;
					shader.data.uImage0.smoothing = renderSession.allowSmoothing;
					shader.data.uMatrix.value = renderer.getMatrix (graphics.__worldTransform);
					
				}
				
				renderSession.blendModeManager.setBlendMode (shape.blendMode);
				//renderSession.maskManager.pushObject (shape);
				
				renderSession.shaderManager.setShader (shader);

				if (renderSession.allowSmoothing) {
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
					
				} else {
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
					
				}
							
				if (shape.mask != null || shape.parent.__renderedMask != null) {
					
					var maskBitmap:BitmapData = null;
					if (shape.parent.__renderedMask != null) {
						maskBitmap = shape.__renderedMask = shape.parent.__renderedMask;
					} else {			
						var wt = shape.__worldTransform;
						var sx = Math.sqrt( ( wt.a * wt.a ) + ( wt.c * wt.c ) );
						var sy = Math.sqrt( ( wt.b * wt.b ) + ( wt.d * wt.d ) );
						var bs = shape.getBounds( shape );
						var bm = shape.mask.getBounds( shape );
						var tx = -sx * (bs.x - bm.x);
						var ty = -sy * (bs.y - bm.y);
						
						maskBitmap = new BitmapData(graphics.__bitmap.width, graphics.__bitmap.height, true, 0x00000000);
						var m = new Matrix();
						m.translate( tx, ty );
						m.rotate( shape.__mask.rotation * Math.PI / 180 );
						maskBitmap.draw( maskGraphics.__bitmap, m );

						shape.__renderedMask = maskBitmap;
					}
					
					renderSession.shaderManager.setActiveTexture( 1 );
					
					//trace("scale:" + sx + "/" + sy + " t:=" + tx + "/" + ty + " r:" + shape.__mask.rotation);
					
					gl.bindTexture (gl.TEXTURE_2D, maskBitmap.getTexture (gl));
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
				}
				
				gl.bindBuffer (gl.ARRAY_BUFFER, graphics.__bitmap.getBuffer (gl, shape.__worldAlpha));
				gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
				gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
				gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
				
				gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
				
				renderSession.filterManager.popObject (shape);
				//renderSession.maskManager.popObject (shape);
				
			}
			
		}
		
	}
	
}
