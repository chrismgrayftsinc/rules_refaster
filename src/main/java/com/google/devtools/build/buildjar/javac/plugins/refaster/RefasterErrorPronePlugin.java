// Copyright 2011 The Bazel Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.google.errorprone;

import static java.util.Comparator.comparing;

import java.io.PrintWriter;
import com.sun.tools.javac.util.Log.WriterKind;
import com.google.errorprone.RefactoringCollection.RefactoringResult;
import com.google.errorprone.scanner.ErrorProneScannerTransformer;
import com.google.errorprone.RefactoringCollection;
import com.google.common.base.Stopwatch;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.devtools.build.buildjar.InvalidCommandLineException;
import com.google.devtools.build.buildjar.javac.plugins.BlazeJavaCompilerPlugin;
import com.google.devtools.build.buildjar.javac.statistics.BlazeJavacStatistics;
import com.google.errorprone.BaseErrorProneJavaCompiler;
import com.google.errorprone.ErrorProneAnalyzer;
import com.google.errorprone.ErrorProneError;
import com.google.errorprone.ErrorProneOptions;
import com.google.errorprone.InvalidCommandLineOptionException;
import com.google.errorprone.scanner.BuiltInCheckerSuppliers;
import com.google.errorprone.scanner.ScannerSupplier;
import com.sun.source.util.TaskEvent;
import com.sun.source.util.TaskEvent.Kind;
import com.sun.tools.javac.comp.AttrContext;
import com.sun.tools.javac.comp.Env;
import com.sun.tools.javac.main.JavaCompiler;
import com.sun.tools.javac.util.Context;
import com.sun.tools.javac.util.Log;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.io.File;

/**
 * A plugin for BlazeJavaCompiler that performs Error Prone analysis. Error Prone is a static
 * analysis framework that we use to perform some simple static checks on Java code.
 */
public final class RefasterErrorPronePlugin extends BlazeJavaCompilerPlugin {

  private final ScannerSupplier scannerSupplier;

  /**
   * Constructs an {@link ErrorPronePlugin} instance with the set of checks that are enabled as
   * errors in open-source Error Prone.
   */
  public RefasterErrorPronePlugin() {
    this(BuiltInCheckerSuppliers.errorChecks());
  }

  /**
   * Constructs an {@link ErrorPronePlugin} with the set of checks that are enabled in {@code
   * scannerSupplier}.
   */
  public RefasterErrorPronePlugin(ScannerSupplier scannerSupplier) {
    this.scannerSupplier = scannerSupplier;
  }

  private ErrorProneAnalyzer errorProneAnalyzer;
  private ErrorProneOptions epOptions;
  private ErrorProneTimings timings;
  private final Stopwatch elapsed = Stopwatch.createUnstarted();
  private RefactoringCollection refactoringCollection;

  // TODO(cushon): delete this shim after the next Error Prone update
  static class ErrorProneTimings {
    static Class<?> clazz;

    static {
      try {
        clazz = Class.forName("com.google.errorprone.ErrorProneTimings");
      } catch (ClassNotFoundException e) {
        // ignored
      }
    }

    private final Object instance;

    public ErrorProneTimings(Object instance) {
      this.instance = instance;
    }

    public static ErrorProneTimings instance(Context context) {
      Object instance = null;
      if (clazz != null) {
        try {
          instance = clazz.getMethod("instance", Context.class).invoke(null, context);
        } catch (ReflectiveOperationException e) {
          throw new LinkageError(e.getMessage(), e);
        }
      }
      return new ErrorProneTimings(instance);
    }

    @SuppressWarnings("unchecked") // reflection
    public Map<String, Duration> timings() {
      if (clazz == null) {
        return ImmutableMap.of();
      }
      try {
        return (Map<String, Duration>) clazz.getMethod("timings").invoke(instance);
      } catch (ReflectiveOperationException e) {
        throw new LinkageError(e.getMessage(), e);
      }
    }
  }

  /** Registers our message bundle. */
  public static void setupMessageBundle(Context context) {
    BaseErrorProneJavaCompiler.setupMessageBundle(context);
  }

