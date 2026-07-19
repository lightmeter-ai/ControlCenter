```
Lightmeter ControlCenter 2.0.0-RC9

 Example call: 

 ./lightmeter -workspace ~/lightmeter_workspace -watch_dir /var/log 

 Flag set: 

  -data_retention_duration string
        How long data should be kept in the databases, to prevent them growing forever (default "90d")
  -default_settings string
        JSON string for default settings (default "{}")
  -dovecot_conf_gen
        Generate Dovecot Configuration
  -dovecot_conf_is_old
        Requires -dovecot_conf_gen. Use if if you're using a Dovecot older than 2.3.1
  -email_reset string
        Change user info (email, name or password; depends on -workspace)
  -i_know_what_am_doing_not_using_a_reverse_proxy
        Used when you are accessing the application without a reverse proxy (e.g. apache2, nginx or traefik), which is unsupported by us at the moment and might lead to security issues
  -importonly
        Only import existing logs, exiting immediately, without running the full application.
  -listen string
        Network Address to listen to (default ":8080")
  -log_file_patterns string
        An optional colon separated list of the base filenames for the Postfix log files. Example: "mail.log:mail.err:mail.log" or "maillog"
  -log_format string
        Expected log format from external sources (like logstash, etc.) (default "default")
  -log_level string
        Log level (DEBUG, INFO, WARN, or ERROR. Default: INFO) (default "INFO")
  -log_starting_year int
        Value to be used as initial year when it cannot be obtained from the Postfix logs. Defaults to the current year. Requires -stdin or -socket
  -logs_socket string
        Receive logs via a Socket. E.g. unix=/tmp/lightemter.sock or tcp=localhost:9999
  -logs_use_rsync
        Log directory is updated by rsync
  -new_email string
        Update user email (depends on -email_reset)
  -new_user_name string
        Update user name (depends on -email_reset)
  -node_type string
        How the logs from multiple servers are interpreted; "single" for independent servers or "multi" when messages are relayed among them (default "single")
  -password string
        Password to reset (requires -email_reset)
  -registered_user_email string
        Experimental: static user e-mail
  -registered_user_name string
        Experimental: static user name
  -registered_user_password string
        Experimental: static user password
  -stdin
        Read log lines from stdin
  -version
        Show Version Information
  -watch_dir value
        Path to the directories where postfix stores its log files, to be watched
  -workspace string
        Path to the directory to store all working data (default "/var/lib/lightmeter_workspace")
```
