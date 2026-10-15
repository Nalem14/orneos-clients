# Orneos branding for the Nextcloud desktop client.
# scripts/apply-desktop.sh appends `include(.../orneos/branding.cmake)` to the end of upstream NEXTCLOUD.cmake,
# so every value below overrides upstream's without touching the rest of the file.

set( APPLICATION_NAME        "Orneos" )
set( APPLICATION_SHORTNAME   "Orneos" )
set( APPLICATION_EXECUTABLE  "orneos" )
set( APPLICATION_ICON_NAME   "Orneos" )
set( APPLICATION_CONFIG_NAME "orneos" )
set( APPLICATION_DOMAIN      "orneos.eu" )
set( APPLICATION_VENDOR      "Orneos" )
set( APPLICATION_HELP_URL    "https://orneos.eu/fr/aide" )
# Our own update feed (ClientUpdateController on orneos.eu), never updates.nextcloud.org
set( APPLICATION_UPDATE_URL  "https://orneos.eu/updates/desktop" )

# The whole point: no server to choose, app.orneos.eu only (sign-in through login.orneos.eu)
set( APPLICATION_SERVER_URL         "https://app.orneos.eu" )
set( APPLICATION_SERVER_URL_ENFORCE ON )
set( WITH_PROVIDERS OFF )

set( APPLICATION_REV_DOMAIN       "eu.orneos.desktopclient" )
set( APPLICATION_REV_DOMAIN_DBUS  "desktopclient.orneos.eu" )
set( APPLICATION_VIRTUALFILE_SUFFIX "orneos" )
set( LINUX_PACKAGE_SHORTNAME "orneos" )
set( LINUX_APPLICATION_ID "${APPLICATION_REV_DOMAIN}.${LINUX_PACKAGE_SHORTNAME}" )
set( DEVELOPMENT_TEAM "" CACHE STRING "Apple Development Team ID" FORCE ) # set from CI once the Apple account exists

# Ornis palette (docs/ROADMAP.md)
set( NEXTCLOUD_BACKGROUND_COLOR "#002FA7" )
set( APPLICATION_WIZARD_HEADER_BACKGROUND_COLOR "#002FA7" )
set( APPLICATION_WIZARD_HEADER_TITLE_COLOR "#FFFFFF" )
set( APPLICATION_WIZARD_USE_CUSTOM_LOGO ON )

# Our icons only (the Icon Composer .icon bundle is Nextcloud's logo)
set( MACOS_USE_ICON_COMPOSER OFF )

# Windows: our own GUIDs, so Orneos installs next to an official Nextcloud client instead of replacing it
if(WIN32)
    set( WIN_SHELLEXT_CONTEXT_MENU_GUID      "{0930158A-387C-471D-9A65-175ACFAD1314}" )
    set( WIN_SHELLEXT_OVERLAY_GUID_ERROR     "{57E590F7-C8FD-44F0-A7A7-D57A20FB47F1}" )
    set( WIN_SHELLEXT_OVERLAY_GUID_OK        "{4B4F8E56-66F0-4ED7-B713-856CD7134AA3}" )
    set( WIN_SHELLEXT_OVERLAY_GUID_OK_SHARED "{1760B681-BFDD-4205-8553-31BD71428240}" )
    set( WIN_SHELLEXT_OVERLAY_GUID_SYNC      "{F4074AF2-2667-4AA0-B908-ABDF81F44013}" )
    set( WIN_SHELLEXT_OVERLAY_GUID_WARNING   "{97376CDC-6423-44D9-8265-A8E5E7ADF1AB}" )
    set( WIN_MSI_UPGRADE_CODE                "18C4B53F-9F5E-4D23-86F2-A769E85E7504" )
endif()
