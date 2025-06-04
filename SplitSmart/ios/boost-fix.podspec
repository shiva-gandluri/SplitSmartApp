Pod::Spec.new do |spec|
  spec.name = 'boost-fix'
  spec.version = '1.76.0'
  spec.license = { :type => 'Boost Software License', :file => "LICENSE_1_0.txt" }
  spec.homepage = 'http://www.boost.org'
  spec.summary = 'Boost provides free peer-reviewed portable C++ source libraries.'
  spec.authors = 'Rene Rivera', 'David Abrahams', 'Peter Dimov', 'Glen Fernandes', 'Marshall Clow', 'Nicolai Josuttis', 'John Maddock', 'Thorsten Ottosen', 'Pavel Vozenilek', 'Vicente J. Botet Escriba'
  
  # Use the local boost source
  spec.preserve_paths = 'boost'
  spec.source = { 
    :http => 'https://boostorg.jfrog.io/artifactory/main/release/1.76.0/source/boost_1_76_0.tar.bz2',
    :sha256 => '79e6d3f986444e5a80afbeccdaf2d1c1cf964baa8d766d20859d653a16c39848'
  }
  
  spec.platform = :ios
  spec.ios.deployment_target = '13.0'
  
  # Header files are not needed for the pod to be installed
  spec.header_mappings_dir = 'boost'
  spec.header_dir = 'boost'
  spec.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => ['-std=c++17']
  }
  
  # No source files - we're just using the headers
  spec.source_files = 'boost/boost/**/*.hpp', 'boost/boost/**/*.h', 'boost/boost/**/*.inl'
  spec.preserve_paths = 'boost/boost'
end
