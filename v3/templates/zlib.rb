class Zlib < Formula
  desc "General-purpose lossless data-compression library (x86_64_ohos source build)"
  homepage "https://zlib.net/"
  url "file:///opt/src-cache/zlib-1.3.1.tar.gz"
  sha256 "@SHA256@"
  license "Zlib"

  def install
    ENV["CC"] = "ohos-clang"
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <assert.h>
      #include <zlib.h>
      int main()
      {
        assert(zlibVersion()[0] == '1');
        return 0;
      }
    C
    system "ohos-clang", "test.c", "-I#{include}", "-L#{lib}", "-lz", "-o", "test"
    system "./test"
  end
end
