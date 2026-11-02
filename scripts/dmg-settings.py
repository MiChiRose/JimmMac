"""Finder layout, generated without AppleScript or changing the user's Finder."""
import os

app = os.path.abspath(defines["app"])
artwork = os.path.abspath(defines["artwork"])
format = "UDZO"
filesystem = "HFS+"  # Mavericks cannot mount APFS.
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents", "Resources", "JimmMac.icns")
background = artwork
# Reserve Mavericks title bar and its optional, globally enabled path bar.
window_rect = ((140, 100), (640, 484))
icon_locations = {"JimmMac.app": (160, 239), "Applications": (480, 239)}
icon_size = 96
text_size = 13
arrange_by = None
default_view = "icon-view"
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_tab_view = False
show_item_info = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
license = None
