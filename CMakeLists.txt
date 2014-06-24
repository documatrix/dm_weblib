### CMakeLists automatically created with AutoVala
### Do not edit

project (dm_weblib)
cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.8)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
option(ICON_UPDATE "Update the icon cache after installing" ON)
option(BUILD_VALADOC "Build API documentation if Valadoc is available" OFF)

set( DM_WEBLIB_MAJOR 1 )
set( DM_WEBLIB_MINOR 0 )
set( DM_WEBLIB_RELEASE 0 )
set( DM_WEBLIB_NAME dm_weblib-${DM_WEBLIB_MAJOR}.${DM_WEBLIB_MINOR} )
set( DM_WEBLIB_VERSION ${DM_WEBLIB_MAJOR}.${DM_WEBLIB_MINOR}.${DM_WEBLIB_RELEASE} )

set(HAVE_VALADOC OFF)
if(BUILD_VALADOC)
	find_package(Valadoc)
	if(VALADOC_FOUND)
		set(HAVE_VALADOC ON)
		include(Valadoc)
	else()
		message("Valadoc not found, will not build documentation")
	endif()
endif()

find_package(PkgConfig)

set (MODULES_TO_CHECK glib-2.0 dmtestlib-1.0 gobject-2.0 gio-2.0 gthread-2.0 zlib open_dmlib-1.0)
pkg_check_modules(DEPS REQUIRED ${MODULES_TO_CHECK})

add_subdirectory(src)
#add_subdirectory(tests)
add_subdirectory(doc)
