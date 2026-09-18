# Based on Homebrew/homebrew-core's molten-vk formula (BSD-2-Clause).
class MoltenVk < Formula
  desc "Vulkan on Metal with selected fixes and private API support"
  homepage "https://github.com/DavidBrockmeier/MoltenVK"
  url "https://github.com/DavidBrockmeier/MoltenVK.git",
      revision: "9554875159bc1945875721bef35bec197cac8bcb"
  version "1.4.3-dev.20260918"
  license "Apache-2.0"
  revision 2
  compatibility_version 1

  option "with-metal-private-api", "Compatibility flag; private Metal APIs are always enabled"

  depends_on xcode: ["26.0", :build]
  depends_on arch: :arm64
  depends_on macos: :tahoe

  uses_from_macos "python" => :build

  # Match ExternalRevisions at the source commit above; do not float dependency HEADs.
  resource "SPIRV-Cross" do
    url "https://github.com/KhronosGroup/SPIRV-Cross.git",
        revision: "6c09849fe88c48eaed08413aa022aaa136a3a057"
    version "6c09849fe88c48eaed08413aa022aaa136a3a057"
  end

  resource "SPIRV-Headers" do
    url "https://github.com/KhronosGroup/SPIRV-Headers.git",
        revision: "29981f65241605e08b0ede4cfeb999fe3b723c6a"
    version "29981f65241605e08b0ede4cfeb999fe3b723c6a"
  end

  resource "SPIRV-Tools" do
    url "https://github.com/KhronosGroup/SPIRV-Tools.git",
        revision: "0d6fd73ca73830ccab5fa1f00ed5ed40124e2c55"
    version "0d6fd73ca73830ccab5fa1f00ed5ed40124e2c55"
  end

  resource "Volk" do
    url "https://github.com/zeux/volk.git",
        revision: "776893306c5d3b22b6185b5d4a258b81d94572bf"
    version "776893306c5d3b22b6185b5d4a258b81d94572bf"
  end

  resource "Vulkan-Headers" do
    url "https://github.com/KhronosGroup/Vulkan-Headers.git",
        revision: "e3b1eec08173d6b825cd3ac88c885a63b621504a"
    version "e3b1eec08173d6b825cd3ac88c885a63b621504a"
  end

  resource "Vulkan-Tools" do
    url "https://github.com/KhronosGroup/Vulkan-Tools.git",
        revision: "8c66b352925cb771f793a4d3220b1321ae0febf1"
    version "8c66b352925cb771f793a4d3220b1321ae0febf1"
  end

  resource "cereal" do
    url "https://github.com/USCiLab/cereal.git",
        revision: "a56bad8bbb770ee266e930c95d37fff2a5be7fea"
    version "a56bad8bbb770ee266e930c95d37fff2a5be7fea"
  end

  def install
    resources.each do |res|
      res.stage(buildpath/"External"/res.name)
    end
    system "python3", "Scripts/prepare_dependencies.py", "--offline"

    xcodebuild "-workspace", "MoltenVK.xcworkspace", "-scheme", "MoltenVK",
               "-configuration", "Release", "-sdk", "macosx",
               "-destination", "generic/platform=macOS",
               "-derivedDataPath", "#{buildpath}/build/DerivedData",
               "MVK_USE_METAL_PRIVATE_API=1",
               "MVK_SOURCE_REVISION=9554875159bc1945875721bef35bec197cac8bcb",
               "GCC_PREPROCESSOR_DEFINITIONS=${inherited} MVK_CONFIG_LOG_LEVEL=MVK_CONFIG_LOG_LEVEL_NONE",
               "build"

    products = buildpath/"build/DerivedData/Build/Products/Release"
    (libexec/"lib").install products/"libSPIRVCross.a", products/"libSPIRVTools.a"
    (libexec/"include/spirv_cross").install Dir["External/SPIRV-Cross/*.hpp"],
                                          "External/SPIRV-Cross/GLSL.std.450.h",
                                          "External/SPIRV-Cross/spirv.h",
                                          "External/SPIRV-Cross/spirv_cross_c.h"
    (libexec/"include").install "External/SPIRV-Tools/include/spirv-tools",
                              "External/Vulkan-Headers/include/vulkan",
                              "External/Vulkan-Headers/include/vk_video"

    frameworks.install "Package/Release/MoltenVK/static/MoltenVK.xcframework"
    lib.install "Package/Release/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib",
                products/"libMoltenVK.a"
    include.install "MoltenVK/MoltenVK/API" => "MoltenVK"

    bin.install "Package/Release/MoltenVKShaderConverter/Tools/MoltenVKShaderConverter",
                products/"MoltenVKProbe"
    frameworks.install "Package/Release/MoltenVKShaderConverter/MoltenVKShaderConverter.xcframework"
    include.install "Package/Release/MoltenVKShaderConverter/include/MoltenVKShaderConverter"

    inreplace "MoltenVK/icd/MoltenVK_icd.json", "./libMoltenVK.dylib",
              (lib/"libMoltenVK.dylib").relative_path_from(prefix/"etc/vulkan/icd.d")
    (prefix/"etc/vulkan").install "MoltenVK/icd" => "icd.d"
    pkgshare.install "LICENSE"
  end

  test do
    require "json"
    manifest = prefix/"etc/vulkan/icd.d/MoltenVK_icd.json"
    driver = JSON.parse(manifest.read).fetch("ICD").fetch("library_path")
    assert_equal (lib/"libMoltenVK.dylib").realpath, (manifest.dirname/driver).realpath

    (testpath/"headers.cpp").write <<~CPP
      #include <SPIRVToMSLConverter.h>
      int main() { return 0; }
    CPP
    system ENV.cxx, "-std=c++17", "-fsyntax-only", "headers.cpp",
           "-I#{include}/MoltenVKShaderConverter", "-I#{libexec}/include/spirv_cross"
    system bin/"MoltenVKProbe", lib/"libMoltenVK.dylib"
  end
end
