#!/bin/bash
CUR_HDMI1_ST=$(cat /sys/class/drm/card0-HDMI-A-1/status)
LAST_HDMI1_ST=$(cat /tmp/.hdmi_status | head -1)

echo 1. $CUR_HDMI1_ST 2. $LAST_HDMI1_ST 

if [[ "$CUR_HDMI1_ST" = "$LAST_HDMI1_ST" ]]; then
	exit #开机时如果HDMI状态没变化则退出，避免多重启一次桌面
fi

export DISPLAY=${DISPLAY:-:0}
RESULT=$(xrandr)
if [[ ! $RESULT =~ "HDMI" ]]; then #还没有登录桌面，xrandr无法配置，则重启桌面
	systemctl restart lightdm
else #如果桌面已经登录，上面可能已经跑了一些应用，重启桌面会杀死这些应用，不合适。改成xrandr自适应
	xrandr --output HDMI-1 --left-of LVDS-1
fi

rm /tmp/.hdmi_status
