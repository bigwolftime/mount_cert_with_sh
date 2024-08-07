set -e # Fail on error

echo "\n---\nInjecting certificate:"

# Create a separate temp directory, to hold the current certificates
# Without this, when we add the mount we can't read the current certs anymore.
mkdir -p -m 700 /data/local/tmp/htk-ca-copy
chmod 700 /data/local/tmp/htk-ca-copy
rm -rf /data/local/tmp/htk-ca-copy/*

# Copy out the existing certificates
if [ -d "/apex/com.android.conscrypt/cacerts" ]; then
    cp /apex/com.android.conscrypt/cacerts/* /data/local/tmp/htk-ca-copy/
else
    cp /system/etc/security/cacerts/* /data/local/tmp/htk-ca-copy/
fi

# Create the in-memory mount on top of the system certs folder
mount -t tmpfs tmpfs /system/etc/security/cacerts

# Copy the existing certs back into the tmpfs mount, so we keep trusting them
mv /data/local/tmp/htk-ca-copy/* /system/etc/security/cacerts/

# Copy our new cert in, so we trust that too
cp /data/misc/user/0/cacerts-added/* /system/etc/security/cacerts/

# Update the perms & selinux context labels, so everything is as readable as before
chown root:root /system/etc/security/cacerts/*
chmod 644 /system/etc/security/cacerts/*

# set Android SELinux label on root ca-certs dir too.
chcon u:object_r:system_file:s0 /system/etc/security/cacerts/
chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*

echo 'System cacerts setup completed'

# Deal with the APEX overrides in Android 14+, which need injecting into each namespace:
if [ -d "/apex/com.android.conscrypt/cacerts" ]; then
    echo 'Injecting certificates into APEX cacerts'

    # we mount for the shell itself, for completeness and so we can see this when we check for correct installation on later runs
    mount --bind /System/etc/security/cacerts /apex/com.android.conscrypt/cacerts

    # When the APEX manages cacerts, we need to mount them at that path too. We can't do
    # this globally as APEX mounts are namespaced per process, so we need to inject a
    # bind mount for this directory into every mount namespace.

    # First we get the Zygote process(es), which launch each app
    ZYGOTE_PID=$(pidof zygote || true)
    ZYGOTE64_PID=$(pidof zygote64 || true)
    Z_PIDS="$ZYGOTE_PID $ZYGOTE64_PID"
    # N.b. some devices appear to have both, some have >1 of each (!)

    # Apps inherit the Zygote's mounts at startup, so we inject here to ensure all newly
    # started apps will see these certs straight away:
    for Z_PID in 1 $Z_PIDS; do
        if [ -n "$Z_PID" ]; then
            nsenter --mount=/proc/$Z_PID/ns/mnt -- \
                /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts
        fi
    done

    echo 'Zygote APEX certificates remounted'

    # Then we inject the mount into all already running apps, so they see these certs immediately.

    # Get the PID of every process whose parent is one of the Zygotes:
    APP_PIDS=$(
        echo $Z_PIDS | \
        xargs -n1 ps -o 'PID' -P | \
        grep -v PID
    )

    # Inject into the mount namespace of each of those apps:
    for PID in $APP_PIDS; do
        nsenter --mount=/proc/$PID/ns/mnt -- \
            /bin/mount --bind /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts

        echo "bind APEX to pid: $PID"
    done

    echo "APEX certificates remounted for $(echo $APP_PIDS | wc -w) apps"
fi

# Delete the temp cert directory & this script itself
rm -r /data/local/tmp/htk-ca-copy

echo "System cert successfully injected"
