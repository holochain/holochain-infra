{config, ...}: let
  fqdn = "${config.networking.hostName}.${config.networking.domain}";
in {
  programs.bash.promptInit = ''
    # Provide a nice prompt if the terminal supports it.
    if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
      PROMPT_COLOR="1;31m"
      ((UID)) && PROMPT_COLOR="1;32m"
      if [ -n "$INSIDE_EMACS" ]; then
        # Emacs term mode doesn't support xterm title escape sequence (\e]0;)
        PS1="\n\[\033[$PROMPT_COLOR\][\u@${fqdn}:\w]\n\\$\[\033[0m\] "
      else
        PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@${fqdn}: \w\a\]\u@${fqdn}:\w]\n\\$\[\033[0m\] "
      fi
      if test "$TERM" = "xterm"; then
        PS1="\[\033]2;${fqdn}:\u:\w\007\]$PS1"
      fi
    fi
  '';
}
