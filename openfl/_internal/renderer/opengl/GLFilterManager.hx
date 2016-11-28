package openfl._internal.renderer.opengl;


import lime.graphics.GLRenderContext;
import openfl._internal.renderer.AbstractFilterManager;
import openfl.display.DisplayObject;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.geom.Rectangle;
import openfl.geom.Point;

@:access(openfl._internal.renderer.opengl.GLRenderer)
@:access(openfl.display.DisplayObject)
@:access(openfl.filters.BitmapFilter)
@:keep


class GLFilterManager extends AbstractFilterManager {
	
	private var gl:GLRenderContext;
	
	public function new (renderSession:RenderSession) {
		
		super (renderSession);
		
		this.gl = renderSession.gl;
		
	}
	
	
	public override function renderFilters (object:DisplayObject, src:BitmapData):BitmapData {

		if (object.__filters != null && object.__filters.length > 0) {

			var filtersDirty:Bool = object.__filterDirty;
			for (filter in object.__filters) {
				filtersDirty = filtersDirty || filter.__filterDirty;
			}
			
			if (object.__filterBitmap == null || filtersDirty) {
		
				// Only support single filter at the moment for offsets
				object.__filterOffset = object.__filters[0].__filterOffset;
				var bounds:Rectangle = object.__filterBounds = new Rectangle( 0, 0, src.width, src.height );
				var filterBounds:Rectangle;
				for (filter in object.__filters) {
					filterBounds = filter.__getFilterBounds( src );
					bounds.x = Math.max( bounds.x, filterBounds.x);
					bounds.y = Math.max( bounds.y, filterBounds.y);
					bounds.width = Math.max( bounds.width, filterBounds.width);
					bounds.height = Math.max( bounds.height, filterBounds.height);
				}
				
				var displacedSource = new BitmapData(Std.int(bounds.width), Std.int(bounds.height), src.transparent, 0x0);
				displacedSource.copyPixels( src, src.rect, new Point( bounds.x, bounds.y ) );
				object.__filterBitmap = new BitmapData(Std.int(bounds.width), Std.int(bounds.height), src.transparent, 0x0);

				// USE THE FOLLOWING FOR DEBUGGING AND TIMING
				// trace("Filter:"+object.name);
				// haxe.Timer.measure(function() {
				// 	for (filter in object.__filters) {
				// 		trace(" - Filter:"+filter);
				// 		filter.__renderFilter( displacedSource, object.__filterBitmap );
				// 	}
				// });

				for (filter in object.__filters) {
					filter.__renderFilter( displacedSource, object.__filterBitmap );
				}

				// var overlay = new BitmapData(Std.int(bounds.width), Std.int(bounds.height), src.transparent, 0x20008800);
				// object.__filterBitmap.draw( overlay );
				// object.__filterBitmap.fillRect( new Rectangle( 0, 0, 10, 10), 0xffff0000 );

				displacedSource = null;

				object.__filterDirty = false;
			}
			
		}

		return object.__filterBitmap;
	}

	public override function pushObject (object:DisplayObject):Shader {
		
		if (object.__filters != null && object.__filters.length > 0) {
			
			return object.__filters[0].__initShader (renderSession);
			
		} else {
			
			return renderSession.shaderManager.defaultShader;
			
		}
		
	}
	
	
	public override function popObject (object:DisplayObject):Void {
		
		
		
	}
	
	
}