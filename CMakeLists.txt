cmake_minimum_required(VERSION 3.16)

project(plasma-applet-eventcalendar VERSION 76 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Core NetworkAuth)

find_package(KF6Package REQUIRED)
find_package(Plasma REQUIRED)

set(EVENTCALENDAR_PLASMOID_ID org.kde.plasma.eventcalendar)
set(EVENTCALENDAR_PACKAGE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/package)

if(NOT EXISTS "${EVENTCALENDAR_PACKAGE_DIR}/metadata.json")
	message(FATAL_ERROR "Missing package/metadata.json")
endif()

plasma_install_package("${EVENTCALENDAR_PACKAGE_DIR}" "${EVENTCALENDAR_PLASMOID_ID}")

# Helper binary used to complete OAuth in a real loopback flow (avoids "connection refused" page).
set(EVENTCALENDAR_BIN_DIR "${EVENTCALENDAR_PACKAGE_DIR}/contents/bin")
file(MAKE_DIRECTORY "${EVENTCALENDAR_BIN_DIR}")

add_executable(eventcalendar-google-oauth
	helper/eventcalendar_google_oauth.cpp
)
target_link_libraries(eventcalendar-google-oauth PRIVATE
	Qt6::Core
	Qt6::NetworkAuth
)
set_target_properties(eventcalendar-google-oauth PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${EVENTCALENDAR_BIN_DIR}"
)
