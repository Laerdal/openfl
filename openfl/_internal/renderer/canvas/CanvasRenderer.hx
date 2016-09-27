package openfl._internal.renderer.canvas;


import flash.display.Bitmap;
import openfl._internal.renderer.opengl.GLShape;
import flash.display.BitmapData;
import flash.display.DisplayObjectContainer;
import lime.graphics.CanvasRenderContext;
import openfl._internal.renderer.AbstractRenderer;
import openfl._internal.renderer.RenderSession;
import openfl.display.DisplayObject;
import openfl.display.Stage;

@:access(openfl.display.Graphics)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Stage)
@:access(openfl.display.Stage3D)


class CanvasRenderer extends AbstractRenderer {
	
	
	private var context:CanvasRenderContext;
	
	
	public function new (stage:Stage, context:CanvasRenderContext) {
		
		super (stage);
		
		this.context = context;
		
		renderSession = new RenderSession ();
		renderSession.context = context;
		renderSession.roundPixels = true ;
		renderSession.renderer = this;
		#if !neko
		renderSession.maskManager = new CanvasMaskManager(renderSession);
		#end
		
	}
	
	
	public override function clear ():Void {
		
		for (stage3D in stage.stage3Ds) {
			
			stage3D.__renderCanvas (stage, renderSession);
			
		}
		
	}
	
	
	public override function render ():Void {
		
		renderSession.allowSmoothing = (stage.quality != LOW);
		
		context.setTransform (1, 0, 0, 1, 0, 0);
		context.globalAlpha = 1;
		
		if (!stage.__transparent && stage.__clearBeforeRender) {
			
			context.fillStyle = stage.__colorString;
			context.fillRect (0, 0, stage.stageWidth, stage.stageHeight);
			
		} else if (stage.__transparent && stage.__clearBeforeRender) {
			
			context.clearRect (0, 0, stage.stageWidth, stage.stageHeight);
			
		}
		
		stage.__renderCanvas (renderSession);
		
	}
	
	//
	// Initial code (now not used) to render each display object child as a bitmap and render them all to a single bitmap 
	// to act as a cacheAsBitmap mechanism.
	//
	// It's now not used as cacheAsBitmap for masking only affects alpha masking not masking of child layer - that just happens in flash
	//
	private static var ctr:Int = 0;
	private static var ctr2:Int = 0;
	
	public static function flatten (shape:DisplayObject, bmd:BitmapData, renderSession:RenderSession ) {

		if (!shape.__renderable || shape.__worldAlpha <= 0) return;
		if (ctr2 < 20)
			trace("flatten:" + shape.name+" bnds:"+shape.getBounds(shape)+" wt:"+shape.__renderTransform);
				
		if (Std.is(shape, DisplayObjectContainer)) {
			var cont:DisplayObjectContainer = cast shape;
			for (i in 0...cont.numChildren) {
				flatten( cont.getChildAt( i ), bmd, renderSession );
			}
		}

		var graphics = shape.__graphics;
		if (graphics!=null) {
			CanvasGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			
			if (graphics.__bitmap!=null)
				bmd.draw( graphics.__bitmap, shape.__worldTransform );
		}
		
		if (GLShape.DEBUG &&  ctr2 < 20) {
			var b = new Bitmap(bmd.clone());
			b.x = 50;
			b.y = ctr++ * 250;
			Lib.current.stage.addChild(b);
		}
		ctr2++;
	}	

}