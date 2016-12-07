package openfl._internal.renderer.opengl;


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
import openfl.geom.Point;
import openfl.geom.Rectangle;

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
	
	public static inline function render (shape:DisplayObject, renderSession:RenderSession):Void {
		
		if (!shape.__renderable || shape.__worldAlpha <= 0 || shape.__renderedAsCachedBitmap) return;
		
		var graphics = shape.__graphics;
		
		if (graphics != null) {
			
			#if (js && html5)
			CanvasGraphics.render (graphics, renderSession, shape.__renderTransform);
			#elseif lime_cairo
			CairoGraphics.render (graphics, renderSession, shape.__renderTransform);
			#end
	
			if (graphics.__bitmap != null && graphics.__visible) {
				
				var renderer:GLRenderer = cast renderSession.renderer;
				var gl = renderSession.gl;
				
				var shader;
				var targetBitmap = graphics.__bitmap;
				var transform = graphics.__worldTransform;
				var stdRender = true;

				if (renderSession.filterManager.useCPUFilters && shape.filters != null && shape.filters.length > 0) {
						
					renderFilterBitmap( shape, renderSession );
				
					stdRender = shape.filters[0].__preserveOriginal;
				} 

				if (stdRender) {

					renderSession.blendModeManager.setBlendMode (shape.blendMode);
					renderSession.maskManager.pushObject (shape);
				
					var shader = renderSession.filterManager.pushObject (shape);
				
					shader.data.uImage0.input = graphics.__bitmap;
					shader.data.uImage0.smoothing = renderSession.allowSmoothing;
					shader.data.uMatrix.value = renderer.getMatrix (graphics.__worldTransform);
				
					renderSession.shaderManager.setShader (shader);
				
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


	private static inline function renderFilterBitmap (shape:DisplayObject, renderSession:RenderSession):Void {
						
		var graphics = shape.__graphics;
		var gl = renderSession.gl;
		var renderer:GLRenderer = cast renderSession.renderer;
		var shader = renderSession.shaderManager.defaultShader;

		// Render filter bitmap and draw it
		renderSession.updateCachedBitmap( shape );
		
		var targetBitmap = renderSession.filterManager.renderFilters( shape, shape.__cachedBitmap );

		var transform = new Matrix();
		transform.translate( graphics.__worldTransform.tx, graphics.__worldTransform.ty );
		transform.translate( -shape.__filterBounds.x, -shape.__filterBounds.y );
		transform.translate( -shape.__cacheAsBitmapMatrix.tx, -shape.__cacheAsBitmapMatrix.ty );

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
							
		
		gl.bindBuffer (gl.ARRAY_BUFFER, targetBitmap.getBuffer (gl, shape.__worldAlpha));
		gl.vertexAttribPointer (shader.data.aPosition.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		gl.vertexAttribPointer (shader.data.aAlpha.index, 1, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 5 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
		
		renderSession.filterManager.popObject (shape);
		renderSession.maskManager.popObject (shape);
						
	}


}
