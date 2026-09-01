# Omarchy component boundaries

The Omarchy platform path adds selected tools to an existing Omarchy system. It
does not reproduce or replace Omarchy's Hyprland/Wayland desktop, login/session
stack, shell defaults, themes, or packaged configuration.

The Debian `50-gui.sh` component is deliberately incompatible with Omarchy. It
contains Xorg, i3, i3lock, picom, SDDM, Polybar, rofi, lxappearance, and Debian
theme packages. Platform filtering rejects it during planning and the component
itself checks the OS before invoking a package command.

## keynav

The reviewed inventory requested `keynav`, but upstream documents that keynav
only works on X11 and does not support Wayland. Its AUR package also depends on
X11 automation libraries such as `xdotool` and Xrandr. It is therefore not
installed on Omarchy. A Wayland-native replacement can be evaluated separately
if keyboard-driven pointer control remains a requirement.

## Safe customization boundary

Omarchy desktop and terminal preferences must use user configuration locations
or supported `omarchy` commands. Bootstrap components must not edit files under
`/usr/share/omarchy`.
