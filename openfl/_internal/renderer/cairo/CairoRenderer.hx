package openfl._internal.renderer.cairo;


import flash.display.Bitmap;
import openfl._internal.renderer.opengl.GLShape;
import flash.display.BitmapData;
import flash.display.DisplayObjectContainer;
import lime.graphics.cairo.Cairo;
import openfl._internal.renderer.AbstractRenderer;
import openfl._internal.renderer.RenderSession;
import openfl.display.DisplayObject;
import openfl.display.Stage;

@:access(openfl.display.Graphics)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Stage)
@:allow(openfl.display.Stage)


class CairoRenderer extends AbstractRenderer {
	
	
	private var cairo:Cairo;
	
	
	public function new (stage:Stage, cairo:Cairo) {
		
		super (stage);
		
		this.cairo = cairo;
		
		renderSession = new RenderSession ();
		renderSession.cairo = cairo;
		renderSession.roundPixels = true;
		renderSession.renderer = this;
		renderSession.maskManager = new CairoMaskManager (renderSession);
		renderSession.blendModeManager = new CairoBlendModeManager (renderSession);
		
	}
	
	
	public override function render ():Void {
		
		renderSession.allowSmoothing = (stage.quality != LOW);
		
		cairo.identityMatrix ();
		
		if (stage.__clearBeforeRender) {
			
			cairo.setSourceRGB (stage.__colorSplit[0], stage.__colorSplit[1], stage.__colorSplit[2]);
			cairo.paint ();
			
		}
		
		stage.__renderCairo (renderSession);
		
	}
	
	
	//
	// Initial code (now not used) to render each display object child as a bitmap and render them all to a single bitmap 
	// to act as a cacheAsBitmap mechanism.
	//
	// It's now not used as cacheAsBitmap for masking only affects alpha masking not masking of child layer - that just happens in flash
	//
	private static var ctr:Int = 0;
	
	public static function flatten (shape:DisplayObject, bmd:BitmapData, renderSession:RenderSession ) {

		if (shape==null || !shape.__renderable || shape.__worldAlpha <= 0) return;
		trace("flatten:" + shape.name+" bnds:"+shape.getBounds(shape)+" wt:"+shape.__worldTransform);
		
		if (Std.is(shape, DisplayObjectContainer)) {
			var cont:DisplayObjectContainer = cast shape;
			var child:DisplayObject;
			for (i in 0...cont.numChildren) {
				child = cont.getChildAt( i );
				child.__renderedAsCachedBitmap == true;
				flatten( child, bmd, renderSession );
			}
		}

		var graphics = shape.__graphics;
		if (graphics!=null) {
			CairoGraphics.render (graphics, renderSession, shape.__renderTransform, shape.__worldColorTransform.__isDefault() ? null : shape.__worldColorTransform);
			
			if (graphics.__bitmap!=null)
				bmd.draw( graphics.__bitmap );
		}
		
	}	

}


