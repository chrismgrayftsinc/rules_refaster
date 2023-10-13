workspace(package = "rules_refaster")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

RULES_JVM_EXTERNAL_TAG = "4.4.2"
RULES_JVM_EXTERNAL_SHA = "735602f50813eb2ea93ca3f5e43b1959bd80b213b836a07a62a29d757670b77b"
http_archive(
    name = "rules_jvm_external",
    strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
    sha256 = RULES_JVM_EXTERNAL_SHA,
    url = "https://github.com/bazelbuild/rules_jvm_external/archive/%s.zip" % RULES_JVM_EXTERNAL_TAG,
)

load("@rules_jvm_external//:repositories.bzl", "rules_jvm_external_deps")
rules_jvm_external_deps()
load("@rules_jvm_external//:setup.bzl", "rules_jvm_external_setup")
rules_jvm_external_setup()


load("@rules_jvm_external//:defs.bzl", "maven_install")
load("@rules_jvm_external//:specs.bzl", "maven")
load("@rules_jvm_external//:defs.bzl", "artifact")

maven_install(
    artifacts = [
        "com.google.guava:guava:28.0-jre",
        "com.google.errorprone:error_prone_core:2.21.0",
        "io.github.java-diff-utils:java-diff-utils:4.0",
    ],
    fetch_sources = True,
    maven_install_json = "//:maven_install.json",
    repositories = [
        "https://repo1.maven.org/maven2",
    ],
)

load("@maven//:defs.bzl", "pinned_maven_install")

pinned_maven_install()
