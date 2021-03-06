#!/bin/sh
### BEGIN INIT INFO
# Provides:          pdnsd
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start pdnsd
# Description:       Provides a Proxy DNS Server.
### END INIT INFO

NAME="pdnsd"
DESC="proxy DNS server"
DAEMON="/usr/sbin/pdnsd"
PIDFILE="/var/run/pdnsd.pid"
CACHE="/var/cache/pdnsd/pdnsd.cache"

test -x $DAEMON || exit 0

if test -r /etc/default/$NAME; then
    . "/etc/default/$NAME"
fi

if test -n "$AUTO_MODE" && test -f /usr/share/pdnsd/pdnsd-$AUTO_MODE.conf
then
    START_OPTIONS="${START_OPTIONS} -c /usr/share/pdnsd/pdnsd-$AUTO_MODE.conf"
fi

. /lib/lsb/init-functions
. /etc/default/rcS

is_yes() {
    case "$1" in
        [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|1) return 0;;
        *) return 1;
    esac
}

log_end_msg2 () {
    log_end_msg "$@"
    test $1 -eq 0 || exit 1
}

gen_cache()
{
    if ! test -f "$CACHE"; then
        mkdir -p `dirname $CACHE`
        dd if=/dev/zero of="$CACHE" bs=1 count=4 2> /dev/null
        chown -R pdnsd.proxy /var/cache/pdnsd
    fi	
}

start_resolvconf()
{
    test -x /sbin/resolvconf || return
    for f in `seq 1 60`; do
        sleep 0.1
        if pdnsd-ctl status >/dev/null 2>&1; then
            break
        fi
    done
    if pdnsd-ctl status | grep -q resolvconf; then
        server=$(pdnsd-ctl status|sed -ne '/^Global:$/,/^Server.*:$/s/.*Server ip.*: \(.*\)$/\1/p')
        case "$server" in
            "")      ;;
            0.0.0.0) echo "nameserver 127.0.0.1" | /sbin/resolvconf -a "lo.$NAME";;
            *)       echo "nameserver $server"   | /sbin/resolvconf -a "lo.$NAME";;
        esac
    fi
}

stop_resolvconf()
{
    if [ -x /sbin/resolvconf ] ; then
        /sbin/resolvconf -d "lo.$NAME"
    fi
}

pdnsd_start()
{
    if is_yes "$START_DAEMON"; then
        log_begin_msg "Starting $NAME"
        start-stop-daemon --oknodo --start --quiet --pidfile "$PIDFILE" \
            --exec "$DAEMON" -- --daemon -p "$PIDFILE" $START_OPTIONS
        log_end_msg2 $?
        start_resolvconf
    else
        log_warning_msg "Not starting $NAME (disabled in /etc/default/$NAME)"
    fi
}

pdnsd_stop()
{
    log_begin_msg "Stopping $NAME"
    start-stop-daemon --oknodo --stop --quiet --user pdnsd --retry=TERM/3/KILL/3 --pidfile "$PIDFILE" --name "$NAME"
    start-stop-daemon --oknodo --stop --quiet --user pdnsd --retry=0/3/KILL/3 --exec "$DAEMON" > /dev/null
    log_end_msg2 $?
    rm -f "$PIDFILE"
    stop_resolvconf
}

case "$1" in
    start)
	gen_cache
	pdnsd_start
	;;
    stop)
	pdnsd_stop
	;;
    restart|force-reload)
	pdnsd_stop
        pdnsd_start
	;;
    *)
	echo "Usage: /etc/init.d/$NAME {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit 0
