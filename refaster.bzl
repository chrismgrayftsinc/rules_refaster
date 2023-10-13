def _refaster_runner_impl(ctx):
    toolchain_info = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    javabuilder = ctx.attr.javabuilder
    out = ctx.actions.declare_file(ctx.attr.name)

    common_substitutions = {
        "{{JAVA_BIN}}": toolchain_info.java_runtime.java_executable_exec_path,
        "{{JAVA_BUILDER}}": javabuilder.files.to_list()[0].path,
        "{{JAVA_OPTS}}": " ".join(toolchain_info.jvm_opt.to_list()),
        "{{TARGET_LABEL}}": "//:foo",
        "{{CLASSPATH}}": " ".join([x.path for x in ctx.attr.deps[0][JavaInfo].compilation_info.compilation_classpath.to_list()]),
        "{{BOOTCLASSPATH}}": " ".join([x.path for x in toolchain_info.bootclasspath.to_list()]),
        "{{PROCESSOR_CLASS_PATH}}": " ".join([x.path for x in ctx.attr.plugins[0][JavaInfo].plugins.processor_jars.to_list()]),
        "{{PROCESSOR_CLASS_NAMES}}": " ".join(ctx.attr.plugins[0][JavaInfo].plugins.processor_classes.to_list()),
        "{{SOURCES}}": " ".join([y.path for x in ctx.attr.srcs for y in x.files.to_list()]),
        "{{CHECKS}}": ",".join(ctx.attr.checks),
    }

    ctx.actions.expand_template(
        template = ctx.file._entry,
        output = out,
        substitutions = common_substitutions,
        is_executable = True,
    )

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = ctx.runfiles(toolchain_info.tools.to_list() + toolchain_info.java_runtime.files.to_list() + javabuilder.files.to_list() + ctx.attr.deps[0][JavaInfo].compilation_info.compilation_classpath.to_list()),
        ),
    ]

_refaster_runner = rule(
    implementation = _refaster_runner_impl,
    executable = True,
    attrs = dict(
        deps = attr.label_list(),
        plugins = attr.label_list(),
        srcs = attr.label_list(),
        javabuilder = attr.label(
            allow_single_file = True,
            default = "@rules_refaster//:RefasterJavaBuilder_deploy.jar",
        ),
        _entry = attr.label(
            allow_single_file = True,
            default = "@rules_refaster//:refaster.sh",
        ),
        _jdk = attr.label(
            default = Label("@remote_java_tools//:JavaBuilder"),
        ),
        checks = attr.string_list(),
    ),
    toolchains = ["@bazel_tools//tools/jdk:toolchain_type"],
)

def refaster(deps, plugins, srcs, checks):
    _refaster_runner(
        name = "refaster-runner",
        deps = deps,
        plugins = plugins,
        srcs = srcs,
        checks = checks,
    )
    native.sh_binary(
        name = "refaster",
        srcs = ["refaster-runner"],
        visibility = ["//visibility:public"],
    )
