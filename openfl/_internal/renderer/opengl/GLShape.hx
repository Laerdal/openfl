package openfl._internal.renderer.opengl;


import flash.geom.Point;
import flash.geom.Rectangle;
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

@:access(openfl.display.DisplayObject)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Graphics)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.Matrix)


class GLShape {
	
	private static var maskMatrix:Matrix = new Matrix();

	public static inline function render (shape:DisplayObject, renderSession:RenderSession):Void {
		
		if (!shape.__renderable || shape.__worldAlpha <= 0 || shape.__renderedAsCachedBitmap) return;
		
		var graphics = shape.__graphics;

		var mask:DisplayObject;
		var maskGraphics:Graphics = null;
		var gl = renderSession.gl;

		//// Render mask
		if (shape.mask != null) {
			mask = shape.__mask;
			maskGraphics = shape.__mask.__graphics;

			#if (js && html5)
			CanvasGraphics.render (maskGraphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#elseif lime_cairo
			CairoGraphics.render (maskGraphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			#end
		}
		
		var isMasked = (maskGraphics != null && maskGraphics.__bitmap != null) || shape.parent.__renderedMask != null;

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
				
				if (isMasked) {

					shader = renderSession.shaderManager.defaultMaskingShader;
					shader.data.uImage1.input = graphics.__bitmap;
					shader.data.uImage1.smoothing = renderSession.allowSmoothing;
					
				} else {
					
					shader = renderSession.filterManager.pushObject (shape);
										
				}
				
				shader.data.uImage0.input = graphics.__bitmap;
				shader.data.uImage0.smoothing = renderSession.allowSmoothing;
				shader.data.uMatrix.value = renderer.getMatrix (graphics.__worldTransform);
				
				renderSession.blendModeManager.setBlendMode (shape.blendMode);
				renderSession.shaderManager.setShader (shader);
				renderSession.maskManager.pushObject (shape);

				if (renderSession.allowSmoothing) {
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
					
				} else {
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
					
				}
							
				if (isMasked) {

					if (shape.parent.__renderedMask != null) {
	
						graphics.__maskBitmap = shape.__renderedMask = shape.parent.__renderedMask;
					
					} else {			
													
						var wt = shape.__worldTransform;
                        var sx = Math.sqrt( ( wt.a * wt.a ) + ( wt.c * wt.c ) );
                        var sy = Math.sqrt( ( wt.b * wt.b ) + ( wt.d * wt.d ) );
                        var bm = shape.mask.getBounds( shape );
						var tx = sx * (bm.x - maskGraphics.__bounds.x - graphics.__bounds.x);
                        var ty = sy * (bm.y - maskGraphics.__bounds.y - graphics.__bounds.y);
                        
						maskMatrix.identity();
						maskMatrix.translate( maskGraphics.__bounds.x * sx, maskGraphics.__bounds.y * sy );
						maskMatrix.rotate( shape.mask.rotation * Math.PI / 180 );
						maskMatrix.translate( tx, ty );
 						
						if (graphics.__maskBitmap == null || graphics.__maskBitmap.width != graphics.__bitmap.width || graphics.__maskBitmap.height != graphics.__bitmap.height)
							graphics.__maskBitmap = new BitmapData(graphics.__bitmap.width, graphics.__bitmap.height, true, 0x00000000);

						graphics.__maskBitmap.fillRect( graphics.__maskBitmap.rect, 0 );
						graphics.__maskBitmap.draw( maskGraphics.__bitmap, maskMatrix );

						shape.__renderedMask = graphics.__maskBitmap;
						
					}
					
					renderSession.shaderManager.setActiveTexture( 1 );
					
					gl.bindTexture (gl.TEXTURE_2D, graphics.__maskBitmap.getTexture (gl));
					
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
					gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);

					renderSession.shaderManager.setActiveTexture( 0 );
				}
				
				gl.bindBuffer (gl.ARRAY_BUFFER, graphics.__bitmap.getBuffer (gl, shape.__worldAlpha));
				gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
				gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
				gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
				
				gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
				
				renderSession.filterManager.popObject (shape);
				renderSession.maskManager.popObject (shape);
				
			}
			
		}
		
	}
	
}
