"""Finder layout for the drag-to-Applications installer."""
from pathlib import Path
import plistlib

application = Path(defines["app"])  # Supplied by dmgbuild.
info = plistlib.loads((application / "Contents/Info.plist").read_bytes())
icon_name = info["CFBundleIconFile"]
if not icon_name.endswith(".icns"):
    icon_name += ".icns"

format = "UDZO"
filesystem = "HFS+"
files = [str(application)]
symlinks = {"Applications": "/Applications"}
icon = str(application / "Contents/Resources" / icon_name)
background = "builtin-arrow"
# Leave room for Finder chrome even when the user's path bar is enabled.
window_rect = ((200, 200), (640, 320))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
arrange_by = None
grid_spacing = 80
icon_size = 96
text_size = 13
icon_locations = {application.name: (140, 120), "Applications": (500, 120)}
# Do not set hide_extensions: dmgbuild writes FinderInfo to the signed app,
# which makes strict codesign verification fail.
