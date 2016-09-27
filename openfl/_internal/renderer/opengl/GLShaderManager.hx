package openfl._internal.renderer.opengl;


import lime.graphics.GLRenderContext;
import openfl._internal.renderer.AbstractShaderManager;
import openfl.display.Shader;
import openfl.display.MaskingShader;

@:access(openfl.display.Shader)


class GLShaderManager extends AbstractShaderManager {
	
	
	private var gl:GLRenderContext;
	
	
	public function new (gl:GLRenderContext) {
		
		super ();
		
		this.gl = gl;
		
		defaultShader = new Shader ();
		defaultShader.gl = gl;
		defaultShader.__init ();
		
		defaultMaskingShader = new MaskingShader ();
		defaultMaskingShader.gl = gl;
		defaultMaskingShader.__init ();
	}
	
	
	public override function setShader (shader:Shader):Void {
		
		if (currentShader == shader) {
			
			if (currentShader != null) currentShader.__update ();
			return;
			
		}
		
		if (currentShader != null) {
			
			currentShader.__disable ();
			
		}
		
		if (shader == null) {
			
			currentShader = null;
			gl.useProgram (null);
			return;
			
		}
		
		currentShader = shader;
		
		if (currentShader.gl == null) {
			
			currentShader.gl = gl;
			currentShader.__init ();
			
		}
		
		gl.useProgram (shader.glProgram);
		currentShader.__enable ();
		currentShader.__update ();
		
	}
	
	
	public override function setActiveTexture( idx:Int ) {
		
		switch (idx) {
			case 0 : gl.activeTexture (gl.TEXTURE0);
			case 1 : gl.activeTexture (gl.TEXTURE1);
			case 2 : gl.activeTexture (gl.TEXTURE2);
			case 3 : gl.activeTexture (gl.TEXTURE3);
			case 4 : gl.activeTexture (gl.TEXTURE4);
			case 5 : gl.activeTexture (gl.TEXTURE5);
			case 6 : gl.activeTexture (gl.TEXTURE6);
			case 7 : gl.activeTexture (gl.TEXTURE7);
		}

	}
	
	
}