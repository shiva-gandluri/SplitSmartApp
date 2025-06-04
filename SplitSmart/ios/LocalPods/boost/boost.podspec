Pod::Spec.new do |s|
  s.name         = 'boost'
  s.version      = '1.76.0'
  s.summary      = 'Boost provides free peer-reviewed portable C++ source libraries.'
  s.homepage     = 'http://www.boost.org/'
  s.license      = 'Boost Software License'
  s.authors      = 'Rene Rivera', 'David Abrahams', 'Peter Dimov', 'Glenn Rice', 'Marshall Clow'
  
  # Using a direct download link that should work better
  s.source = {
    :http => 'https://boostorg.jfrog.io/artifactory/main/release/1.76.0/source/boost_1_76_0.tar.bz2',
    :sha256 => '79e6d3f986444e5a80afbeccdaf2d1c1cf964baa8d766d20859d653a16c39848'
  }
  
  s.platform = :ios, '13.0'
  s.requires_arc = false
  s.module_name = 'boost'
  s.header_dir = 'boost'
  s.preserve_paths = 'boost'
  s.libraries = 'c++'
  
  s.prepare_command = <<-CMD
    # Clean up any previous extraction
    rm -rf boost
    
    # Extract the boost source
    mkdir -p boost
    tar -xjf boost_1_76_0.tar.bz2 --strip-components=1 -C boost
    
    # Clean up the downloaded archive
    rm -f boost_1_76_0.tar.bz2
  CMD
  
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/boost/boost',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end
