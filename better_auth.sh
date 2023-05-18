#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# The script need to be run with sudo for the first time setup
# Verify if the user is sudo or root, if not then ask for sudo password and at the same time run the script with elevated privileges
if [ "$UID" != 0 ]; then
    sudo --preserve-env=HOME bash "$0" "$@"
    exit $?
fi

function wheel_setup() {
    cat >/etc/sudoers.d/admin <<EOF
# allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
EOF
    gpasswd -a "$SUDO_USER" wheel
}

function polkit_setup() {
    cat >/etc/polkit-1/rules.d/50-admin.rules <<EOF
polkit.addAdminRule(function(action, subject) {
    return ["unix-group:wheel"];
});
EOF
}

function polkit_yast() {

    # We use this instead of directly running YaST in order for the root user's Qt theme to be used instead of an unsightly fallback theme, and to allow YaST to display a GUI on some Wayland compositors.
    cat >/usr/local/sbin/polkityast <<EOF
#!/bin/bash
if [ $XDG_CURRENT_DESKTOP = Hyprland ] || [ $XDG_CURRENT_DESKTOP = sway ]
then
        xhost si:localuser:root
        on_exit(){
                xhost -si:localuser:root
        }
        trap 'on_exit' EXIT
fi

pkexec env "DISPLAY=$DISPLAY" "XAUTHORITY=$XAUTHORITY" "QT_QPA_PLATFORMTHEME=kde" /sbin/yast2
EOF

    cat >/usr/share/polkit-1/actions/org.freedesktop.policykit.yast.policy <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
    <action id="org.freedesktop.policykit.pkexec.yast">
    <description>Run the YaST setup utility</description>
    <message>Authentication is required to run YaST</message>
    <icon_name>yast</icon_name>
    <defaults>
        <allow_any>auth_admin</allow_any>
        <allow_inactive>auth_admin</allow_inactive>
        <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/sbin/polkityast</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
    </action>
</policyconfig>
EOF
}

function YaST_desktop() {
    # you should be able to launch YaST with polkit instead of kdesu or gnomesu, and you should be able to use the user password instead of the root password.
    cat >~/.local/share/applications/org.opensuse.YaST.desktop <<EOF
    Exec=/usr/bin/pkexec /usr/local/sbin/polkityast
EOF
}

wheel_setup
polkit_setup
polkit_yast
YaST_desktop

echo "Done, system customization completed."
