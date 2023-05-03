# make_opensuse_auth_better
A guide on how to fix openSUSE's quirks regarding authentication.

## Why?
By default, openSUSE uses the root password for privilege elevation. This is not ideal for several reasons, the most major being [security](https://apple.stackexchange.com/questions/192365/is-it-ok-to-use-the-root-user-as-a-normal-user/192422#192422), since you need to give the root password to anyone who needs elevated priveliges, and the fact that most Linux distros do not use the root password in this way.
This guide seeks to fix these issues by allowing you to use the user password for authentication.

## Before you begin

Before following the rest of this guide, make sure to add yourself to the `wheel` group, since by the end of this guide, you will need to be in that group to get elevated permissions.
There are two ways to do this:

### Using YaST
Open YaST, then under Security and Users, open User and Group Management. Once the window loads, double-click your username, then select the Details tab.
In this menu, scroll down to the `wheel` group, and if it isn't already checked off, click on the tickbox, then click OK, then click OK again to close the window and save your changes.

### Using the terminal
Run the following command, replacing `$YOUR_USERNAME` with your username:
```
# usermod -a -G wheel $YOUR_USERNAME
```

## Sudo
Run `visudo` as root, and comment out the the line that starts with `Defaults targetpw` and the line directly under it, like so:
```
# Defaults targetpw   # ask for the password of the target user i.e. root
# ALL   ALL=(ALL) ALL   # WARNING! Only use this together with 'Defaults targetpw'!
```
and uncomment the line further down starting with `%wheel`, like so:
```
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
```
Once this is complete, you will need to log out and restart your display manager service for the changes to apply. For example, here is how to restart the SDDM service, which is the default display manager used by KDE Plasma.
```
# systemctl restart sddm
```
If all goes well, you should be able to authenticate with `sudo` using your user password.

## Polkit
Create a new file at `/etc/polkit-1/rules.d/50-default.rules` and populate it with the following contents using your favorite text editor:
```
polkit.addAdminRule(function(action, subject) {
    return ["unix-group:wheel"];
});
```
Save the file, and the changes should apply immediately. If all goes well, you should be able to authenticate with Polkit using the user password.
## YaST
Create a new file at `/usr/local/sbin/polkityast` and populate it with the following contents using your favorite text editor:
```bash
#!/bin/bash
pkexec env "DISPLAY=$DISPLAY" "XAUTHORITY=$XAUTHORITY" "QT_QPA_PLATFORMTHEME=kde" /sbin/yast2
```
We use this instead of directly running YaST in order for the root user's Qt theme to be used instead of an unsightly fallback theme.

Make a new file at `/usr/share/polkit-1/actions/org.freedesktop.policykit.yast.policy`, you know the drill:
```xml
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
```
Finally, edit `~/.local/share/applications/org.opensuse.YaST.desktop` and replace the line starting with `Exec=` with the following:
```
Exec=/usr/bin/pkexec /usr/local/sbin/polkityast
```
If all goes well, you should be able to launch YaST with polkit instead of `kdesu` or `gnomesu`, and you should be able to use the user password instead of the root password.
