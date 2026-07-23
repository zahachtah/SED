export function detectWebGL2() {
  const canvas = document.createElement("canvas");
  const gl = canvas.getContext("webgl2", {
    antialias: false,
    depth: false,
    stencil: false,
    preserveDrawingBuffer: false
  });
  if (!gl) {
    return {
      supported: false,
      reason: "WebGL2 unavailable"
    };
  }

  const floatTexture = gl.getExtension("EXT_color_buffer_float");
  return {
    supported: true,
    floatTexture: !!floatTexture,
    maxTextureSize: gl.getParameter(gl.MAX_TEXTURE_SIZE),
    maxVertexTextures: gl.getParameter(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS)
  };
}

export class WebGLBatchEngine {
  constructor() {
    this.info = detectWebGL2();
  }

  ready() {
    return this.info.supported && this.info.floatTexture;
  }

  describe() {
    if (!this.info.supported) {
      return "CPU fallback";
    }
    if (!this.info.floatTexture) {
      return "WebGL2 without float render targets";
    }
    return `WebGL2 ready (${this.info.maxTextureSize}px textures)`;
  }
}
