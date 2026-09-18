# Based on Homebrew/homebrew-core's molten-vk formula (BSD-2-Clause).
class MoltenVk < Formula
  desc "Vulkan graphics and compute on Metal with selected upstream fixes"
  homepage "https://github.com/KhronosGroup/MoltenVK"
  url "https://github.com/KhronosGroup/MoltenVK/archive/4aaf714aa1b3e78e26ecfcefa9c75e9a576c500b.tar.gz"
  version "1.4.3-dev.20260918"
  sha256 "f5512b679bbf642904d6be75fd9ef63cccd67d65138b88d32cc0cb679b5ca891"
  license "Apache-2.0"
  compatibility_version 1

  option "with-metal-private-api", "Enable MoltenVK's private Metal graphics interfaces"

  depends_on "cmake" => :build
  depends_on arch: :arm64
  depends_on macos: :tahoe
  depends_on xcode: ["26.0", :build]

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

  # Integrated, immutable diff of upstream PRs #2819, #2827, #2829, and #2822.
  # It intentionally excludes the local Makefile and all private research artifacts.
  patch :DATA

  def install
    resources.each do |res|
      res.stage(buildpath/"External"/res.name)
    end
    mv "External/SPIRV-Headers", "External/SPIRV-Tools/external/spirv-headers"

    system "cmake", "-S", "External/SPIRV-Tools", "-B", "External/SPIRV-Tools/build",
           *std_cmake_args, "-DSPIRV_SKIP_TESTS=ON", "-DSPIRV_WERROR=OFF"
    system "cmake", "--build", "External/SPIRV-Tools/build"

    architecture = %w[ARCHS=arm64 ONLY_ACTIVE_ARCH=NO EXCLUDED_ARCHS= MACOSX_DEPLOYMENT_TARGET=26.0]
    xcodebuild(*architecture, "-configuration", "Release", "-sdk", "macosx",
               "-project", "ExternalDependencies.xcodeproj",
               "-scheme", "ExternalDependencies-macOS",
               "-derivedDataPath", "#{buildpath}/External/build",
               "SYMROOT=#{buildpath}/External/build", "OBJROOT=#{buildpath}/External/build",
               "build")

    definitions = %w[MVK_CONFIG_LOG_LEVEL=MVK_CONFIG_LOG_LEVEL_NONE]
    definitions << "MVK_USE_METAL_PRIVATE_API=1" if build.with?("metal-private-api")
    xcodebuild(*architecture, "-configuration", "Release", "-sdk", "macosx",
               "-project", "MoltenVKPackaging.xcodeproj",
               "-scheme", "MoltenVK Package (macOS only)",
               "-derivedDataPath", "#{buildpath}/build",
               "SYMROOT=#{buildpath}/build", "OBJROOT=#{buildpath}/build",
               "GCC_PREPROCESSOR_DEFINITIONS=${inherited} #{definitions.join(" ")}",
               "build")

    (libexec/"lib").install "External/build/Release/libSPIRVCross.a",
                          "External/build/Release/libSPIRVTools.a"
    (libexec/"include").install "External/SPIRV-Cross/include/spirv_cross",
                              "External/SPIRV-Tools/include/spirv-tools",
                              "External/Vulkan-Headers/include/vulkan",
                              "External/Vulkan-Headers/include/vk_video"

    frameworks.install "Package/Release/MoltenVK/static/MoltenVK.xcframework"
    lib.install "Package/Release/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib",
                "build/Release/libMoltenVK.a"
    include.install "MoltenVK/MoltenVK/API" => "MoltenVK"

    bin.install "Package/Release/MoltenVKShaderConverter/Tools/MoltenVKShaderConverter"
    frameworks.install "Package/Release/MoltenVKShaderConverter/MoltenVKShaderConverter.xcframework"
    include.install "Package/Release/MoltenVKShaderConverter/include/MoltenVKShaderConverter"

    inreplace "MoltenVK/icd/MoltenVK_icd.json", "./libMoltenVK.dylib",
              (lib/"libMoltenVK.dylib").relative_path_from(prefix/"etc/vulkan/icd.d")
    (prefix/"etc/vulkan").install "MoltenVK/icd" => "icd.d"
    pkgshare.install "LICENSE"
  end

  def caveats
    <<~EOS
      This is the same-name replacement for homebrew/core/molten-vk.
      The four included upstream patches are correctness fixes; a RIFE speedup
      and M5 Neural Accelerator use have not been demonstrated.
      The optional private Metal interfaces affect graphics compatibility,
      not cooperative-matrix or TensorOps support.
    EOS
  end

  test do
    require "json"
    manifest = prefix/"etc/vulkan/icd.d/MoltenVK_icd.json"
    driver = JSON.parse(manifest.read).fetch("ICD").fetch("library_path")
    assert_equal (lib/"libMoltenVK.dylib").realpath, (manifest.dirname/driver).realpath

    (testpath/"test.c").write <<~C
      #include <vulkan/vulkan.h>
      #include <stdio.h>
      #include <stdlib.h>
      int main(void) {
        VkApplicationInfo app = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                                  .pApplicationName = "Homebrew MoltenVK test",
                                  .apiVersion = VK_API_VERSION_1_0 };
        VkInstanceCreateInfo info = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                                      .pApplicationInfo = &app };
        VkInstance instance = VK_NULL_HANDLE;
        VkResult result = vkCreateInstance(&info, NULL, &instance);
        if (result != VK_SUCCESS) {
          fprintf(stderr, "vkCreateInstance failed: %d\\n", result);
          return 1;
        }
        uint32_t count = 0;
        result = vkEnumeratePhysicalDevices(instance, &count, NULL);
        if (result != VK_SUCCESS || count == 0) {
          fprintf(stderr, "No usable Vulkan physical device: %d\\n", result);
          vkDestroyInstance(instance, NULL);
          return 1;
        }
        VkPhysicalDevice *devices = calloc(count, sizeof(*devices));
        if (!devices) { vkDestroyInstance(instance, NULL); return 1; }
        result = vkEnumeratePhysicalDevices(instance, &count, devices);
        if (result == VK_SUCCESS) {
          for (uint32_t i = 0; i < count; ++i) {
            VkPhysicalDeviceProperties props;
            vkGetPhysicalDeviceProperties(devices[i], &props);
            printf("Device: %s\\n", props.deviceName);
          }
        }
        free(devices);
        vkDestroyInstance(instance, NULL);
        return result == VK_SUCCESS ? 0 : 1;
      }
    C
    system ENV.cc, "test.c", "-o", "test", "-I#{libexec}/include",
           "-L#{lib}", "-Wl,-rpath,#{lib}", "-lMoltenVK"
    system "./test"
  end
