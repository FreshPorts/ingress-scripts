FreshPorts now uses a jexec and a FreeBSD jail strategy for extracting information from the ports tree.

To install the scripts into the jail, issue the following command:

./copy-scripts-into-jail.sh /jails/freshports/

The scripts required for the jail will be copied to the base directory of
the jail.  These scripts are located in the scripts subdirectory relative to
the file you are reading now.
