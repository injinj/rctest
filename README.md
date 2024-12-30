# Readme for rctest

These are notes for creating a network of Rocky 9 containers with
systemd-nspawn.   It configures systemd to manage a network of services
such as raicache and a ms_server network defined in 'network.txt'.

- Clone the repo.

```
  # git clone https://github.com/injinj/rctest
  # cd rctest
```

- Install the systemd container and networking.

```
  # dnf install systemd-networkd systemd-container dnsmasq
```

- Config a bridge network for systemd-networkd.

```
  # cp br0.netdev /etc/systemd/network/
  # cp br0.network /etc/systemd/network/
```

- Config a dhcp and dns server for the containers.  Change br0.conf for the upstream dns servers.

```
  # cp br0.conf /etc/dnsmask.d/
  # sed -i 's/^server\=.*/server=8.8.8.8/' /etc/dnsmask.d/br0.conf
```

- Start the network.  Enable if wanted on boot.

```
  # systemctl start systemd-networkd
```

- Start the dhcp server.  Enable if wanted on boot.  If resolv.conf does not go
  through dnsmasq, then the container hosts will not resolve.  Dnsmasq leases
  are in /var/lib/dnsmasq/dnsmasq.leases.  If NetworkManager is running, add
  dns=dnsmasq to the [main] section of /etc/NetworkManager/NetworkManager.conf.

```
  # systemctl stop systemd-resolved
  # systemctl start dnsmasq
  # sed -i 's/^nameserver.*/nameserver 127.0.0.1/' /etc/resolv.conf
  # sed -i 's/^\[main\]/[main]\ndns=dnsmasq/' /etc/NetworkManager/NetworkManager.conf
```

- Disable firewalld/iptables or pass through 53(dns) and 67(dhcp) ports from the containsers to the host through the bridge.

```
  # systemctl stop firewalld
  # systemctl stop iptables
```

- Create a Rocky 9 based machine for the containers.  May need to check file
  names since they contain versions.  If on a btrfs filesystem, create a
  subvolume, this allows for efficient copy on write container filesystems
  using the systemd template mechanism.  Newer XFS also has some features for
  this, but no subvolume.  The btrfs subvolume create makes the directory.

```
  # btrfs subvolume create /var/lib/machines/rocky9
  # mkdir -p /var/lib/machines/rocky9
  # dnf install --installroot=/var/lib/machines/rocky9 \
        https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/r/rocky-release-9.5-1.2.el9.noarch.rpm \
        https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/r/rocky-repos-9.5-1.2.el9.noarch.rpm \
        https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/r/rocky-gpg-keys-9.5-1.2.el9.noarch.rpm
```

- AlmaLinux 9 is here if preferred, it is very much like Rocky 9, otherwise skip it.

```
  # btrfs subvolume create /var/lib/machines/alma9
  # mkdir -p /var/lib/machines/alma9
  # dnf install --installroot=/var/lib/machines/alma9 \
        https://repo.almalinux.org/almalinux/9.5/BaseOS/x86_64/os/Packages/almalinux-gpg-keys-9.5-1.el9.x86_64.rpm
        https://repo.almalinux.org/almalinux/9.5/BaseOS/x86_64/os/Packages/almalinux-release-9.5-1.el9.x86_64.rpm
        https://repo.almalinux.org/almalinux/9.5/BaseOS/x86_64/os/Packages/almalinux-repos-9.5-1.el9.x86_64.rpm
```

- Copy the GPG key to the local system so that dnf can find it.

```
  # cp /var/lib/machines/rocky9/etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9 /etc/pki/rpm-gpg/
  # cp /var/lib/machines/alma9/etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-9 /etc/pki/rpm-gpg/
```

- Install the EPEL repo for Rocky 9 and/or AlmaLinux 9.

```
  # dnf install --installroot=/var/lib/machines/rocky9 \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  # dnf install --installroot=/var/lib/machines/alma9 \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
```

- Install enough to create a root passwd and boot the container.  May need to check file names since they contain versions.

