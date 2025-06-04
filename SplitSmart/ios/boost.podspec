Pod::Spec.new do |s|
  s.name = 'boost'
  s.version = '1.76.0'
  s.license = 'MIT'
  s.homepage = 'http://www.boost.org'
  s.summary = 'Boost provides free peer-reviewed portable C++ source libraries.'
  s.authors = 'Rene Rivera', 'David Abrahams', 'Peter Dimov', 'Glen Fernandes', 'Marshall Clow', 'Nicolai Josuttis', 'John Maddock', 'Thorsten Ottosen', 'Pavel Vozenilek', 'Vicente J. Botet Escriba'
  
  # Use the local boost source file we downloaded
  s.source = { 
    :http => 'file:' + File.expand_path('boost_1_76_0_correct.tar.bz2', __dir__),
    :sha256 => 'f0397ba6e982c4450f27bf32a2a83292aba035b827a5623a14636ea583318c41',
    :flatten => true
  }
  
  s.prepare_command = "mkdir -p boost && tar xjf boost_1_76_0_correct.tar.bz2 --strip-components=1 -C boost"
  s.platform = :ios
  s.ios.deployment_target = '13.0'
  s.requires_arc = false
  
  # Header files
  s.header_mappings_dir = 'boost'
  s.header_dir = 'boost'
  
  # Ensure the pod is built as a static library
  s.static_framework = true
  
  # Include all header files
  s.source_files = 'boost/boost/**/*.hpp', 'boost/boost/**/*.h', 'boost/boost/**/*.ipp'
  s.preserve_paths = 'boost'
  
  # Build settings
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/boost',
    'OTHER_LDFLAGS' => '-lstdc++',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
  
  s.libraries = 'c++'
end
