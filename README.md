# Zeus: the not-quite-root user

# General design

There are many administrative tasks in Linux that can, and probably *should* be done
without logging in as root or having to remember to preface each command with `sudo`.
Linux has no built-in sub-root user, as did many flavors of UNIX. The tasks are sometimes
called *operator tasks*, meaning that they are commonly executed commands, that although they
are privileged, are done to keep the computer up-and-running.

## create-zeus
The script creates a sub-root user named `zeus`. Without going into too excessive detail,
this is how the script works:

- Create two groups, `zeus` and `trustee`.
- Creates a local user named `zeus` who belongs to both of the above groups.
- Creates the directory `/etc/zeus` to contain the configuration file[s].
- Creates the directory `/var/lib/zeus` to contain zeus's commands.
- Creates a file named `/var/log/zeus-login.log` to record logins to zeus.
- Sets access to `zeus-login.log` to `0620` with the ownership of `root:trustee`. This allows
  members of trustee to write to it, but not read or alter it. Additionally, the
  write access is set to append-only (using `chattr`).
- Creates a file in `/etc/sudoers.d` that allows members of trustee to issue
  exactly one command, `sudo su - zeus`, allowing them to become zeus.
- Creates `/etc/zeus/allowed-commands` that contains the commands zeus is allowed to use.
- Creates `/var/lib/zeus/allowed-commands.md5` that contains the hash of the allowed commands.
- Installs a cron job that runs `/usr/local/sbin/generate-zeus-sudoers.sh` checks every
  five minutes for changes to the list of commands for zeus. If the list has changed, the
  `sudoers.d` file is refreshed.
- Adds a line to `/etc/fstab` that mounts a `tmpfs` filesystem on `/home/zeus/tmp`. As written, this
  file system is only 128MB (you can change it), the purpose being to allow write access to a secure space for the
  members of trustee.
- Changes the ownership of `/home/zeus` to `root:trustee` with access `0750`, allowing trustees (of which zeus is one) to read
  but not write within the directory, except for `/home/zeus/tmp`.

A couple of things to keep in mind. 

Membership in groups is session dependent. Linux looks at
your group affiliations when you login, and never looks again. So, if you add a user to `trustee`,
the user will need to logout/login for Linux to notice.

On the other hand, changes to the sudoers files are instantaneously reflected in the running
system. If you grant `zeus` a new command, `zeus` can execute it immediately.

## remove-zeus

This script was developed primarily to test the creation of the zeus user. That is
to say, it took a while to get everything to work. It removes everything about zeus
from the system, which is also convenient if you decide to abandon delegation of commands
to the zeus user and adopt some other method.

# About the scripts
The scripts do not take any options; you just need to run them.
If you want to make changes to their operation, go ahead. For example,
if you do not want to use the name `zeus` for the user, you can change the value
of the `$ZEUS_USER` variable in the scripts.