```
  # dnf install --installroot=/var/lib/machines/rocky9 \
                https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/p/passwd-0.80-12.el9.x86_64.rpm \
                https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/s/systemd-252-46.el9_5.2.0.1.x86_64.rpm
  # dnf install --installroot=/var/lib/machines/alma9 \
                https://repo.almalinux.org/almalinux/9.5/BaseOS/x86_64/os/Packages/passwd-0.80-12.el9.x86_64.rpm \
                https://repo.almalinux.org/almalinux/9.5/BaseOS/x86_64/os/Packages/systemd-252-46.el9_5.2.alma.1.x86_64.rpm
```

- Set the root passwd (same for alma9 if not explicitly mentioned).

```
  # systemd-nspawn -D /var/lib/machines/rocky9 passwd
```

- Boot the container, login as root.

```
  # systemd-nspawn -bD /var/lib/machines/rocky9
```

- After logging into the container, install the rocky release.

```
  # dnf install --releasever=9 rocky-release
  # dnf install --releasever=9 almalinux-release
```

- In the container, install dev and network utils, vim editor.

```
  # dnf install openssh-server traceroute iputils rsync telnet sudo procps-ng htop
  # dnf install iproute net-tools pcre2 pcre2-utf32 liblzf-devel make gcc-c++ kmod
  # dnf install git openssl-devel pcre2-devel chrpath zlib-devel libbsd-devel bind-utils
  # dnf install which vim vi gdb c-ares-devel rpm-build byacc flex frr systemd-networkd
```

- In the container, install the Rai open source.  Can also clone the repos and compile them, which allows for rapid development
  and testing on a network since the containers can have a common bind mount with the host that has the binaries.

```
  # curl -s https://www.raitechnology.com/repo/raitechnology_epel-x86_64.repo -o /etc/yum.repos.d/raitechnology_epel-x86_64.repo
  # dnf install raims omm
```

- In the container, add a user, add the user to group wheel for sudo privs, may
  need to modify uid to match the host uid for user.  Change the sudoers file
  to allow sudo without a password (uncomment %wheel ALL=(ALL) NOPASSWD: ALL,
  then comment the other %wheel line).  This allows the wheel group to do sudo
  without a passwd.  A passwd can be annoying when there are dozens of containers
  that all need a systemctl command to modify some state.

```
  # useradd chris
  # usermod -G wheel chris
  # passwd chris
  # visudo
```

- In the container, enable systemd-networkd and sshd so you can use ssh to
  login.  The 172.20.0.1 address is defined in the
  /etc/systemd/network/br0.network file, it causes dns to go through dnsmasq.
  systemd-networkd will fail unless the nspawn template is used or
  systemd-nspawn with argument -U is used.

```
  # systemctl enable systemd-networkd
  # systemctl enable sshd
  # sed -i 's/^nameserver.*/nameserver 172.20.0.1/' /etc/resolv.conf
```

- Exit the container with exit and ctrl-] ctrl-] ctrl-] at the login prompt.

```
  # exit
  rocky9 login:
  Container rocky9 terminated by signal KILL.
```

- Copy the network config for the container.

```
  # cp 20-wired.network /var/lib/machines/rocky9/etc/systemd/network/
```

- Copy the systemd nspawn template or link it into /etc/systemd/system.  Note
  that this causes machines to use the rocky9 copy on write filesystem if the
  /var/lib/machines/<hostname> does not exist.  Change it if alma9 or some other
  machine filesystem is desired.

```
  # cp 'systemd-nspawn@.service' /etc/systemd/system/
```

- Optionally install gcc-toolset-13, since RHEL gcc-11 does not have a static c++
  library (libsupc++) for x86_64.  Check with cmd "dnf provides */libsupc++.a".  Can
  also use the 'scl' command instead of update-alternatives.

