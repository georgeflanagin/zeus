# Zeus: the not-quite-root user

# General design

There are many administrative tasks in Linux that can, and probably
*should* be done without logging in as root or having to remember to
preface each command with `sudo`.  Linux has no built-in sub-root user,
as did many flavors of UNIX. The tasks are sometimes called *operator
tasks*, meaning that they are commonly executed commands, that although
they are privileged, are done to keep the computer up-and-running.

## create-zeus

The script creates a sub-root user named `zeus`. Without going into too
excessive detail, these are the tasks done by the script:

1. Create two groups, `zeus` and `trustee`.
1. Creates a local user named `zeus` who belongs to both of the above groups.
1. Creates the directory `/etc/zeus` to contain the configuration file[s].
1. Creates the directory `/var/lib/zeus` to contain zeus's commands.
1. Creates a file named `/var/log/zeus-login.log` to record logins to zeus.
1. Sets access to `zeus-login.log` to `0620` with the ownership of `root:trustee`. This allows
  members of trustee to write to it, but not read or alter it. Additionally, the
  write access is set to append-only (using `chattr`).
1. Creates `/etc/sudoers.d/trustee` that allows members of trustee to issue
  exactly one command, `sudo su - zeus`, allowing them to become zeus.
1. Creates `/etc/sudoers.d/zeus` that enumerates the commands allowed for zeus.
1. Creates `/etc/zeus/allowed-commands` that lists in plain text the commands zeus is allowed to use.
1. Creates `/var/lib/zeus/allowed-commands.md5` that contains the hash of the allowed commands.
1. Installs a cron job that runs `/usr/local/sbin/generate-zeus-sudoers.sh` every
  five minutes for changes to the list of commands for zeus. If the list has changed, the
  `sudoers.d` file is refreshed. This way ... you won't forget to make the changes live.
1. Changes the ownership of `/home/zeus` to `root:trustee` with permissions `0750`, allowing trustees (of which zeus is one) to read
  but not write within the directory, except for `/home/zeus/tmp`.
1. Adds a line to `/etc/fstab` that mounts a `tmpfs` filesystem on `/home/zeus/tmp`. As written, this
  file system is only 128MB (you can change it, but for the purpose, this is surely enough), to allow write access to a secure space for the
  members of trustee. The script does a `systemctl daemon-reload` to make the change immediately visible.
   `/home/zeus/tmp` is owned by `zeus` with permissions `700`1. Creates `/usr/local/libexec/zeus_wrapper_common.sh` a file that checks
  each command executed for safety. (NOTE: this file system, as well as regular `/tmp`, are wiped on reboot.)
1. Creates `/home/zeus/.bashrc` to be sure `/usr/local/sbin` is first in the `$PATH` for `zeus`.

A couple of things to keep in mind. 

Membership in groups is session dependent. Linux looks at your group
affiliations when you login, and never looks again. So, if you add a
user to `trustee`, the user will need to logout/login for Linux to notice.

On the other hand, changes to the sudoers files are instantaneously
reflected in the running system. If you grant `zeus` a new command,
`zeus` can execute it immediately.

The scripts do not take any options; you just need to run them.  If you
want to make changes to their operation, go ahead. For example, if you
do not want to use the name `zeus` for the user, you can change the
value of the `$ZEUS_USER` variable in the scripts.  

## remove-zeus

This script was developed primarily to test the creation of the zeus
user. That is to say, it took a while to get everything to work. It
removes everything about zeus from the system, which is also convenient
if you decide to abandon delegation of commands to the zeus user and
adopt some other method.

## Supporting scripts

### wrapcmd.sh

The syntax is simple: `./wrapcmd.sh command`. This script wraps the
command for zeus and creates the file in `/usr/local/sbin/` that executes
the underlying, unwrapped command.

### bootstrap-wrapper.sh

You can use this command to create a few commonly used commands for zeus.

# Using the Zeus system

## Adding trustees

Identify users who will be allowed to be Zeus. The only required action is 

`usermod -aG trustee ae9qg`

As mentioned above, the user must logout/login for the change to be realized.

## Adding commands to Zeus.

It is not quite as simple as `./wrapcmd.sh command` and you are done, unless
you want to allow any variation of `command`. In fact, if you want to allow all
variations of a command via `sudo`, it is quite a bit more direct to just add 
a line to the `sudoers` file that allows it, for example, `shutdown`: 

`zeus ALL=(ALL) NOPASSWD: /usr/sbin/shutdown`

Do note that it is important to specifically identify the command in this way.
For example, suppose you wanted Zeus to be able to read (see the contents of) 
any file. It is tempting to allow `sudo cat`, but there are problems with this
method, namely that there is no guarantee that `cat` resolves to the "real" 
cat, `/usr/bin/cat`. 

The `wrapcmd.sh` script will create a wrapper for the `sudo` command, and place
it in `/usr/local/sbin`. For Zeus, this directory is searched first. Let's take a
quick look at what is in the wrapper, in this case for our friend `cat`, and
go through it line-by-line. 


`
     1	#!/bin/bash
     2	CMDNAME=$(basename "$0")
     3	REALCMD="/usr/sbin/cat"
     4	
     5	# Optional: define command-specific block patterns here
     6	BLOCKED_PATTERNS=('wheel')
     7	
     8	source "/usr/local/libexec/zeus_wrapper_common.sh"
     9	
    10	fail_if_blocked "$@"
    11	log "$@"
    12	exec "$REALCMD" "$@"
`

Line 2 
