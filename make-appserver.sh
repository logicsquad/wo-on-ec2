# Script for creating an EC2 appserver remotely
#
# This script has two mandatory options:
#
# * -i <PEM certificate>: The path to a local copy of the private PEM
#   certificate for the instance.
# * -h <hostname>: The hostname of the instance.  This is the 'Public
#   DNS' name, as supplied by the EC2 console.

APPSERVER_SETUP=appserver-setup.sh
EC2_USERNAME=ec2-user

E_BADARGS=65

# Usage
usage() {
    echo "Usage: make-appserver.sh -i <PEM certificate> -h <hostname>"
}

while getopts "i:h:" OPTION; do
    case $OPTION in
    i)
        PEM_CERT=$OPTARG
        ;;
    h)
        HOST_NAME=$OPTARG
        ;;
    *)
	usage
	exit $E_BADARGS
        ;;
    esac
done

if [ ! "$PEM_CERT" ] || [ ! "$HOST_NAME" ]
then
    usage
    exit $E_BADARGS
fi

# Create artefacts directory
ssh -t -i $PEM_CERT $EC2_USERNAME@$HOST_NAME "mkdir artefacts"

# Copy appserver-setup.sh to the server
scp -o StrictHostKeyChecking=no -B -i $PEM_CERT $APPSERVER_SETUP $EC2_USERNAME@$HOST_NAME:

# Copy artefacts to the server
scp -o StrictHostKeyChecking=no -B -i $PEM_CERT artefacts/* $EC2_USERNAME@$HOST_NAME:artefacts/

# Run appserver-setup.sh
ssh -t -i $PEM_CERT $EC2_USERNAME@$HOST_NAME "sudo ./$APPSERVER_SETUP"