```
  # systemctl start systemd-nspawn@rocky9.service
  # ssh rocky9
  # sudo su
  # dnf install gcc-toolset-13
  # mv /usr/bin/gcc /usr/bin/gcc11
  # mv /usr/bin/g++ /usr/bin/g++11
  # mv /usr/bin/cpp /usr/bin/cpp11
  # update-alternatives --install /usr/bin/gcc gcc /opt/rh/gcc-toolset-13/root/usr/bin/gcc 60
  # update-alternatives --install /usr/bin/g++ g++ /opt/rh/gcc-toolset-13/root/usr/bin/g++ 60
  # update-alternatives --install /usr/lib/cpp cpp /opt/rh/gcc-toolset-13/root/usr/bin/cpp 60
  # exit
  # systemctl stop systemd-nspawn@rocky9.service
```

- Increase the number if inodes that can be open, the default is too low for dozens of containers.

```
  # cp 60-fs-inotify.conf /etc/sysctl.d/
  # sysctl --system
```

- Get raicache and add a link into the template container (need a
  http-user/http-passwd).  This uses the bind of /home in all the containers to
  the hosts /home directory configured in 'systemd-nspawn@.service'.

```
  # wget https://www.raitechnology.com/restricted/software/rel/RH8_x86_64_2.0.0.138_MTN_VIEW_REL_API_241030.tar
  # tar xf RH8_x86_64_2.0.0.138_MTN_VIEW_REL_API_241030.tar
  # tar xzf RH8_x86_64_2.0.0.138/rai_2.0.0.138.tgz
  # ln -s -f -T ${PWD}/RH8_x86_64_2.0.0.138 /var/lib/machines/rocky9/usr/rai
```

- Configure a dictionary in 'RH8_x86_64_2.0.0.138/rmds-config'.  This is an empty dict, ideally there is one that
  represents the data.

```
  # mkdir RH8_x86_64_2.0.0.138/rmds-config
  # ln -s ../config/raitest_tss_fields.cf RH8_x86_64_2.0.0.138/rmds-config/tss_fields.cf
  # ln -s ../config/raitest_tss_records.cf RH8_x86_64_2.0.0.138/rmds-config/tss_records.cf
  # touch RH8_x86_64_2.0.0.138/rmds-config/flistmapping
```

- Configure the services for the machines and install those into the template.

```
  # sh mk_services.sh
  # for i in *.service ; do ln -s -f ${PWD}/$i /var/lib/machines/rocky9/etc/systemd/system/ ; done
```

- If raims is not installed and the repos are cloned and compiled, link the binaries into the filesystem
  so that a recompile will change the containers through the symbolic link.

```
  # systemctl start systemd-nspawn@compile.service
  # git clone https://github.com/raitechnology/build
  # make -C ${PWD}/build clone
  # ssh compile make -C ${PWD}/build
  # systemctl stop systemd-nspawn@compile.service
  # ln -s ${PWD}/build/raims/ROCKY9.5_x86_64/bin/ms_server /var/lib/machines/rocky9/usr/bin/
  # ln -s ${PWD}/build/sassrv/ROCKY9.5_x86_64/bin/rv_client /var/lib/machines/rocky9/usr/bin/
  # ln -s ${PWD}/build/sassrv/ROCKY9.5_x86_64/bin/rv_pub /var/lib/machines/rocky9/usr/bin/
```

- Start the machines in file 'hosts.txt' using the rocky9 template.  The network configured in 'network.yaml' should
  match these hosts.  If the network topology is updated, then also update the 'hosts.txt' file.

```
  # for i in $(cat hosts.txt) ; do systemctl start systemd-nspawn@${i}.service ; done
  # for i in $(cat hosts.txt) ; do systemctl status systemd-nspawn@${i}.service ; done
```

- Start the 'ms_server' daemons in all the containers.  This creates a rv
  network for all of them.  From this point, I will use sudo as a regular user
  that has sudo in the containers.  The log files are in /var/log/raims.log.

```
  $ ssh_all.sh sudo systemctl start raims
  $ ssh -t sv01 sudo less /var/log/raims.log
```

- Start the raicache daemons. The log files are in /var/log/raicache.log.

```
  $ ssh raicache01 sudo systemctl start raicache
  $ ssh raicache02 sudo systemctl start raicache
  $ ssh -t raicache01 sudo less /var/log/raicache.log
```
