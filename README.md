# Zeus: the not-quite-root user

# General design

There are many administrative tasks in Linux that can, and probably *should* be done
without logging in as root or having to remember to preface each command with `sudo`.
Linux has no built-in sub-root user, as did many flavors of UNIX. The tasks are sometimes
called *operator tasks*, meaning that they are commonly executed commands, that although they
are privileged, are done to keep the computer up-and-running.

These scripts create a sub-root user named `zeus`. Without going into too much detail,
this is what the scripts do:

- Create two groups, `zeus` and `trustee`.
- Creates a local user named `zeus` who belongs to both of the above groups.
- Creates the directory /etc/zeus to contain the configuration file[s].
- Creates the directory /var/lib/zeus to contain zeus's commands.
- Creates a file named /var/log/zeus-login.log to record logins to zeus.
- Sets access to zeus-login.log to 0620 with the ownership of root:trustee. This allows
  members of trustee to write to it, but not read or alter it. Additionally, the
  write access is set to append-only (using chattr).

# About the scripts
The scripts do not take any options; you just need to run them.
If you want to make changes to their operation, go ahead. For example,
if you do not want to use the name `zeus` for the user, you can change the value
of the `$ZEUS_USER` variable in the scripts.
