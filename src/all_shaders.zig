const std = @import("std");
const allocator = std.heap.wasm_allocator;

const c = @import("webgl.zig");
const debug_gl = @import("debug_gl.zig");

const math3d = @import("math3d.zig");
const Vec4 = math3d.Vec4;
const Mat4x4 = math3d.Mat4x4;

pub const AllShaders = struct {
    primitive: ShaderProgram,
    primitive_attrib_position: c.GLint,
    primitive_uniform_mvp: c.GLint,
    primitive_uniform_color: c.GLint,

    texture: ShaderProgram,
    texture_attrib_tex_coord: c.GLint,
    texture_attrib_position: c.GLint,
    texture_uniform_mvp: c.GLint,
    texture_uniform_tex: c.GLint,

    pub fn create() AllShaders {
        var as: AllShaders = undefined;

        var vertex_array_object: c.GLuint = c.glCreateVertexArray();
        c.glBindVertexArray(vertex_array_object);

        as.primitive = ShaderProgram.create(
            \\#version 300 es
            \\precision mediump float;
            \\in vec3 VertexPosition;
            \\uniform mat4 MVP;
            \\void main(void) {
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
            \\#version 300 es
            \\precision mediump float;
            \\out vec4 FragColor;
            \\uniform vec4 Color;
            \\void main(void) {
            \\    FragColor = Color;
            \\}
        );

        as.primitive_attrib_position = as.primitive.attribLocation("VertexPosition");
        as.primitive_uniform_mvp = as.primitive.uniformLocation("MVP");
        as.primitive_uniform_color = as.primitive.uniformLocation("Color");

        as.texture = ShaderProgram.create(
            \\#version 300 es
            \\precision mediump float;
            \\in vec3 VertexPosition;
            \\in vec2 TexCoord;
            \\out vec2 FragTexCoord;
            \\uniform mat4 MVP;
            \\void main(void) {
            \\    FragTexCoord = TexCoord;
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
            \\#version 300 es
            \\precision mediump float;
            \\in vec2 FragTexCoord;
            \\out vec4 FragColor;
            \\uniform sampler2D Tex;
            \\void main(void) {
            \\    FragColor = texture(Tex, FragTexCoord);
            \\}
        );

        as.texture_attrib_tex_coord = as.texture.attribLocation("TexCoord");
        as.texture_attrib_position = as.texture.attribLocation("VertexPosition");
        as.texture_uniform_mvp = as.texture.uniformLocation("MVP");
        as.texture_uniform_tex = as.texture.uniformLocation("Tex");

        debug_gl.assertNoError();

        return as;
    }

    pub fn destroy(as: *AllShaders) void {
        as.primitive.destroy();
        as.texture.destroy();
    }
};

pub const ShaderProgram = struct {
    program_id: c.GLuint,
    vertex_id: c.GLuint,
    fragment_id: c.GLuint,
    maybe_geometry_id: ?c.GLuint,

    pub fn bind(sp: ShaderProgram) void {
        c.glUseProgram(sp.program_id);
    }

    pub fn attribLocation(sp: ShaderProgram, name: []const u8) c.GLint {
        const id = c.glGetAttribLocation(sp.program_id, &name.ptr[0], name.len);
        if (id == -1) unreachable;
        return id;
    }

    pub fn uniformLocation(sp: ShaderProgram, name: []const u8) c.GLint {
        const id = c.glGetUniformLocation(sp.program_id, &name.ptr[0], name.len);
        if (id == -1) unreachable;
        return id;
    }

    pub fn setUniformInt(sp: ShaderProgram, uniform_id: c.GLint, value: c_int) void {
        c.glUniform1i(uniform_id, value);
    }

    pub fn setUniformFloat(sp: ShaderProgram, uniform_id: c.GLint, value: f32) void {
        c.glUniform1f(uniform_id, value);
    }

    pub fn setUniformVec3(sp: ShaderProgram, uniform_id: c.GLint, value: math3d.Vec3) void {
        c.glUniform3fv(uniform_id, value.data[0], value.data[1], value.data[2]);
    }

    pub fn setUniformVec4(sp: ShaderProgram, uniform_id: c.GLint, value: Vec4) void {
        c.glUniform4fv(uniform_id, value.data[0], value.data[1], value.data[2], value.data[3]);
    }

    pub fn setUniformMat4x4(sp: ShaderProgram, uniform_id: c.GLint, value: Mat4x4) void {
        c.glUniformMatrix4fv(uniform_id, 1, c.GL_FALSE, value.data[0][0..].ptr);
    }

    pub fn create( vertex_source: []const u8, frag_source: []const u8, ) ShaderProgram {
        var sp: ShaderProgram = undefined;
        sp.vertex_id = c.compileShader(&vertex_source[0], vertex_source.len, c.GL_VERTEX_SHADER);
        sp.fragment_id = c.compileShader(&frag_source[0], frag_source.len, c.GL_FRAGMENT_SHADER);
        sp.program_id = c.linkShaderProgram(sp.vertex_id, sp.fragment_id);
        debug_gl.assertNoError();
        return sp;
    }

    pub fn destroy(sp: *ShaderProgram) void {
        if (sp.maybe_geometry_id) |geo_id| {
            c.glDetachShader(sp.program_id, geo_id);
        }
        c.glDetachShader(sp.program_id, sp.fragment_id);
        c.glDetachShader(sp.program_id, sp.vertex_id);

        if (sp.maybe_geometry_id) |geo_id| {
            c.glDeleteShader(geo_id);
        }
        c.glDeleteShader(sp.fragment_id);
        c.glDeleteShader(sp.vertex_id);

        c.glDeleteProgram(sp.program_id);
    }
};