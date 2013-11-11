
To use this config include `check_flashpolicyd.cfg` and define service check:

```
define service {
        use                     flashpolicyd
        host_name               irc.example.org
}
```

Usually you can just place `check_flashpolicyd.cfg` to `/etc/nagios/plugins.d` or similar and it would be autoloaded.

If you need to pass parameters to `check_flashpolicyd`, you can define `check_command` and add them there:

```
define service {
        use                     flashpolicyd
        host_name               irc.example.org
        check_command           check_flashpolicyd!--timeout 10
}
```
