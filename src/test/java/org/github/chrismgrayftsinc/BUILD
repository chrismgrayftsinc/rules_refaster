
java_library(
    name = "java_file_with_errors",
    srcs = [
        "JavaFileWithErrors.java",
    ],
)

filegroup(
    name = "all_files",
    srcs = [
        "JavaFileWithErrors.java"
    ],
)

load("@rules_refaster//:refaster.bzl", "refaster")

refaster(
    name = "refaster",
    srcs = [
        ":all_files",
    ],
    checks = [
        "CatchingUnchecked",
        "DefaultCharset",
    ],
    deps = [
        ":java_file_with_errors",
    ],
)
