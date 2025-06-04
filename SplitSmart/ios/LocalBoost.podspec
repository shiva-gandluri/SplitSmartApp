Pod::Spec.new do |s|
  s.name         = "LocalBoost"
  s.version      = "1.76.0"
  s.summary      = 'Boost C++ Libraries' 
  s.homepage     = 'http://www.boost.org/'
  s.license      = { :type => 'Boost Software License', :file => 'LICENSE_1_0.txt' }
  s.authors      = 'Rene Rivera', 'David Abrahams', 'Peter Dimov', 'Glen Fernandes', 'Marshall Clow', 'Nicolai Josuttis', 'John Maddock', 'Thorsten Ottosen', 'Pavel Vozenilek', 'Vicente J. Botet Escriba'
  
  # Use the local boost source
  s.source = { :http => 'file:' + __dir__ + '/boost_1_76_0.tar.bz2', :type => 'tar', :flatten => true }
  
  s.platform = :ios
  s.ios.deployment_target = '13.0'
  s.compiler_flags = '-std=c++17 -stdlib=libc++ -Wno-documentation'
  
  s.preserve_paths = 'boost'
  s.header_dir = 'boost'
  
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/boost",
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => ['-std=c++17']
  }
  
  s.source_files = 'boost/boost/**/*.hpp', 'boost/boost/**/*.h', 'boost/boost/**/*.inl'
  s.preserve_paths = 'boost/boost'
end
