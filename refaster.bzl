def _is_absolute_path(ctx, path):
    return path.startswith("/")

def _refaster_runner_impl(ctx):
    toolchain_info = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java
    javabuilder = ctx.attr.javabuilder
    out = ctx.actions.declare_file(ctx.attr.name)
    print("ctx is ", ctx)

    common_substitutions = {
        "{{JAVA_BIN}}": toolchain_info.java_runtime.java_executable_exec_path,
        "{{JAVA_BUILDER}}": javabuilder.files.to_list()[0].path,
        "{{JAVA_OPTS}}": " ".join(toolchain_info.jvm_opt.to_list()),
        "{{TARGET_LABEL}}": "//:foo",
        "{{CLASSPATH}}": " ".join([x.path for x in ctx.attr.deps[0][JavaInfo].compilation_info.compilation_classpath.to_list()]),
        "{{BOOTCLASSPATH}}": " ".join([x.path for x in toolchain_info.bootclasspath.to_list()]),
        "{{PROCESSOR_CLASS_PATH}}": " ",  # .join([x.path for x in ctx.attr.plugins[0][JavaInfo].plugins.processor_jars.to_list()]),
        "{{PROCESSOR_CLASS_NAMES}}": " ",  #.join(ctx.attr.plugins[0][JavaInfo].plugins.processor_classes.to_list()),
        "{{SOURCES}}": " ".join([y.path for x in ctx.attr.srcs for y in x.files.to_list()]),
        "{{CHECKS}}": ",".join(ctx.attr.checks),
        "{{BIN_DIR}}": ctx.bin_dir.path,
        "{{BUiLD_FILE_DIR}}": ctx.build_file_path,
    }

    ctx.actions.expand_template(
        template = ctx.file._entry,
        output = out,
        substitutions = common_substitutions,
        is_executable = True,
    )

    java_args = [
        "-XX:-CompactStrings",
        "--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.resources=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED",
        "--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED",
        "--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED",
        "--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED",
        "--add-opens=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED",
        "--add-opens=java.base/java.nio=ALL-UNNAMED",
        "--add-opens=java.base/java.lang=ALL-UNNAMED",
        "--patch-module=java.compiler=external/remote_java_tools/java_tools/java_compiler.jar",
        "--patch-module=jdk.compiler=external/remote_java_tools/java_tools/jdk_compiler.jar",
    ]

    bootclasspath_args = ["--bootclasspath"] + [x.path for x in toolchain_info.bootclasspath.to_list()]
    sources_args = ["--sources"] + [y.path for x in ctx.attr.srcs for y in x.files.to_list()]
    target_label_args = [
        "--target_label",
        "//:refaster",
        "--output",
        "bazel-out/k8-fastbuild/refaster-output.jar",
    ]

    error_prone_patch = ctx.actions.declare_file("error-prone.patch")

    javacopts_args = [
        "--javacopts",
        "-XDcompilePolicy=simple",
        "-XepPatchChecks:" + ",".join(ctx.attr.checks),
        "-XepPatchLocation:" + error_prone_patch.dirname,
        "--",
    ]

    merged = java_common.merge([dep[java_common.provider] for dep in ctx.attr.deps])
    all_deps = [jar for jar in merged.transitive_deps.to_list()]

    classpath_args = ["--classpath"] + [x.path for x in all_deps]

    plugin_jars = [y for x in ctx.attr.plugins for y in x[JavaInfo].plugins.processor_jars.to_list()]
    processor_args = ["--processorpath"] + [y.path for y in plugin_jars] + ["--processors"] + [y for x in ctx.attr.plugins for y in x[JavaInfo].plugins.processor_classes.to_list()]

    java_executable = toolchain_info.java_runtime.java_executable_exec_path
    args = java_args + ["-jar", javabuilder.files.to_list()[0].path] + bootclasspath_args + sources_args + target_label_args + javacopts_args + classpath_args + processor_args

    ctx.actions.run_shell(
        command = java_executable + " $@",
        arguments = args,
        outputs = [error_prone_patch],
        inputs = [y for x in ctx.attr.srcs for y in x.files.to_list()] + all_deps + plugin_jars,
        tools = toolchain_info.tools.to_list() + toolchain_info.java_runtime.files.to_list() + javabuilder.files.to_list(),
    )

    return [
        DefaultInfo(
            files = depset([error_prone_patch]),
        ),
    ]

_refaster_runner = rule(
    implementation = _refaster_runner_impl,
    attrs = dict(
        deps = attr.label_list(),
        plugins = attr.label_list(),
        srcs = attr.label_list(
            allow_files = True,
        ),
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

def refaster(deps, srcs, checks, name, plugins = []):
    _refaster_runner(
        name = name,
        deps = deps,
        plugins = plugins,
        srcs = srcs,
        checks = checks,
    )
