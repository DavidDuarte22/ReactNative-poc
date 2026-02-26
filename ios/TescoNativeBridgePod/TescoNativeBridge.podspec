require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "TescoNativeBridge"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/tesco/rn-poc"
  s.license      = "MIT"
  s.authors      = "Tesco Engineering"
  s.platforms    = { :ios => "15.1" }
  s.source       = { :git => "", :tag => s.version }

  # ObjC++ implementation files + pre-generated Codegen spec (committed to repo
  # so the build does not need a Codegen script phase at all).
  s.source_files = "*.{h,mm}", "codegen/*.{h,mm}"

  # Public headers: both the module interface and the pre-generated Codegen spec.
  s.public_header_files = "*.h", "codegen/*.h"

  # TypeScript spec is kept for reference but not compiled (JS file)
  s.preserve_paths = "NativeTescoNativeBridge.ts"

  # install_modules_dependencies sets up React-Core, ReactCommon, and all
  # required header search paths. The Codegen script phase it adds is a no-op
  # because we commit the generated files in codegen/ directly.
  install_modules_dependencies(s)
end