  @Override
  public void processArgs(
      ImmutableList<String> standardJavacopts, ImmutableList<String> blazeJavacopts)
      throws InvalidCommandLineException {
    ImmutableList.Builder<String> epArgs = ImmutableList.<String>builder().addAll(blazeJavacopts);
    // allow javacopts that reference unknown error-prone checks
    epArgs.add("-XepIgnoreUnknownCheckNames");
    String absoluteBaseDirectory = new File(".").getAbsolutePath();
    for (String arg : blazeJavacopts) {
      if (arg.startsWith("-XepPatchLocation:")) {
        absoluteBaseDirectory = new File(arg.substring("-XepPatchLocation:".length())).getAbsolutePath();
      }
    }
    epArgs.add("-XepPatchLocation:" + absoluteBaseDirectory);
    processEpOptions(epArgs.build());
  }

  private void processEpOptions(List<String> args) throws InvalidCommandLineException {
    try {
      epOptions = ErrorProneOptions.processArgs(args);
    } catch (InvalidCommandLineOptionException e) {
      throw new InvalidCommandLineException(e.getMessage());
    }
  }

  @Override
  public void init(
      Context context,
      Log log,
      JavaCompiler compiler,
      BlazeJavacStatistics.Builder statisticsBuilder) {
    super.init(context, log, compiler, statisticsBuilder);

    setupMessageBundle(context);

    if (epOptions == null) {
      epOptions = ErrorProneOptions.empty();
    }
    
    refactoringCollection = RefactoringCollection.refactor(epOptions.patchingOptions(), context);
    CodeTransformer codeTransformer =
        epOptions
            .patchingOptions()
            .customRefactorer()
            .or(
                () -> {
                  ScannerSupplier toUse =
                      ErrorPronePlugins.loadPlugins(scannerSupplier, context)
                          .applyOverrides(epOptions);
                  Set<String> namedCheckers = epOptions.patchingOptions().namedCheckers();
                  if (!namedCheckers.isEmpty()) {
                    toUse = toUse.filter(bci -> namedCheckers.contains(bci.canonicalName()));
                  }
                  return ErrorProneScannerTransformer.create(toUse.get());
                })
            .get();
    timings = ErrorProneTimings.instance(context);
    errorProneAnalyzer = ErrorProneAnalyzer.createWithCustomDescriptionListener(
        codeTransformer, epOptions, context, refactoringCollection);
  }

  /** Run Error Prone analysis after performing dataflow checks. */
  @Override
  public void postFlow(Env<AttrContext> env) {
    elapsed.start();
    try {
      errorProneAnalyzer.finished(new TaskEvent(Kind.ANALYZE, env.toplevel, env.enclClass.sym));
      RefactoringResult refactoringResult;
      try {
        refactoringResult = refactoringCollection.applyChanges(env.toplevel.sourcefile.toUri());
      } catch (Exception e) {
        PrintWriter out = Log.instance(context).getWriter(WriterKind.ERROR);
        out.println(e.getMessage());
        out.flush();
        return;
      }
      if (refactoringResult.type() == RefactoringCollection.RefactoringResultType.CHANGED) {
        PrintWriter out = Log.instance(context).getWriter(WriterKind.NOTICE);
        out.println(refactoringResult.message());
        out.flush();
      }    } catch (ErrorProneError e) {
      e.logFatalError(log);
      // let the exception propagate to javac's main, where it will cause the compilation to
      // terminate with Result.ABNORMAL
      throw e;
    } finally {
      elapsed.stop();
    }
  }

  @Override
  public void finish() {
    
    statisticsBuilder.totalErrorProneTime(elapsed.elapsed());
    timings.timings().entrySet().stream()
        .sorted(comparing((Map.Entry<String, Duration> e) -> e.getValue()).reversed())
        .limit(10) // best-effort to stay under the action metric size limit
        .forEachOrdered((e) -> statisticsBuilder.addBugpatternTiming(e.getKey(), e.getValue()));
  }
}
