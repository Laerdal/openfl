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
        var stdRender = true;


        // Render cache as bitmap
        if ( shape.cacheAsBitmap ) {
            
			renderSession.updateCachedBitmap( shape );

			renderSession.maskManager.pushObject (shape);
			renderSession.filterManager.pushObject (shape);

			if (shape.__cachedBitmap != null) {

				if (renderSession.filterManager.useCPUFilters && shape.filters != null && shape.filters.length > 0) {
						
					renderFilterBitmap( shape, renderSession );
				
					stdRender = shape.filters[0].__preserveOriginal;
				} 

				if (stdRender)
					renderCacheAsBitmap( shape, renderSession );
			}

			renderSession.filterManager.popObject (shape);
			renderSession.maskManager.popObject (shape);

        } else {

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

			if (graphics != null && stdRender) {

				#if (js && html5)
				CanvasGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
				#elseif lime_cairo
				CairoGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
				#end
			
				if (graphics.__bitmap != null && graphics.__visible) {
					
					var renderer:GLRenderer = cast renderSession.renderer;
					var gl = renderSession.gl;
					
					var shader;
					var targetBitmap = graphics.__bitmap;
					var transform = graphics.__worldTransform;

					if (isMasked) {

						shader = renderSession.shaderManager.defaultMaskingShader;
						shader.data.uImage1.input = graphics.__bitmap;
						shader.data.uImage1.smoothing = renderSession.allowSmoothing;
						
					} else {
									
						shader = renderSession.shaderManager.defaultShader;
											
					}
		
					shader.data.uImage0.input = targetBitmap;
					shader.data.uImage0.smoothing = renderSession.allowSmoothing;
					shader.data.uMatrix.value = renderer.getMatrix (transform);
					
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

							shape.__mask.__updateTransforms();

							var bmd = shape.__mask.__graphics.__bitmap;
							var transform = shape.__mask.__graphics.__worldTransform;
							var topLeft = transform.transformPoint( new Point( 0, 0 ) );
							var topRight = transform.transformPoint( new Point( bmd.width, 0 ) );
							var bottomLeft = transform.transformPoint( new Point( 0, bmd.height ) );
							var bottomRight = transform.transformPoint( new Point( bmd.width,  bmd.height ) );
							
							var top = Math.min( topLeft.y,  Math.min( topRight.y,  Math.min( bottomLeft.y, bottomRight.y ) ) );
							var bottom = Math.max( topLeft.y,  Math.max( topRight.y,  Math.max( bottomLeft.y, bottomRight.y ) ) );
							var left = Math.min( topLeft.x,  Math.min( topRight.x,  Math.min( bottomLeft.x, bottomRight.x ) ) );
							var right = Math.max( topLeft.x,  Math.max( topRight.x,  Math.max( bottomLeft.x, bottomRight.x ) ) );

							var bounds = new Rectangle( topLeft.x, topLeft.y, right - left, bottom - top );

							var wt = shape.__worldTransform;
							var sx = Math.sqrt( ( wt.a * wt.a ) + ( wt.c * wt.c ) );
							var sy = Math.sqrt( ( wt.b * wt.b ) + ( wt.d * wt.d ) );
							var bm = shape.__mask.getBounds( shape );
							var tx = sx * (bm.x - maskGraphics.__bounds.x - graphics.__bounds.x);
							var ty = sy * (bm.y - maskGraphics.__bounds.y - graphics.__bounds.y);
							
							maskMatrix.identity();
							maskMatrix.translate( maskGraphics.__bounds.x * sx, maskGraphics.__bounds.y * sy );
							maskMatrix.rotate( shape.mask.rotation * Math.PI / 180 );
							maskMatrix.translate( tx, ty );

							var shapeTransform = shape.__worldTransform.clone();
							var maskTransform = shape.__mask.__worldTransform.clone();
							
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
					}
					
					renderSession.shaderManager.setActiveTexture( 0 );
					
					gl.bindBuffer (gl.ARRAY_BUFFER, targetBitmap.getBuffer (gl, shape.__worldAlpha));
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

	private static inline function renderFilterBitmap (shape:DisplayObject, renderSession:RenderSession):Void {

		var shapeTransform = shape.__graphics == null ? shape.__worldTransform.clone() : shape.__graphics.__worldTransform.clone();
		var targetBitmap = renderSession.filterManager.renderFilters( shape, shape.__cachedBitmap );
		var transform = new Matrix();
		var pt = new Point ( shapeTransform.tx, shapeTransform.ty );
		pt = transform.deltaTransformPoint( pt );
		transform.translate( pt.x, pt.y );
		transform.translate( -shape.__filterBounds.x + shape.__filterOffset.x , -shape.__filterBounds.y + shape.__filterOffset.y );
		transform.translate( -shape.__cacheAsBitmapMatrix.tx, -shape.__cacheAsBitmapMatrix.ty );
	
		renderBitmapTexture( targetBitmap, transform, shape, renderSession );
	}

	private static inline function renderCacheAsBitmap (shape:DisplayObject, renderSession:RenderSession):Void {

		var shapeTransform = shape.__graphics == null ? shape.__worldTransform.clone() : shape.__graphics.__worldTransform.clone();
		var targetBitmap = shape.__cachedBitmap;
		var transform = new Matrix();
		var pt = new Point ( shapeTransform.tx, shapeTransform.ty );
		pt = transform.deltaTransformPoint( pt );
		transform.translate( pt.x, pt.y );
		transform.translate( -shape.__cacheAsBitmapMatrix.tx, -shape.__cacheAsBitmapMatrix.ty );

		renderBitmapTexture( targetBitmap, transform, shape, renderSession );
	}

	private static inline function renderBitmapTexture (targetBitmap:BitmapData, transform:Matrix, shape:DisplayObject, renderSession:RenderSession):Void {
						
		var gl = renderSession.gl;
		var renderer:GLRenderer = cast renderSession.renderer;
		var shader = renderSession.shaderManager.defaultShader;

		shader.data.uImage0.input = targetBitmap;
		shader.data.uImage0.smoothing = renderSession.allowSmoothing;
		shader.data.uMatrix.value = renderer.getMatrix (transform);
		
		renderSession.blendModeManager.setBlendMode (shape.blendMode);
		renderSession.shaderManager.setShader (shader);
		renderSession.maskManager.pushObject (shape);
							
		renderSession.shaderManager.setActiveTexture( 0 );
		
		gl.bindBuffer (gl.ARRAY_BUFFER, targetBitmap.getBuffer (gl, shape.__worldAlpha));
		
		if (renderSession.allowSmoothing) {
			
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
			
		} else {
			
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
			
		}
		
		gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
						
	}

}
