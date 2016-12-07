package openfl.filters;


import lime.graphics.utils.ImageCanvasUtil;
import lime.utils.UInt8Array;
import openfl._internal.renderer.RenderSession;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.filters.FilterUtils;
import openfl.geom.Rectangle;


class GlowFilter extends BlurFilter {
	
	private static var __glowShader = new GlowShader ();
	
	public var alpha (default, set):Float;
	public var color (default, set):Int;
	public var inner (default, set):Bool;
	public var hideObject (default, set):Bool;
	public var knockout (default, set):Bool;
	public var strength (default, set):Float;
	
	
	public function new (color:Int = 0xFF0000, alpha:Float = 1, blurX:Float = 6, blurY:Float = 6, strength:Float = 2, quality:Int = 1, inner:Bool = false, knockout:Bool = false) {
		
		super ( blurX, blurY, quality );
		
		__preserveOriginal = true;

		this.color = color;
		this.alpha = alpha;
		this.strength = strength;
		this.inner = inner;
		this.knockout = knockout;
		
	}
	
	
	public override function clone ():BitmapFilter {
		
		return new GlowFilter (color, alpha, blurX, blurY, strength, quality, inner, knockout);
		
	}
	
	
	public override function toString ():String {
		
		return "GlowFilter: [ color:0x" + StringTools.hex(color,6) + ", alpha:" + alpha + ", blurX:" + blurX + ", blurY:" + blurY + ", strength:" + strength + ", quality:" + quality + ", inner:" + inner + ", knockout:" + knockout + " ]";
		
	}
	
	
	
	
	// Get & Set Methods
	
	
	
	
	
	private function set_color (value:UInt):UInt {

		if (value != color)
			__filterDirty = true;

		return color = value;
		
	}
	
	
	private function set_alpha (value:Float):Float {

		if (value != alpha)
			__filterDirty = true;

		return alpha = value;
		
	}
	
	
	private function set_inner (value:Bool):Bool {

		if (value != inner)
			__filterDirty = true;

		return inner = value;
		
	}

	private function set_knockout (value:Bool):Bool {

		if (value != knockout)
			__filterDirty = true;

		return knockout = value;
		
	}
	
	
	private function set_hideObject (value:Bool):Bool {
		
		if (value != hideObject)
			__filterDirty = true;

		return hideObject = value;
		
	}


	private function set_strength (value:Float):Float {

		if (value != strength)
			__filterDirty = true;

		return strength = value;
		
	}



	private override function __initShader (renderSession:RenderSession):Shader {
		
		var data = __glowShader.data;
		
		data.uColor[0] = color;
		data.uAlpha[0] = alpha;
		data.uBlurX[0] = blurX;
		data.uBlurY[0] = blurY;
		data.uStrength[0] = strength;
		data.uQuality[0] = quality;
		data.uInner[0] = inner;
		data.uKnockout[0] = knockout;
		data.uHideObject[0] = hideObject;
		
		return __glowShader;
		
	}
	

	private override function __renderFilter (sourceBitmapData:BitmapData, destBitmapData:BitmapData):Void {

		var tmpSrc = sourceBitmapData.clone();
		#if (js && html5)
		ImageCanvasUtil.convertToData (tmpSrc.image);
		ImageCanvasUtil.convertToData (destBitmapData.image);
		#end

		var source = sourceBitmapData.image.data;
		var target = destBitmapData.image.data;

		var i = 0;
		var cR = (color >> 16) & 0xff;
		var cG = (color >> 8) & 0xff;
		var cB = color & 0xff;
		var cA = Std.int(alpha * 0xff);
		while (i < source.length) {
			source[ i ] = target[ i ] = cR;
			source[ i+1 ] = target[ i+1 ] = cG;
			source[ i+2 ] = target[ i+2 ] = cB;
			i += 4;
		}

		FilterUtils.GaussianBlur( source, target, sourceBitmapData.width, sourceBitmapData.height, blurX, blurY, quality, strength );

		tmpSrc = null;

		__filterDirty = false;
	}
	
}

private class GlowShader extends Shader {


	@:glFragmentSource( 
		
		"varying float vAlpha;
		varying vec2 vTexCoord;

		uniform sampler2D uImage0;
		
		uniform float uDistance;
		uniform float uAngle;
		uniform float uColor;
		uniform float uAlpha;
		uniform float uBlurX;
		uniform float uBlurY;
		uniform float uStrength;
		uniform float uQuality;
		uniform bool uInner;
		uniform bool uKnockout;
		uniform bool uHideObject;
		
		float normpdf(in float x, in float sigma)
		{
			return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
		}

		void main(void)
		{
			vec4 c = texture2D(uImage0, vTexCoord);

			// OPERATIONAL BUT VERY SLOW
			if (c.a > 0.0) {
				gl_FragColor = c;
			} else {
				//declare stuff
				const int mSize = 21;
				const int kSize = (mSize-1)/2;
				float kernel[mSize];
				vec3 final_colour = vec3(0.0);
				
				//create the 1-D kernel
				float sigma = 7.0;
				float Z = 0.0;
				for (int j = 0; j <= kSize; ++j)
				{
					kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), sigma);
				}
				
				//get the normalization factor (as the gaussian has been clamped)
				for (int j = 0; j < mSize; ++j)
				{
					Z += kernel[j];
				}
				
				//read out the texels
				for (int i=-kSize; i <= kSize; ++i)
				{
					for (int j=-kSize; j <= kSize; ++j)
					{
						final_colour += kernel[kSize+j] * kernel[kSize+i] * texture2D(uImage0, (vTexCoord.xy + vec2(float(i), float(j))/vec2(512,512))).rgb;
			
					}
				}
				
				
				gl_FragColor = vec4(final_colour/(Z*Z), 1.0);
			}
		}"
		
	)
	
	@:glVertexSource( 
		
		"attribute float aAlpha;
		attribute vec4 aPosition;
		attribute vec2 aTexCoord;
		
		varying float vAlpha;
		varying vec2 vTexCoord;
		
		uniform mat4 uMatrix;
		
		void main(void) {
			
			vAlpha = aAlpha;
			vTexCoord = aTexCoord;
			gl_Position = uMatrix * aPosition;
			
		}"
		
	)

	
	public function new () {
		
		super ();
		
		data.uColor.value = [ 0 ];
		data.uAlpha.value = [ 1 ];
		data.uBlurX.value = [ 4 ];
		data.uBlurY.value = [ 4 ];
		data.uStrength.value = [ 1 ];
		data.uQuality.value = [ 1 ];
		data.uInner.value = [ false ];
		data.uKnockout.value = [ false ];
		data.uHideObject.value = [ false ];
		
	}
}