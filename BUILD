exports_files(["refaster.sh"])

java_binary(
    name = "RefasterJavaBuilder",
    runtime_deps = [
        "//src/main/java/com/google/devtools/build/buildjar/javac/plugins/refaster",
        "//src/main/java/com/google/devtools/build/buildjar",
        "@maven//:io_github_java_diff_utils_java_diff_utils",
    ],
    main_class = "com.google.devtools.build.buildjar.RefasterJavaBuilder",
    visibility = ["//visibility:public"],
)
