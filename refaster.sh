#!/bin/bash

cd ../../../../..

{{JAVA_BIN}} -XX:-CompactStrings {{JAVA_OPTS}} -jar {{JAVA_BUILDER}} --bootclasspath {{BOOTCLASSPATH}} --sources {{SOURCES}} --target_label {{TARGET_LABEL}} --output bazel-out/k8-fastbuild/refaster-output.jar --javacopts -XDcompilePolicy=simple  -XepPatchChecks:{{CHECKS}} -XepPatchLocation:$BUILD_WORKSPACE_DIRECTORY -- --classpath {{CLASSPATH}} --reduce_classpath_mode JAVABUILDER_REDUCED --processorpath {{PROCESSOR_CLASS_PATH}}  --processors '{{PROCESSOR_CLASS_NAMES}}'