end

__END__
diff --git a/Docs/Whats_New.md b/Docs/Whats_New.md
index b8b4c0b5..69467bd9 100644
--- a/Docs/Whats_New.md
+++ b/Docs/Whats_New.md
@@ -25,6 +25,9 @@ Released TBD
 - Fix inconsistent image `memoryTypeBits` when `VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT` is used.
 - Fix shader stage interface matching of 16-bit floating point variables.
 - Fix spurious warning about blending on attachment formats that do not support it.
+- Fix `OpArrayLength` returning 0 for buffers bound with `vkCmdPushDescriptorSet()`, which never populated the implicit buffer-sizes buffer.
+- Fix `VkDeviceMemory` imported from a `MTLTexture` not backing the image bound to it, and over-releasing that texture.
+- Fix leak of the `MTLBuffer` of a host-coherent `VkDeviceMemory` that also holds a `MTLTexture`.
 
 
 
@@ -2840,4 +2843,3 @@ MoltenVK 1.0.0
 Released 2018/02/26
 
 Initial open-source release!
-
diff --git a/MoltenVK/MoltenVK/Commands/MVKCmdPipeline.mm b/MoltenVK/MoltenVK/Commands/MVKCmdPipeline.mm
index 90929544..d5e3e8e0 100644
--- a/MoltenVK/MoltenVK/Commands/MVKCmdPipeline.mm
+++ b/MoltenVK/MoltenVK/Commands/MVKCmdPipeline.mm
@@ -104,6 +104,10 @@
 	for (uint32_t i = 0; i < imageMemoryBarrierCount; i++) {
 		_barriers.emplace_back(pImageMemoryBarriers[i], srcStageMask, dstStageMask);
 	}
+	if (_barriers.empty()) {
+		VkMemoryBarrier barrier = {VK_STRUCTURE_TYPE_MEMORY_BARRIER};
+		_barriers.emplace_back(barrier, srcStageMask, dstStageMask);
+	}
 
 	return VK_SUCCESS;
 }
