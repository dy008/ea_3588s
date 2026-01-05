#!/bin/bash

set -x

# for xfce graphical
if [ -f /lib/systemd/system/lightdm.service ];then
	systemctl enable lightdm
fi

# for gdm graphical
if [ -f /lib/systemd/system/gdm.service ] ; then

	cat >> /lib/systemd/system/gdm.service << "EOF"

[Install]
WantedBy=graphical.target
EOF

	ln -svf /lib/systemd/system/gdm.service /etc/systemd/system/graphical.target.wants/gdm.service
	sed -i '/\[security\]/a AllowRoot=true' /etc/gdm3/daemon.conf
	sed -i 's/^auth.*pam_succeed_if\.so.*user != root.*/#&/' /etc/pam.d/gdm-password

	systemctl enable gdm
fi

systemctl daemon-reload

chmod +x /etc/rc.local

sed -i 's/NanoPC T6/EA_3588S/g' /etc/armbian-*

echo ok > /etc/hack

