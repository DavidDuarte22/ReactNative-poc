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

  # Swift-only — no ObjC++ wrappers, no codegen.
  s.source_files = "*.swift"

  # ExpoModulesCore provides the Module/ModulesProvider base classes
  # and the full JSI + TurboModule wiring. No install_modules_dependencies needed.
  s.dependency "ExpoModulesCore"
end
