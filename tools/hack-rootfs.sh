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


# add user admin
adduser --quiet --disabled-password --gecos "" admin
echo "admin:admin" | chpasswd
usermod -aG sudo admin

# add user teamhd
adduser --quiet --disabled-password --gecos "" teamhd
echo "teamhd:teamhd" | chpasswd
usermod -aG sudo teamhd

# add user linaro
adduser --quiet --disabled-password --gecos "" linaro
echo "linaro:linaro" | chpasswd
usermod -aG sudo linaro

echo ok > /etc/hack

