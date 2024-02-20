# mount_cert_with_sh
A shell script to help Android root devices mount user certifications. 

The entire processes need not be executed by flushing the Magisk/KernelSU module, so there's no need to worry about module inspection tools like: momo, Memory Detector, and etc. Theoretically :>

## Usage

1. Open the **Settings** APP, and install the CA certificate;
2. Go to this directory: `/data/misc/user/0/cacerts-added/*`, and expect to see the hash file of the certificate you just installed;
3. Execute the project's shell file with `su` privileges;
4. You can see the newly mounted certificates information in the **Settings** APP. Enjoy it!

## Note

1. After reboot, the certificate mounting relationship will be invalidated;
2. The path of the system certificate for Android14 is: `/apex/com.android.conscrypt/cacerts/`, and for versions below Android14, the path is: `/system/etc/security/cacerts/`.


## Last but not least

The vast majority of the code is referenced from: [httptoolkit-server](https://github.com/httptoolkit/httptoolkit-server), it's a really great program.


[https://github.com/httptoolkit/httptoolkit-server/blob/405ec0a4f165853ab0b90172710d4455559f4519/src/interceptors/android/adb-commands.ts#L256-L361](https://github.com/httptoolkit/httptoolkit-server/blob/405ec0a4f165853ab0b90172710d4455559f4519/src/interceptors/android/adb-commands.ts#L256-L361)
