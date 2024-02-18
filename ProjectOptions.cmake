include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(gui_setup_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(gui_setup_setup_options)
  option(gui_setup_ENABLE_HARDENING "Enable hardening" ON)
  option(gui_setup_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    gui_setup_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    gui_setup_ENABLE_HARDENING
    OFF)

  gui_setup_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR gui_setup_PACKAGING_MAINTAINER_MODE)
    option(gui_setup_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(gui_setup_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(gui_setup_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(gui_setup_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(gui_setup_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(gui_setup_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(gui_setup_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(gui_setup_ENABLE_PCH "Enable precompiled headers" OFF)
    option(gui_setup_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(gui_setup_ENABLE_IPO "Enable IPO/LTO" ON)
    option(gui_setup_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(gui_setup_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(gui_setup_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(gui_setup_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(gui_setup_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(gui_setup_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(gui_setup_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(gui_setup_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(gui_setup_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(gui_setup_ENABLE_PCH "Enable precompiled headers" OFF)
    option(gui_setup_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      gui_setup_ENABLE_IPO
      gui_setup_WARNINGS_AS_ERRORS
      gui_setup_ENABLE_USER_LINKER
      gui_setup_ENABLE_SANITIZER_ADDRESS
      gui_setup_ENABLE_SANITIZER_LEAK
      gui_setup_ENABLE_SANITIZER_UNDEFINED
      gui_setup_ENABLE_SANITIZER_THREAD
      gui_setup_ENABLE_SANITIZER_MEMORY
      gui_setup_ENABLE_UNITY_BUILD
      gui_setup_ENABLE_CLANG_TIDY
      gui_setup_ENABLE_CPPCHECK
      gui_setup_ENABLE_COVERAGE
      gui_setup_ENABLE_PCH
      gui_setup_ENABLE_CACHE)
  endif()

  gui_setup_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (gui_setup_ENABLE_SANITIZER_ADDRESS OR gui_setup_ENABLE_SANITIZER_THREAD OR gui_setup_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(gui_setup_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(gui_setup_global_options)
  if(gui_setup_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    gui_setup_enable_ipo()
  endif()

  gui_setup_supports_sanitizers()

  if(gui_setup_ENABLE_HARDENING AND gui_setup_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR gui_setup_ENABLE_SANITIZER_UNDEFINED
       OR gui_setup_ENABLE_SANITIZER_ADDRESS
       OR gui_setup_ENABLE_SANITIZER_THREAD
       OR gui_setup_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${gui_setup_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${gui_setup_ENABLE_SANITIZER_UNDEFINED}")
    gui_setup_enable_hardening(gui_setup_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(gui_setup_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(gui_setup_warnings INTERFACE)
  add_library(gui_setup_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  gui_setup_set_project_warnings(
    gui_setup_warnings
    ${gui_setup_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(gui_setup_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(gui_setup_options)
  endif()

  include(cmake/Sanitizers.cmake)
  gui_setup_enable_sanitizers(
    gui_setup_options
    ${gui_setup_ENABLE_SANITIZER_ADDRESS}
    ${gui_setup_ENABLE_SANITIZER_LEAK}
    ${gui_setup_ENABLE_SANITIZER_UNDEFINED}
    ${gui_setup_ENABLE_SANITIZER_THREAD}
    ${gui_setup_ENABLE_SANITIZER_MEMORY})

  set_target_properties(gui_setup_options PROPERTIES UNITY_BUILD ${gui_setup_ENABLE_UNITY_BUILD})

  if(gui_setup_ENABLE_PCH)
    target_precompile_headers(
      gui_setup_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(gui_setup_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    gui_setup_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(gui_setup_ENABLE_CLANG_TIDY)
    gui_setup_enable_clang_tidy(gui_setup_options ${gui_setup_WARNINGS_AS_ERRORS})
  endif()

  if(gui_setup_ENABLE_CPPCHECK)
    gui_setup_enable_cppcheck(${gui_setup_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(gui_setup_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    gui_setup_enable_coverage(gui_setup_options)
  endif()

  if(gui_setup_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(gui_setup_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(gui_setup_ENABLE_HARDENING AND NOT gui_setup_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR gui_setup_ENABLE_SANITIZER_UNDEFINED
       OR gui_setup_ENABLE_SANITIZER_ADDRESS
       OR gui_setup_ENABLE_SANITIZER_THREAD
       OR gui_setup_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    gui_setup_enable_hardening(gui_setup_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
