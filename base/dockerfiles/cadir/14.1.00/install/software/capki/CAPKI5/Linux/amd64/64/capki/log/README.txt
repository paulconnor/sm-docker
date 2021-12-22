ETPKI - logging functionality
=============================

OVERVIEW
--------

The ETPKI API logging sub-system provides capabilities for logging the state of
API parameter and return values. It is implemented as a loadable plug-in, which
is deactivated by default, and may be activated as described below. The logging
sub-system comprises of the following files, which are included in the ETPKI
SDK and are installed (in a deactivated state) by the redistributable
setup application:

	capki\log\liblog_api.(dll/sl/so)
	capki\log\capki_log.cfg


INVOKING LOGGING FUNCTIONALITY
------------------------------

The ETPKI API logging sub-system is activated when the following three
conditions are met:

1)
	a) In windows, "ETPKI Installation Directory" is searched in the registry. If none is found in the registry, CAPKIHOME environment variable is used as installation directory. 
	
	b) In UNIX, CAPKIHOME environment variable is used as Installation directory.

	NOTE: ***For the rest of the document below, please read CAPKIHOME as "ETPKI Installation directory".***

	c) The ETPKI installation directory must contain 'capki\log' sub-directory. For installation of ETPKI, please refer to README present in redistrib folder of SDK.

2/ The DLL/shared library liblog_api must exist at the path:
     Windows:
       %CAPKIHOME%\capki\log\liblog_api.dll
     Others:
       $CAPKIHOME\capki\log\liblog_api.<so|sl|dylib>
		
3/ The logging sub-system configuration file 'capki_log.cfg' must exist at the
   path:
     Windows:
       %CAPKIHOME%\capki\log\etpki_log.cfg
     Others:
       $CAPKIHOME/capki/log/etpki_log.cfg

When installed via the ETPKI setup application, and as included in the SDK the
configuration file 'capki_log.cfg' has been renamed to '_capki_log.cfg'. This
breaks the third condition listed above, and the logging sub-system is
installed in a deactivated state. The logging sub-system may be activated by
simply renaming this file from '_capki_log.cfg' to 'capki_log.cfg', and may
be subsequently deactivated by renaming it back.

NB: It is preferred that the configuration file is renamed back to
    '_capki_log.cfg' rather than any other filename which will also deactivate
    the logging functionality, as the ETPKI setup application will be unable to
    remove this file on uninstall if it has a different filename.


LOG OUTPUT
----------

When invoked with the default configuration options specified in capki_log.cfg,
rolling log files are created in the current directory of the process calling
ETPKI. These log files follow the naming convention "etpki5_trace.log{.[1-n]}".
