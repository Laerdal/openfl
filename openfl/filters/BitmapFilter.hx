package openfl.filters;


import openfl._internal.renderer.RenderSession;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;


class BitmapFilter {
	
	private var __filterDirty:Bool;
	private var __preserveOriginal:Bool;
	private var __filterTransform:Matrix;
	

	public function new () {
		
		__filterDirty = true;
		__preserveOriginal = false;

		__filterTransform = new Matrix();
		
	}
	
	
	public function clone ():BitmapFilter {
		
		return new BitmapFilter ();
		
	}
	
	
	private function __applyFilter (sourceBitmapData:BitmapData, destBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point):Void {
		
		
		
	}
	

	private function __getFilterBounds( sourceBitmapData:BitmapData ) : Rectangle {

		return new Rectangle();

	}


	private function __renderFilter (sourceBitmapData:BitmapData, destBitmapData:BitmapData):Void {
		
		__filterDirty = false;
		
	}


	private function __initShader (renderSession:RenderSession):Shader {
		
		return renderSession.shaderManager.defaultShader;
		
	}
	
	
}