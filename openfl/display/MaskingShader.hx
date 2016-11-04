package openfl.display;

import openfl.utils.ByteArray;

class MaskingShader extends Shader
{

	public function new(code:ByteArray=null) 
	{		
		if (glFragmentSource == null) {
			
			glFragmentSource = 
				
				"varying float vAlpha;
				varying vec2 vTexCoord;
				uniform sampler2D uImage0;
				uniform sampler2D uImage1;
				
				
				void main(void) {
					
					vec4 color = texture2D (uImage0, vTexCoord);
					vec4 mask = texture2D (uImage1, vTexCoord);
					
					//TODO: Uncommnent this block for debugging shader
					//if (mask.a > 0.0) {
					//
					//	gl_FragColor = vec4 ((mask.rgb * 0.5) + (color.rgb * 0.5), 1.0);
					//
					//} else if (color.a == 0.0) {
					//
					//	gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);
					//
					//} else {
					//
					//	gl_FragColor = vec4 (color.rgb / color.a, color.a * vAlpha);
					//
					//}

					//TODO: Comment out this block when debugging shader is being used
					if (color.a == 0.0) {
						
						gl_FragColor = vec4 (0.0, 0.0, 0.0, 0.0);
						
					} else {
						
						gl_FragColor = color * vAlpha * mask.a;
						
					}
					
				}";
		}

		super(code);
		
	}
	
	private override function __init ():Void {
		
		super.__init();
		
		if (gl != null && glProgram == null && glFragmentSource != null && glVertexSource != null) {
			
			// Add second uniform for mask texture in fragment shader
			if (glProgram != null) {
				__processGLData (glFragmentSource, "uniform");
			}
			
		}
		
	}
}