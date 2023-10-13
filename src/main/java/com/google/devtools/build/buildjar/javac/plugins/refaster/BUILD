
java_library(
    name = "refaster",
    srcs = glob(["*.java"]),
    deps = [
        "//src/main/java/com/google/devtools/build/buildjar:bazel_buildjar",
        "@maven//:com_google_errorprone_error_prone_core",
        "@maven//:com_google_guava_guava",
    ],
    visibility = ["//:__subpackages__"],
)
