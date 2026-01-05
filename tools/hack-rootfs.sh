#!/bin/bash

set -x

if [ -f /lib/systemd/system/lightdm.service ];then
	systemctl enable lightdm
fi



if [ -f /lib/systemd/system/gdm.service ] ; then
	cat >> /lib/systemd/system/gdm.service << "EOF"

[Install]
WantedBy=graphical.target
EOF

	ln -svf /lib/systemd/system/gdm.service /etc/systemd/system/graphical.target.wants/gdm.service
fi

if [ -f /lib/systemd/system/gdm.service ];then
	systemctl enable gdm
fi

systemctl daemon-reload

chmod +x /etc/rc.local

sed -i 's/NanoPC T6/EA_3588S/g' /etc/armbian-*

echo ok > /etc/hack

