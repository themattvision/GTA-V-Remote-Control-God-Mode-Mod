import os

stage_dir = os.environ["GTA_REMOTE_DMG_STAGE"]

files = [
    os.path.join(stage_dir, "GodMode Mod Remote Control.app"),
    os.path.join(stage_dir, "1. START HERE.html"),
]
symlinks = {"Applications": "/Applications"}

volume_name = "GodMode Mod Remote Control"
format = "UDZO"
filesystem = "HFS+"
size = None
window_rect = ((140, 120), (720, 470))
icon_size = 92
text_size = 13
icon_locations = {
    "1. START HERE.html": (360, 105),
    "GodMode Mod Remote Control.app": (205, 285),
    "Applications": (515, 285),
}
background = os.path.join(stage_dir, ".background", "install-background.png")
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