diff --git a/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.h b/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.h
index 76ca7884..07b66381 100644
--- a/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.h
+++ b/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.h
@@ -551,6 +551,7 @@ protected:
 	uint32_t _multiviewPassIndex;
     uint32_t _flushCount;
 	MVKCommandUse _mtlComputeEncoderUse;
+	uint32_t _mtlComputeEncoderStages;
 	MVKCommandUse _mtlBlitEncoderUse;
 	bool _isRenderingEntireAttachment;
 };
diff --git a/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.mm b/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.mm
index 8c24debb..fc72d985 100644
--- a/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.mm
+++ b/MoltenVK/MoltenVK/Commands/MVKCommandBuffer.mm
@@ -749,9 +749,10 @@ static MVKBarrierStage commandUseToBarrierStage(MVKCommandUse use) {
 	}
 
 	if (_mtlComputeEncoder) {
-		MVKBarrierStage stage = commandUseToBarrierStage(_mtlComputeEncoderUse);
-		if (stage != kMVKBarrierStageNone) {
-			barrierUpdate(stage, _mtlComputeEncoder);
+		for (int stage = 0; stage < kMVKBarrierStageCount; ++stage) {
+			if (mvkIsAnyFlagEnabled(_mtlComputeEncoderStages, 1 << stage)) {
+				barrierUpdate((MVKBarrierStage)stage, _mtlComputeEncoder);
+			}
 		}
 	}
 
@@ -1063,6 +1064,7 @@ static MVKBarrierStage commandUseToBarrierStage(MVKCommandUse use) {
 	if (_mtlComputeEncoder && _cmdBuffer->_hasStageCounterTimestampCommand) { [_mtlComputeEncoder updateFence: getStageCountersMTLFence()]; }
 	endMetalEncoding(_mtlComputeEncoder);
 	_mtlComputeEncoderUse = kMVKCommandUseNone;
+	_mtlComputeEncoderStages = 0;
 
 	if (_mtlBlitEncoder && _cmdBuffer->_hasStageCounterTimestampCommand) { [_mtlBlitEncoder updateFence: getStageCountersMTLFence()]; }
 	endMetalEncoding(_mtlBlitEncoder);
@@ -1109,6 +1111,10 @@ static bool shouldStartNewEncoder(MVKCommandUse prev, MVKCommandUse next) {
 	if (_mtlComputeEncoderUse != cmdUse) {
 		needWaits = true;
 		_mtlComputeEncoderUse = cmdUse;
+		MVKBarrierStage stage = commandUseToBarrierStage(cmdUse);
+		if (stage != kMVKBarrierStageNone) {
+			mvkEnableFlags(_mtlComputeEncoderStages, 1 << stage);
+		}
 		_cmdBuffer->setMetalObjectLabel(_mtlComputeEncoder, mvkMTLComputeCommandEncoderLabel(cmdUse));
 	}
 	if (needWaits) {
@@ -1350,6 +1356,7 @@ static bool shouldStartNewEncoder(MVKCommandUse prev, MVKCommandUse next) {
 	_mtlRenderEncoder = nil;
 	_mtlComputeEncoder = nil;
 	_mtlComputeEncoderUse = kMVKCommandUseNone;
+	_mtlComputeEncoderStages = 0;
 	_mtlBlitEncoder = nil;
 	_mtlBlitEncoderUse = kMVKCommandUseNone;
 	_pEncodingContext = nullptr;
diff --git a/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.h b/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.h
index 25e6017b..0a98c512 100644
--- a/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.h
+++ b/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.h
@@ -434,6 +434,9 @@ class MVKCommandEncoderState {
 	/** Get the encoder state associated with the given bind point, or nullptr if the bindPoint isn't supported. */
 	MVKVulkanCommonEncoderState* getVkEncoderState(VkPipelineBindPoint bindPoint);
 
+	/** Regenerates and invalidates the implicit buffer data derived from the push descriptor set after its contents change. */
+	void refreshPushDescriptorSet(VkPipelineBindPoint bindPoint, MVKPipelineLayout* layout, uint32_t set);
+
 public:
 	/** Get a reference to the Vulkan state shared between graphics and compute.  Read-only, use methods on this class (which will invalidate associated Metal state) to modify. */
 	const MVKVulkanSharedCommandEncoderState&   vkShared()   const { return _vkShared; }
diff --git a/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.mm b/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.mm
index 7d16b94e..5d146eb2 100644
--- a/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.mm
+++ b/MoltenVK/MoltenVK/Commands/MVKCommandEncoderState.mm
@@ -638,13 +638,18 @@ static void bindMetalResources(id<MTLCommandEncoder> encoder,
                                MVKStageResourceBits& exists,
                                MVKStageResourceBindings& bindings,
                                const MVKResourceBinder& RESTRICT binder) {
-	// Clear descriptor set resource use bitarray for new sets and bind them
+	// Clear descriptor set resource use bitarray for new sets.
 	MVKStaticBitSet<kMVKMaxDescriptorSetCount> setsNeeded = resources.resources.descriptorSetData.clearingAllIn(exists.descriptorSetData);
 	exists.descriptorSetData |= resources.resources.descriptorSetData;
 	for (size_t idx : setsNeeded) {
-		MVKDescriptorSet* set = common._descriptorSets[idx];
 		const MVKDescriptorSetLayout* layout = common._layout->getDescriptorSetLayout(idx);
 		bindings.descriptorSetResourceUse[idx].resizeAndClear(layout->bindings().size());
+	}
+
+	// Helper commands can overwrite buffer bindings without changing descriptor set resource use.
+	// Let the buffer binding cache restore argument buffers only when their bindings have changed.
+	for (size_t idx : resources.resources.descriptorSetData) {
+		MVKDescriptorSet* set = common._descriptorSets[idx];
 		bindBuffer(encoder, set->gpuBufferObject, set->gpuBufferOffset, idx, exists, bindings, binder);
 	}
 
@@ -1782,21 +1787,39 @@ static void invalidateImplicitBuffer(MVKCommandEncoderState& state, VkPipelineBi
 	}
 }
 
+void MVKCommandEncoderState::refreshPushDescriptorSet(VkPipelineBindPoint bindPoint, MVKPipelineLayout* layout, uint32_t set) {
+	// The push descriptor set's contents changed, so the implicit buffer data derived from
+	// descriptor contents (buffer sizes for OpArrayLength, texture swizzles) must be regenerated
+	// from it and rebound before the next draw or dispatch, exactly as vkCmdBindDescriptorSets does.
+	// Push descriptor sets carry no dynamic offsets.
+	if (bindPoint == VK_PIPELINE_BIND_POINT_GRAPHICS) {
+		MVKDescriptorSet* pushSet = &_vkGraphics._pushDescriptor;
+		_vkGraphics.bindDescriptorSets(layout, set, 1, &pushSet, 0, nullptr);
+	} else if (bindPoint == VK_PIPELINE_BIND_POINT_COMPUTE) {
+		MVKDescriptorSet* pushSet = &_vkCompute._pushDescriptor;
+		_vkCompute.bindDescriptorSets(layout, set, 1, &pushSet, 0, nullptr);
+	}
+	applyToActiveMTLState(bindPoint, [](auto& mtl){ invalidateDescriptorSetImplicitBuffers(mtl); });
+}
+
 void MVKCommandEncoderState::pushDescriptorSet(VkPipelineBindPoint bindPoint, MVKPipelineLayout* layout, uint32_t set, uint32_t writeCount, const VkWriteDescriptorSet* writes) {
 	assert(layout->pushDescriptor() == set);
 	if (MVKVulkanCommonEncoderState* state = getVkEncoderState(bindPoint)) [[likely]] {
 		MVKDescriptorSetLayout* dsl = layout->getDescriptorSetLayout(set);
 		state->ensurePushDescriptorSize(dsl->cpuSize());
 		mvkPushDescriptorSet(state->_pushDescriptor.cpuBuffer, dsl, writeCount, writes);
+		refreshPushDescriptorSet(bindPoint, layout, set);
 	}
 }
 
 void MVKCommandEncoderState::pushDescriptorSet(MVKDescriptorUpdateTemplate* updateTemplate, MVKPipelineLayout* layout, uint32_t set, const void* data) {
 	assert(layout->pushDescriptor() == set);
-	if (MVKVulkanCommonEncoderState* state = getVkEncoderState(updateTemplate->getBindPoint())) [[likely]] {
+	VkPipelineBindPoint bindPoint = updateTemplate->getBindPoint();
+	if (MVKVulkanCommonEncoderState* state = getVkEncoderState(bindPoint)) [[likely]] {
 		MVKDescriptorSetLayout* dsl = layout->getDescriptorSetLayout(set);
 		state->ensurePushDescriptorSize(dsl->cpuSize());
 		mvkPushDescriptorSetTemplate(state->_pushDescriptor.cpuBuffer, dsl, updateTemplate, data);
+		refreshPushDescriptorSet(bindPoint, layout, set);
 	}
 }
 
diff --git a/MoltenVK/MoltenVK/GPUObjects/MVKDeviceMemory.mm b/MoltenVK/MoltenVK/GPUObjects/MVKDeviceMemory.mm
index e6e7786b..faf524a3 100644
--- a/MoltenVK/MoltenVK/GPUObjects/MVKDeviceMemory.mm
+++ b/MoltenVK/MoltenVK/GPUObjects/MVKDeviceMemory.mm
@@ -483,14 +483,17 @@
 			setConfigurationResult(reportError(VK_ERROR_INITIALIZATION_FAILED, "vkAllocateMemory(): External memory requires a dedicated VkImage when a export operation will be done."));
 			return;
 		}
-		auto& xmProps = getPhysicalDevice()->getExternalImageProperties(dedicatedImage->getVkFormat(), VK_EXTERNAL_MEMORY_HANDLE_TYPE_MTLTEXTURE_BIT_EXT);
-		// Not all texture formats allow to exporting. Vulkan formats that are emulated through the use of multiple MTLTextures
-		// cannot be exported as a single MTLTexture, and therefore will have exporting forbidden.
-		if (!(xmProps.externalMemoryFeatures & VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT)) {
-			setConfigurationResult(reportError(VK_ERROR_INITIALIZATION_FAILED, "vkAllocateMemory(): VkImage's VkFormat does not allow exports."));
-		} else {
-			// Make sure allocation happens at creation time since we may need to export the memory before usage
-			_mtlTexture = [dedicatedImage->getMTLTexture() retain];
+		// An imported texture is already the memory; only an exportable one is made here.
+		if ( !_mtlTexture ) {
+			auto& xmProps = getPhysicalDevice()->getExternalImageProperties(dedicatedImage->getVkFormat(), VK_EXTERNAL_MEMORY_HANDLE_TYPE_MTLTEXTURE_BIT_EXT);
+			// Not all texture formats allow to exporting. Vulkan formats that are emulated through the use of multiple MTLTextures
+			// cannot be exported as a single MTLTexture, and therefore will have exporting forbidden.
+			if (!(xmProps.externalMemoryFeatures & VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT)) {
+				setConfigurationResult(reportError(VK_ERROR_INITIALIZATION_FAILED, "vkAllocateMemory(): VkImage's VkFormat does not allow exports."));
+			} else {
+				// Make sure allocation happens at creation time since we may need to export the memory before usage
+				_mtlTexture = [dedicatedImage->getMTLTexture() retain];
+			}
 		}
 		requiresDedicated = true;
 	}
@@ -511,7 +514,10 @@
 	if (_externalMemoryHandleType & VK_EXTERNAL_MEMORY_HANDLE_TYPE_MTLTEXTURE_BIT_EXT) {
 		[_mtlTexture release];
 		_mtlTexture = nil;
-	} else if (id<MTLBuffer> buf = _mtlBuffer) {
+	}
+
+	// Memory holding a texture can hold a buffer as well, when it is host coherent.
+	if (id<MTLBuffer> buf = _mtlBuffer) {
 		_mtlBuffer = nil;
 		_device->removeResidency(buf);
 		_device->getLiveResources().remove(buf);
diff --git a/MoltenVK/MoltenVK/GPUObjects/MVKImage.mm b/MoltenVK/MoltenVK/GPUObjects/MVKImage.mm
index 1c180417..2b394922 100644
--- a/MoltenVK/MoltenVK/GPUObjects/MVKImage.mm
+++ b/MoltenVK/MoltenVK/GPUObjects/MVKImage.mm
@@ -80,7 +80,7 @@ static uint32_t mvkGetMTLTextureIOSurfaceID(id<MTLTexture> tex) {
         id<MTLTexture> tex;
         // Use imported texture if we are binding to a VkDeviceMemory that was created with an import operation
         if (dvcMem && (dvcMem->_externalMemoryHandleType & VK_EXTERNAL_MEMORY_HANDLE_TYPE_MTLTEXTURE_BIT_EXT) && dvcMem->_mtlTexture) {
-            tex = dvcMem->_mtlTexture;
+            tex = [dvcMem->_mtlTexture retain];		// retained
         } else if (_image->_ioSurface) {
             tex = [_image->getMTLDevice()
                    newTextureWithDescriptor: mtlTexDesc
