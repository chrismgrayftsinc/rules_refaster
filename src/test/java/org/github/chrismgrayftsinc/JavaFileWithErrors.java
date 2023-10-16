package org.github.chrismgrayftsinc;

public class JavaFileWithErrors{
  public void a() {
    System.out.println("foo");
  }

  public void b() {
    try {
      a();
    } catch (Exception e) {
      return;
    }
  }
}
