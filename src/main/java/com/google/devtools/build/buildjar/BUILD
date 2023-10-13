
java_library(
    name = "buildjar",
    srcs = glob(["*.java"]),
    deps = [
        "//src/main/java/com/google/devtools/build/buildjar/javac/plugins/refaster",
        "@maven//:com_google_guava_guava",
        ":bazel_buildjar",
    ],
    visibility = ["//:__subpackages__"],
)

java_import(
    name = "bazel_buildjar",
    jars = [
        "@bazel_tools//tools/jdk:JavaBuilder_deploy.jar",
    ],
    visibility = ["//:__subpackages__"],
)
