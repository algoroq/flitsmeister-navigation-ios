Pod::Spec.new do |s|
  s.name = "MapboxNavigationUI"
  s.version = "1.1.4"
  s.summary = "Mapbox Navigation UI wrapper."
  s.description = <<-DESC
  MapboxNavigationUI makes it easy to open a navigation UI in your project.
                   DESC
  s.homepage = "https://swcode.io"
  s.license = { :type => "ISC", :file => "LICENSE.md" }
  s.author = { "SWCode" => "info@swcode.io" }

  s.swift_version = "5"
  s.ios.deployment_target = "11.0"

  s.source = { :git => "https://github.com/sw-code/flitsmeister-navigation-ios.git", :tag => "#{s.version.to_s}" }
  s.source_files = ["MapboxNavigationUI/**/*.{h,m,swift}"]

  s.requires_arc = true
  s.module_name = "MapboxNavigationUI"

  s.dependency "MapboxCoreNavigation", "~> 1.1.3"
  s.dependency "MapboxNavigation", "~> 1.1.3"
  s.dependency "MapboxDirections", "~> 1.1.3"
end
