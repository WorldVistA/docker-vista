usage()
{
    cat << EOF
    usage: $0 options

    This script will automatically start the VistA instance

    OPTIONS:
      -h    Show this message
      -v    Start Apache for ViViaN Documentation
      -i    Instance (Required)

EOF
}

while getopts "hacbemdgivpsrwy" option
do
    case $option in
        h)
            usage
            exit 1
            ;;
        v)
            startApache=true
            ;;
        i)
            instance=true
            instanceName=$OPTARG
            ;;
    esac
done

if [[ -z $startApache ]]; then
    startApache=false
fi

if [[ -z $instance ]]; then
    usage
    exit 1
fi

/opt/cachesys/${instance}/bin/start.sh

if [[ $startApache ]]; then
    exec /usr/sbin/apachectl -DFOREGROUND
fi